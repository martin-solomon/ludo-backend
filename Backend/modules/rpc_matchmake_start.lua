local nk = require("nakama")

local function rpc_matchmake_start(context, payload)
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

    local mode = input.mode
    if not mode then
        return nk.json_encode({ error = "MODE_REQUIRED" }), 400
    end

    -- 3. Mode → required players
    local required_players
    if mode == "solo" then
        required_players = 2
    elseif mode == "clash" then
        required_players = 3
    elseif mode == "solo_rush" then
        required_players = 4
    elseif mode == "team_up" then
        required_players = 4
    else
        return nk.json_encode({ error = "INVALID_MODE" }), 400
    end

    -- 4. Matchmaker query (STRING, not table)
    -- We keep it empty and rely on properties
    local query = ""

    -- 5. Matchmaker properties (TABLE)
    local properties = {
        mode = mode
    }

    -- 6. Add to matchmaker (CORRECT ORDER)
    local ticket = nk.matchmaker_add(
        context.user_id,
        context.session_id,
        query,
        1,
        required_players,
        properties
    )

    -- 7. Response
    return nk.json_encode({
        status = "searching",
        ticket = ticket,
        mode = mode,
        players_required = required_players
    }), 200
end

nk.register_rpc(rpc_matchmake_start, "matchmake_start")
