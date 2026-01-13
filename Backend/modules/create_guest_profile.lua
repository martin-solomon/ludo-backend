-- create_guest_profile.lua
local nk = require("nakama")
local daily_login_rewards = require("daily_login_rewards")

local function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function create_guest_profile(context, payload)
  -- 🔐 Auth check
  if not context or not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local user_id = context.user_id
  local data = nk.json_decode(payload or "{}")
  local username = trim(data.username or "")

  if username == "" then
    return nk.json_encode({ error = "username_required" }), 400
  end

  --------------------------------------------------
  -- ✅ UPDATE NAKAMA ACCOUNT (authoritative identity)
  --------------------------------------------------
  nk.account_update_id(user_id, {
    username = username,
    display_name = username
  })

  --------------------------------------------------
  -- 🔍 CHECK IF PROFILE ALREADY EXISTS
  --------------------------------------------------
  local objects = nk.storage_read({
    {
      collection = "user_profiles",
      key = "profile",
      user_id = user_id
    }
  })

  --------------------------------------------------
  -- 🆕 FIRST-TIME GUEST INITIALIZATION ONLY
  --------------------------------------------------
  if not objects or #objects == 0 then
    --------------------------------------------------
    -- 📦 CREATE PROFILE STORAGE (UI SOURCE)
    --------------------------------------------------
    nk.storage_write({
      {
        collection = "user_profiles",
        key = "profile",
        user_id = user_id,
        value = {
          username = username,
          display_name = username,   -- ✅ UI WILL READ THIS
          guest = true,
          created_at = os.time()
        },
        permission_read = 2,
        permission_write = 0
      }
    })

    --------------------------------------------------
    -- 💰 INITIAL WALLET GRANT (ONE-TIME ONLY)
    --------------------------------------------------
    nk.wallet_update(
      user_id,
      { coins = 1000 },
      { reason = "guest_account_init" },
      false
    )
  end

  --------------------------------------------------
  -- 🎁 DAILY LOGIN PROCESS (SAFE TO CALL)
  --------------------------------------------------
  daily_login_rewards.process_login(context)

  --------------------------------------------------
  -- ✅ RESPONSE (NO STATE ASSUMPTIONS)
  --------------------------------------------------
  return nk.json_encode({
    success = true,
    user_id = user_id,
    username = username
  })
end

nk.register_rpc(create_guest_profile, "create_guest_profile")
