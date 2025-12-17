local nk = require("nakama")

local function create_guest_profile(context, payload)
    if not context or not context.user_id then
        return nk.json_encode({ error = "unauthorized" }), 401
    end

    -- payload from HTTP RPC is ALWAYS a string
    local data = {}
    if payload ~= nil and payload ~= "" then
        local ok, decoded = pcall(nk.json_decode, payload)
        if ok and type(decoded) == "table" then
            data = decoded
        end
    end

    if not data.username then
        return nk.json_encode({ error = "username is required" }), 400
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
