local nk = require("nakama")

local function rename_username(context, payload)
    -- Authentication check
    if not context.user_id then
        nk.error("UNAUTHORIZED", 16)
    end

    -- Handle payload correctly (unwrap-safe)
    local new_username

    if type(payload) == "string" and payload ~= "" then
        local decoded = nk.json_decode(payload)
        new_username = decoded.username
    else
        nk.error("USERNAME_REQUIRED", 3)
    end

    if not new_username or new_username == "" then
        nk.error("USERNAME_REQUIRED", 3)
    end

    -- Normalize
    new_username = string.lower(new_username)

    -- Validation
    if #new_username < 3 or #new_username > 20 then
        nk.error("USERNAME_LENGTH_INVALID", 3)
    end

    if not string.match(new_username, "^[a-z0-9_]+$") then
        nk.error("USERNAME_FORMAT_INVALID", 3)
    end

    -- Fetch current account
    local account = nk.account_get_id(context.user_id)

    -- No-op
    if account.username == new_username then
        return nk.json_encode({
            success = true,
            username = account.username
        })
    end

    -- Update account username
    local ok, err = pcall(function()
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

    if not ok then
        nk.logger_error("rename_username failed: " .. tostring(err))
        nk.error("USERNAME_ALREADY_TAKEN", 13)
    end

    -- Sync profile mirror
    nk.storage_write({
        {
            collection = "profile",
            key = "data",
            user_id = context.user_id,
            value = {
                username = new_username
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

return rename_username
