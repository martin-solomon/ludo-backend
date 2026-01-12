local nk = require("nakama")

local function error_response(code, message)
    return nk.json_encode({
        success = false,
        code = code,
        message = message
    })
end

local function rename_username(context, payload)
    -- Auth check
    if not context.user_id then
        return error_response(16, "UNAUTHORIZED")
    end

    -- Decode payload
    local decoded
    local ok = pcall(function()
        decoded = nk.json_decode(payload)
    end)

    if not ok or not decoded or not decoded.username then
        return error_response(3, "USERNAME_REQUIRED")
    end

    local new_username = string.lower(decoded.username)

    -- Validation
    if #new_username < 3 or #new_username > 20 then
        return error_response(3, "USERNAME_LENGTH_INVALID")
    end

    if not string.match(new_username, "^[a-z0-9_]+$") then
        return error_response(3, "USERNAME_FORMAT_INVALID")
    end

    local user_id = context.user_id

    -- Read current profile to get old username
    local profiles = nk.storage_read({
        {
            collection = "profile",
            key = "data",
            user_id = user_id
        }
    })

    local old_username = nil
    if profiles[1] and profiles[1].value and profiles[1].value.display_name then
        old_username = profiles[1].value.display_name
    end

    -- If same name, no-op
    if old_username == new_username then
        return nk.json_encode({
            success = true,
            username = new_username
        })
    end

    -- Check if new username already exists
    local existing = nk.storage_read({
        {
            collection = "usernames",
            key = new_username,
            user_id = nil
        }
    })

    if existing[1] then
        return error_response(13, "USERNAME_ALREADY_TAKEN")
    end

    -- Begin rename operation
    -- 1. Delete old username mapping (if exists)
    if old_username then
        nk.storage_delete({
            {
                collection = "usernames",
                key = old_username,
                user_id = nil
            }
        })
    end

    -- 2. Claim new username
    nk.storage_write({
        {
            collection = "usernames",
            key = new_username,
            user_id = nil,
            value = {
                user_id = user_id
            },
            permission_read = 2,
            permission_write = 0
        }
    })

    -- 3. Update profile display name
    nk.storage_write({
        {
            collection = "profile",
            key = "data",
            user_id = user_id,
            value = {
                display_name = new_username
            },
            permission_read = 2,
            permission_write = 0
        }
    })

    return nk.json_encode({
        success = true,
        username = new_username
    })
end

nk.register_rpc(rename_username, "rename_username")
