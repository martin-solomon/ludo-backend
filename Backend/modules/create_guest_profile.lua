local nk = require("nakama")

-- Helper function to trim whitespace
local function trim(s)
   return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function create_guest_profile(context, payload)
    if not context or not context.user_id then
        return nk.json_encode({ error = "unauthorized" }), 401
    end

    -- 1. Safe JSON Decoding
    -- The payload comes in as a string. We MUST decode it.
    local decoded_ok, data = pcall(nk.json_decode, payload)
    if not decoded_ok or type(data) ~= "table" then
        nk.logger_error("Failed to decode JSON payload: " .. payload)
        return nk.json_encode({ error = "invalid json format" }), 400
    end

    -- 2. Validate Username
    local username = trim(data.username or "")
    if username == "" then
        nk.logger_error("create_guest_profile: username field is missing or empty")
        return nk.json_encode({ error = "username is required" }), 400
    end

    nk.logger_info("Processing guest profile for user: " .. context.user_id .. " with username: " .. username)

    -- 3. Update Account
    local update_ok, update_err = pcall(nk.account_update_id, context.user_id, {
        username = username
    })
    if not update_ok then
         nk.logger_warn("Failed to update username (might be taken): " .. tostring(update_err))
    end

    -- 4. Write to Storage
    local storage_write_ok, storage_err = pcall(nk.storage_write, {
        {
            collection = "user_profiles",
            key = "profile",
            user_id = context.user_id,
            value = { username = username, guest = true },
            permission_read = 2,
            permission_write = 0
        }
    })

    if not storage_write_ok then
        nk.logger_error("Failed to write to storage: " .. tostring(storage_err))
        return nk.json_encode({ error = "failed to write storage" }), 500
    end

    -- 5. Success Response
    return nk.json_encode({
        success = true,
        user_id = context.user_id,
        username = username
    })
end

nk.register_rpc(create_guest_profile, "create_guest_profile")
