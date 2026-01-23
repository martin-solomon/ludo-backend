local nk = require("nakama")
local avatar_catalog = require("avatar_catalog")

local function rpc_avatar_health_check(context, payload)

    -- 🔐 Optional: restrict to server/admin only
    if not context or not context.user_id then
        return nk.json_encode({ error = "unauthorized" }), 401
    end

    local fixed = 0
    local scanned = 0

    -- List all user_profiles
    local cursor = nil

    repeat
        local objects, new_cursor = nk.storage_list(
            nil,                 -- user_id (nil = all users)
            "user_profiles",     -- collection
            100,                 -- batch size
            cursor
        )

        cursor = new_cursor

        for _, obj in ipairs(objects or {}) do
            scanned = scanned + 1

            local profile = obj.value or {}

            -- Check avatar
            local avatar = profile.active_avatar
            if not avatar or not avatar_catalog.is_valid(avatar.id) then
                profile.active_avatar = avatar_catalog.DEFAULT

                nk.storage_write({
                    {
                        collection = "user_profiles",
                        key = obj.key,
                        user_id = obj.user_id,
                        value = profile,
                        permission_read = obj.permission_read,
                        permission_write = obj.permission_write
                    }
                })

                fixed = fixed + 1
            end
        end

    until not cursor

    return nk.json_encode({
        success = true,
        scanned_profiles = scanned,
        fixed_profiles = fixed
    })
end

nk.register_rpc(rpc_avatar_health_check, "rpc_avatar_health_check")
