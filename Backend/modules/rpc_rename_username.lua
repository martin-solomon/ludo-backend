local nk = require("nakama")

local function error_response(code, message)
    return nk.json_encode({
        success = false,
        code = code,
        message = message
    })
end

local function rename_username(context, payload)
    if not context.user_id then
        return error_response(16, "UNAUTHORIZED")
    end

    local decoded
    local ok = pcall(function()
        decoded = nk.json_decode(payload)
    end)

    if not ok or not decoded or not decoded.username then
        return error_response(3, "USERNAME_REQUIRED")
    end

    local new_username = string.lower(decoded.username)

    if #new_username < 3 or #new_username > 20 then
        return error_response(3, "USERNAME_LENGTH_INVALID")
    end

    if not string.match(new_username, "^[a-z0-9_]+$") then
        return error_response(3, "USERNAME_FORMAT_INVALID")
    end

    local account = nk.account_get_id(context.user_id)

    if account.username == new_username then
        return nk.json_encode({
            success = true,
            username = account.username
        })
    end

    local update_ok, update_err = pcall(function()
        nk.account_update_id(
            context.user_id,
            new_username,
            account.display_name,
            account.avatar_url,
            account.lang_tag,
            account.location,
            account.timezone,
            account.metadata
        )
    end)

    if not update_ok then
        nk.logger_error("rename_username failed: " .. tostring(update_err))
        return error_response(13, "USERNAME_ALREADY_TAKEN")
    end

    nk.storage_write({
        {
            collection = "profile",
            key = "data",
            user_id = context.user_id,
            value = { username = new_username },
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
