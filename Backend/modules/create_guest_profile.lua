-- create_guest_profile.lua
local nk = require("nakama")

local function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function create_guest_profile(context, payload)
  if not context or not context.user_id then
    return nk.json_encode({ error = "unauthorized" })
  end

  local data = nk.json_decode(payload or "{}")
  local username = trim(data.username or "")

  if username == "" then
    return nk.json_encode({ error = "username is required" })
  end

  -- 🔴 THIS IS THE CRITICAL FIX
  nk.account_update_id(context.user_id, {
    username = username,
    display_name = username   -- ✅ REQUIRED
  })

  -- profile storage (unchanged)
  local objects = nk.storage_read({
    {
      collection = "user_profiles",
      key = "profile",
      user_id = context.user_id
    }
  })

  if #objects == 0 then
    nk.storage_write({
      {
        collection = "user_profiles",
        key = "profile",
        user_id = context.user_id,
        value = {
          username = username,
          guest = true,
          created_at = os.time()
        },
        permission_read = 2,
        permission_write = 0
      }
    })
  end

  -- ✅ DAILY LOGIN TASK PROGRESS (ADDED)
  local daily_progress = require("daily_task_progress")
  daily_progress.increment(context.user_id, "login", 1)

  return nk.json_encode({
    success = true,
    user_id = context.user_id,
    username = username
  })
end

nk.register_rpc(create_guest_profile, "create_guest_profile")
