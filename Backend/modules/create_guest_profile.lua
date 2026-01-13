-- create_guest_profile.lua (PRODUCTION SAFE)
local nk = require("nakama")

local STARTING_COINS = 1000

local function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function create_guest_profile(context, payload)
  if not context or not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local data = {}
  if payload and payload ~= "" then
    local ok, decoded = pcall(nk.json_decode, payload)
    if ok and type(decoded) == "table" then
      data = decoded
    end
  end

  local username = trim(data.username or "")
  if username == "" then
    return nk.json_encode({ error = "username_required" }), 400
  end

  local user_id = context.user_id

  --------------------------------------------------
  -- ✅ 1. Update Nakama account (fixes "Player")
  --------------------------------------------------
  nk.account_update_id(user_id, {
    username = username,
    display_name = username
  })

  --------------------------------------------------
  -- ✅ 2. Check ONE-TIME INIT FLAG
  --------------------------------------------------
  local init_flag = nk.storage_read({
    {
      collection = "user_init",
      key = "state",
      user_id = user_id
    }
  })

  local already_initialized = init_flag and #init_flag > 0

  if not already_initialized then
    --------------------------------------------------
    -- ✅ 3. Initialize wallet ONCE
    --------------------------------------------------
    nk.wallet_update(
      user_id,
      { coins = STARTING_COINS },
      { reason = "initial_grant" },
      true
    )

    --------------------------------------------------
    -- ✅ 4. Save init flag
    --------------------------------------------------
    nk.storage_write({
      {
        collection = "user_init",
        key = "state",
        user_id = user_id,
        value = {
          initialized = true,
          at = os.time()
        },
        permission_read = 0,
        permission_write = 0
      }
    })
  end

  --------------------------------------------------
  -- ✅ 5. Profile storage (non-authoritative)
  --------------------------------------------------
  nk.storage_write({
    {
      collection = "user_profiles",
      key = "profile",
      user_id = user_id,
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
    user_id = user_id,
    username = username
  })
end

nk.register_rpc(create_guest_profile, "create_guest_profile")
