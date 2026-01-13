-- create_guest_profile.lua
local nk = require("nakama")
local daily_login_rewards = require("daily_login_rewards")

local function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function create_guest_profile(context, payload)
  if not context or not context.user_id then
    return nk.json_encode({ error = "unauthorized" })
  end

  local user_id = context.user_id
  local data = nk.json_decode(payload or "{}")
  local username = trim(data.username or "")

  if username == "" then
    return nk.json_encode({ error = "username is required" })
  end

  -- ✅ Set Nakama account fields
  nk.account_update_id(user_id, {
    username = username,
    display_name = username
  })

  -- 🔍 Check if profile already exists
  local objects = nk.storage_read({
    {
      collection = "user_profiles",
      key = "profile",
      user_id = user_id
    }
  })

  -- 🆕 FIRST-TIME GUEST CREATION
  if #objects == 0 then
    --------------------------------------------------
    -- 📦 CREATE USER PROFILE
    --------------------------------------------------
    nk.storage_write({
      {
        collection = "user_profiles",
        key = "profile",
        user_id = user_id,
        value = {
          username = username,
          guest = true,
          created_at = os.time()
        },
        permission_read = 2,
        permission_write = 0
      }
    })

    --------------------------------------------------
    -- 💰 INITIAL WALLET GRANT (ONE-TIME)
    -- Purpose: Give starting coins to new guest
    --------------------------------------------------
    nk.wallet_update(
      user_id,
      { coins = 1000 },
      { reason = "guest_account_init" },
      false -- authoritative
    )
  end

  --------------------------------------------------
  -- 🎁 DAILY LOGIN PROCESS (UNCHANGED)
  --------------------------------------------------
  daily_login_rewards.process_login(context)

  return nk.json_encode({
    success = true,
    user_id = user_id,
    username = username
  })
end

nk.register_rpc(create_guest_profile, "create_guest_profile")
