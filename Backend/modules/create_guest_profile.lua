local nk = require("nakama")

-- 🔹 ADD: inventory helper
local inventory = require("inventory_helper")

local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function create_guest_profile(context, payload)
    -- ✅ AUTH CHECK (REQUIRED)
    if not context or not context.user_id then
        return nk.json_encode({ error = "unauthorized" })
    end

    -- ✅ DECODE JSON PAYLOAD
    local data = nk.json_decode(payload or "{}")
    local username = trim(data.username or "")

    if username == "" then
        return nk.json_encode({ error = "username is required" })
    end

    -- 🧑 UPDATE ACCOUNT
    pcall(nk.account_update_id, context.user_id, {
        username = username
    })

    -- 📦 CREATE PROFILE ONLY IF NOT EXISTS
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

    -- 🔹 ADD: ensure inventory always exists
    inventory.ensure_inventory(context.user_id)

    return nk.json_encode({
        success = true,
        user_id = context.user_id,
        username = username,
        guest = true
    })
end

nk.register_rpc(create_guest_profile, "create_guest_profile")
