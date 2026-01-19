local nk = require("nakama")

local function rpc_quick_join(context, payload)
    if not context.user_id then
        return nk.json_encode({ error = "NO_SESSION" })
    end

    local input = nk.json_decode(payload or "{}")
    local match_id = input.match_id

    if not match_id then
        return nk.json_encode({ error = "MATCH_ID_REQUIRED" })
    end

    -- Server-side join (this is correct)
    nk.match_join(match_id, { context.user_id })

    return nk.json_encode({
        status = "JOINED",
        match_id = match_id
    })
end

nk.register_rpc(rpc_quick_join, "match_quick_join")
