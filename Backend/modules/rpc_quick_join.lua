local nk = require("nakama")

local function rpc_match_quick_join(context, payload)
    if not context.user_id then
        return nk.json_encode({ error = "NO_SESSION" })
    end

    local input = nk.json_decode(payload or "{}")

    if not input.match_id then
        return nk.json_encode({ error = "MATCH_ID_REQUIRED" })
    end

    -- 🔹 DO NOT call nk.match_join
    -- 🔹 Just validate match exists
    local matches = nk.match_list(1, true, nil, nil, { match_id = input.match_id })

    if not matches or #matches == 0 then
        return nk.json_encode({ error = "MATCH_NOT_FOUND" })
    end

    -- 🔹 Player join logic is logical, not HTTP
    -- (State update happens inside match handler)

    return nk.json_encode({
        status = "JOIN_ACCEPTED",
        match_id = input.match_id,
        user_id = context.user_id
    })
end

nk.register_rpc(rpc_match_quick_join, "match_quick_join")
