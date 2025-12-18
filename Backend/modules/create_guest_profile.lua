local nk = require("nakama")

-- Helper to trim whitespace
local function trim(s)
   return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function create_guest_profile(context, payload)
    if not context or not context.user_id then
        return nk.json_encode({ error = "unauthorized" }), 401
    end

    -- SIMPLE VERSION: Just take the payload string as the username
    local username = trim(payload or "")

    if username == "" then
        return nk.json_encode({ error = "username is required" }), 400
    end

    nk.logger_info("Creating profile for: " .. context.user_id .. " name: " .. username)

    -- Update Account
    pcall(nk.account_update_id, context.user_id, { username = username })

    -- Write Storage
    local write_ok, write_err = pcall(nk.storage_write, {
        {
            collection = "user_profiles",
            key = "profile",
            user_id = context.user_id,
            value = { username = username, guest = true },
            permission_read = 2,
            permission_write = 0
        }
    })

    if not write_ok then
        nk.logger_error("Storage write failed: " .. tostring(write_err))
        return nk.json_encode({ error = "storage failed" }), 500
    end

    return nk.json_encode({ success = true, username = username })
end

nk.register_rpc(create_guest_profile, "create_guest_profile")
