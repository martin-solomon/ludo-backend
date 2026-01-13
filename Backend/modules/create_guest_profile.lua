-- create_guest_profile.lua
local nk = require("nakama")

local STARTING_COINS = 1000

local function create_guest_profile(context, payload)
  if not context or not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local data = nk.json_decode(payload or "{}")
  local username = (data.username or ""):gsub("^%s*(.-)%s*$", "%1")
  if username == "" then
    return nk.json_encode({ error = "username_required" }), 400
  end

  -- ✅ Update Nakama account name (THIS fixes “Player” issue)
  nk.account_update_id(context.user_id, {
    username = username,
    display_name = username
  })

  -- ✅ Initialize wallet ONLY IF EMPTY
  local wallet = nk.wallet_get(context.user_id)
  if not wallet or not wallet.coins then
    nk.wallet_update(
      context.user_id,
      { coins = STARTING_COINS },
      { reason = "initial_grant" },
      true
    )
  end

  -- ✅ Create profile storage (non-authoritative)
  nk.storage_write({
    {
      collection = "user_profiles",
      key = "profile",
      user_id = context.user_id,
      value = {
        username = username,
        display_name = username,
        guest = true,
        created_at = os.time()
      },
      permission_read = 2,
      permission_write = 0
    }
  })

  return nk.json_encode({
    success = true,
    user_id = context.user_id,
    username = username
  })
end

nk.register_rpc(create_guest_profile, "create_guest_profile")
