-- create_guest_profile.lua
local nk = require("nakama")

-- inventory helper (already used by you)
local inventory = require("inventory_helper")

-- helper
local function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function create_guest_profile(context, payload)
  -- 🔐 AUTH CHECK (UNCHANGED)
  if not context or not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  -- 🔹 DECODE PAYLOAD (UNCHANGED)
  local data = nk.json_decode(payload or "{}")
  local username = trim(data.username or "")

  if username == "" then
    return nk.json_encode({ error = "username is required" }), 400
  end

  ------------------------------------------------------------------
  -- ✅ MISSING BUT CRITICAL FIX (ADD THIS)
  -- Force-update Nakama account username + display_name
  ------------------------------------------------------------------
  local ok, err = pcall(nk.account_update_id, context.user_id, {
    username = username,        -- shows in Nakama Console
    display_name = username     -- also shows correctly
  })

  if not ok then
    nk.logger_error("Failed to update guest account name: " .. tostring(err))
    return nk.json_encode({ error = "username_update_failed" }), 500
  end
  ------------------------------------------------------------------

  ------------------------------------------------------------------
  -- 📦 PROFILE STORAGE (UNCHANGED LOGIC)
  ------------------------------------------------------------------
  local objects = nk.storage_read({
    {
      collection = "user_profiles",
      key = "profile",
      user_id = context.user_id
    }
  })

  if not objects or #objects == 0 then
    nk.storage_write({
      {
        collection = "user_profiles",
        key = "profile",
        user_id = context.user_id,
        value = {
          username = username,
          guest = true,
          coins = 1000,
          level = 1,
          xp = 0,
          wins = 0,
          losses = 0,
          created_at = os.time()
        },
        permission_read = 2,
        permission_write = 0
      }
    })
  end

  ------------------------------------------------------------------
  -- 📦 INVENTORY INIT (UNCHANGED)
  ------------------------------------------------------------------
  inventory.ensure_inventory(context.user_id)

  return nk.json_encode({
    success = true,
    user_id = context.user_id,
    username = username,
    guest = true
  })
end

nk.register_rpc(create_guest_profile, "create_guest_profile")
