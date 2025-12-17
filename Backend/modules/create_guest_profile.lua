local nk = require("nakama")

-- Helper function to trim whitespace from strings
local function trim(s)
   return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function create_guest_profile(context, payload)
    if not context or not context.user_id then
        return nk.json_encode({ error = "unauthorized" }), 401
    end

    -- payload from HTTP RPC is ALWAYS a string.
    -- IMPORTANT: Trim whitespace (like extra newlines) before decoding.
    local clean_payload = trim(payload or "")
    local data = {}

    if clean_payload ~= "" then
        local ok, decoded = pcall(nk.json_decode, clean_payload)
        if ok and type(decoded) == "table" then
            data = decoded
        else
            -- Log if JSON decoding fails for debugging
            nk.logger_error("Failed to decode JSON payload: " .. clean_payload)
            return nk.json_encode({ error = "invalid json payload" }), 400
        end
    end

    if not data.username or data.username == "" then
        return nk.json_encode({ error = "username is required" }), 400
    end

    nk.logger_info("Creating guest profile for user: " .. context.user_id .. " with username: " .. data.username)

    -- Update the account's username
    local update_ok, update_err = pcall(nk.account_update_id, context.user_id, {
        username = data.username
    })

    if not update_ok then
         nk.logger_error("Failed to update username: " .. tostring(update_err))
         -- Usually means username is taken
         return nk.json_encode({ error = "username unavailable or invalid" }), 409
    end

    -- Write to storage so it shows up in the console
    local storage_write_ok, storage_err = pcall(nk.storage_write, {
        {
            collection = "user_profiles",
            key = "profile",
            user_id = context.user_id,
            value = { username = data.username, guest = true },
            permission_read = 2, -- Public read
            permission_write = 0 -- Owner write only
        }
    })

    if not storage_write_ok then
        nk.logger_error("Failed to write to storage: " .. tostring(storage_err))
        -- Don't fail the whole request if storage write fails, but log it.
    end

    return nk.json_encode({
        success = true,
        user_id = context.user_id,
        username = data.username
    })
end

nk.register_rpc(create_guest_profile, "create_guest_profile")
