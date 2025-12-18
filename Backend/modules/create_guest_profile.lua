local nk = require("nakama")

-- Helper to trim whitespace
local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function create_guest_profile(context, payload)
    -- 🚫 AUTH CHECK
    if not context or not context.user_id then
        return nk.json_encode({ error = "unauthorized" })
    end

    -- 📥 RAW STRING PAYLOAD (unwrap=true)
    local username = trim(payload or "")

    if username == "" then
        return nk.json_encode({ error = "username is required" })
    end

    nk.logger_info("Creating profile for: " .. context.user_id .. " name: " .. username)

    -- 🧑 ACCOUNT UPDATE
    local ok, err = pcall(nk.account_update_id, context.user_id, {
        username = username
    })

    if not ok then
        nk.logger_warn("Username update failed: " .. tostring(err))
        return nk.json_encode({ error = "username already taken" })
    end

    -- 📦 STORAGE WRITE
    local write_ok, write_err = pcall(nk.storage_write, {
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

    if not write_ok then
        nk.logger_error("Storage write failed: " .. tostring(write_err))
        return nk.json_encode({ error = "storage failed" })
    end

    -- ✅ SUCCESS (SINGLE RETURN VALUE)
    return nk.json_encode({
        success = true,
        user_id = context.user_id,
        username = username,
        guest = true
    })
end

nk.register_rpc(create_guest_profile, "create_guest_profile")
