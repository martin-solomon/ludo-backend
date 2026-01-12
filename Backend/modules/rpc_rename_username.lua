local nk = require("nakama")

-- =========================================
-- RPC: rename_username
-- Purpose:
--   - Rename Nakama account username
--   - Enforce global uniqueness (via Nakama)
--   - Sync profile mirror
-- =========================================

local function rename_username(context, payload)
    --  Authentication check
    if not context.user_id then
        error("UNAUTHORIZED")
    end

    --  Decode payload
    local data = nk.json_decode(payload or "{}")
    local new_username = data.username

    if not new_username or new_username == "" then
        error("USERNAME_REQUIRED")
    end

    --  Normalize username
    new_username = string.lower(new_username)

    -- Optional: basic validation (recommended)
    if #new_username < 3 or #new_username > 20 then
        error("USERNAME_LENGTH_INVALID")
    end

    if not string.match(new_username, "^[a-z0-9_]+$") then
        error("USERNAME_FORMAT_INVALID")
    end

    --  Fetch current account
    local account = nk.account_get_id(context.user_id)

    --  No-op protection
    if account.username == new_username then
        return nk.json_encode({
            success = true,
            username = account.username
        })
    end

    -- Update ACCOUNT username
    -- This is where Nakama enforces uniqueness
    local ok, err = pcall(function()
        nk.account_update_id(
            context.user_id,
            new_username,                 -- authoritative username
            account.display_name,
            account.avatar_url,
            account.lang_tag,
            account.location,
            account.timezone,
            account.metadata
        )
    end)

    if not ok then
    nk.logger_error("rename_username real error: " .. tostring(err))
    error("RENAME_FAILED")
end

    -- Sync profile mirror (NOT authoritative)
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

    --Return success
    return nk.json_encode({
        success = true,
        username = new_username
    })
end

-- Register RPC
nk.register_rpc(rename_username, "rename_username")

return rename_username

