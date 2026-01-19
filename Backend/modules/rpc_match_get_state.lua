local nk = require("nakama")

-- This RPC is called by the client AFTER joining a match.
-- It fetches the authoritative match state from the server.
local function rpc_match_get_state(context, payload)
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

    local match_id = input.match_id
    if not match_id then
        return nk.json_encode({ error = "MATCH_ID_REQUIRED" }), 400
    end

    -- 3. Fetch match state
    local matches = nk.match_get([match_id])
    if not matches or #matches == 0 then
        return nk.json_encode({ error = "MATCH_NOT_FOUND" }), 404
    end

    local match = matches[1]

    -- 4. Return authoritative match state
    return nk.json_encode({
        match_id = match.match_id,
        authoritative = match.authoritative,
        label = match.label,
        size = match.size,
        tick_rate = match.tick_rate,
        handler_name = match.handler_name
        -- NOTE:
        -- Actual game state (board, players, turn, dice, etc.)
        -- lives inside ludo_match.lua state and will be sent
        -- via match data messages in Phase-3.
    }), 200
end

-- Register RPC
nk.register_rpc(rpc_match_get_state, "match_get_state")
