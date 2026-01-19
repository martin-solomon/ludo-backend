local nk = require("nakama")

local function rpc_match_join(context, payload)
    if not context.user_id then
        return nk.json_encode({ error = "NO_SESSION" }), 401
    end

    local input = nk.json_decode(payload or "{}")

    if not input.match_id then
        return nk.json_encode({ error = "MATCH_ID_REQUIRED" }), 400
    end

    nk.match_join(
        input.match_id,
        context.user_id,
        context.session_id
    )

    return nk.json_encode({
        status = "JOINED",
        match_id = input.match_id
    })
end

nk.register_rpc(rpc_match_join, "match_join")
