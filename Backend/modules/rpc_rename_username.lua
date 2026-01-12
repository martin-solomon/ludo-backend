local nk = require("nakama")

local function rename_username(context, payload)
    -- Must be authenticated
    if not context.user_id then
        error("UNAUTHORIZED")
    end

    -- Decode payload
    local data = nk.json_decode(payload)
    local new_username = data.username

    if not new_username or new_username == "" then
        error("USERNAME_REQUIRED")
    end

    -- Normalize username (IMPORTANT)
    new_username = string.lower(new_username)

    -- Get current account
    local account = nk.account_get_id(context.user_id)

    -- Prevent no-op rename
    if account.username == new_username then
        return nk.json_encode({
            success = true,
            username = account.username
        })
    end

    -- Try updating ACCOUNT username (this enforces uniqueness)
    local success, err = pcall(function()
        nk.account_update_id(
            context.user_id,
            new_username,                 -- UNIQUE USERNAME
            account.display_name,
            account.avatar_url,
            account.lang_tag,
            account.location,
            account.timezone,
            account.metadata
        )
    end)

    if not success then
        -- Nakama throws error if username already exists
        error("USERNAME_ALREADY_TAKEN")
    end

    -- Sync profile mirror (NOT authority)
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

    --  Return success
    return nk.json_encode({
        success = true,
        username = new_username
    })
end

return rename_username
