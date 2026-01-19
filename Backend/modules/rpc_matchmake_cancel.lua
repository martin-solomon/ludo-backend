local nk = require("nakama")

local function rpc_matchmake_cancel(context, payload)
    -- 1. Validate session
    if not context or not context.user_id then
        return nk.json_encode({ error = "NO_SESSION" }), 401
    end

    -- 2. Parse payload
    local input = {}
    if payload and payload ~= "" then
        local ok, decoded = pcall(nk.json_decode, payload)
        if ok and type(decoded) == "table" then
            input = decoded
        end
    end

    -- 3. Validate ticket
    local ticket = input.ticket
    if not ticket then
        return nk.json_encode({ error = "TICKET_REQUIRED" }), 400
    end

    -- 4. Remove from matchmaking
    nk.matchmaker_remove(ticket)

    -- 5. Return success
    return nk.json_encode({
        status = "cancelled",
        ticket = ticket
    }), 200
end

-- Register RPC
nk.register_rpc(rpc_matchmake_cancel, "matchmake_cancel")
