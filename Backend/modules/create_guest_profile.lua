local nk = require("nakama")

local function create_guest_profile(context, payload)
    if not context.user_id then
        return nk.json_encode({
            error = "User not authenticated"
        })
    end

    if not payload or payload == "" then
        return nk.json_encode({
            error = "Payload required"
        })
    end

    local data = nk.json_decode(payload)
    if not data.username then
        return nk.json_encode({
            error = "username is required"
        })
    end

    nk.logger_info("Creating guest profile for user: " .. context.user_id)

    nk.account_update_id(context.user_id, {
        username = data.username
    })

    return nk.json_encode({
        success = true,
        user_id = context.user_id
    })
end

nk.register_rpc(create_guest_profile, "create_guest_profile")
