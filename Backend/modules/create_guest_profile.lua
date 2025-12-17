local nk = require("nakama")

-- Helper function to trim whitespace from strings
local function trim(s)
   return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function create_guest_profile(context, payload)
    if not context or not context.user_id then
        return nk.json_encode({ error = "unauthorized" }), 401
    end

    -- The payload is now just the username string directly.
    -- e.g., payload will be "test_player_final"
    local username = trim(payload or "")

    if username == "" then
        nk.logger_error("create_guest_profile: no username provided")
        return nk.json_encode({ error = "username is required" }), 400
    end

    nk.logger_info("Updating profile for user: " .. context.user_id .. " to username: " .. username)

    -- 1. Update the account's username
    local update_ok, update_err = pcall(nk.account_update_id, context.user_id, {
        username = username
    })
    if not update_ok then
         nk.logger_warn("Failed to update username (might be taken): " .. tostring(update_err))
         -- Continue anyway to write the storage object
    end

    -- 2. Write the profile to storage
    local storage_write_ok, storage_err = pcall(nk.storage_write, {
        {
            collection = "user_profiles",
            key = "profile",
            user_id = context.user_id,
            value = { username = username, guest = true },
            permission_read = 2, -- Public read
            permission_write = 0 -- Owner write only
        }
    })

    if not storage_write_ok then
        nk.logger_error("Failed to write to storage: " .. tostring(storage_err))
        return nk.json_encode({ error = "failed to write storage" }), 500
    end

    -- Return success
    return nk.json_encode({
        success = true,
        user_id = context.user_id,
        username = username
    })
end

nk.register_rpc(create_guest_profile, "create_guest_profile")
