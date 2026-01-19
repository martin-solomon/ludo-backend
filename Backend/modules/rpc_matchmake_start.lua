local nk = require("nakama")

local function rpc_matchmake_start(context, payload)
    if not context or not context.user_id then
        return nk.json_encode({ error = "NO_SESSION" })
    end

    -- Decode payload
    local input = {}
    if payload and payload ~= "" then
        local ok, decoded = pcall(nk.json_decode, payload)
        if ok and type(decoded) == "table" then
            input = decoded
        end
    end

    local mode = input.mode
    if not mode then
        return nk.json_encode({ error = "MODE_REQUIRED" })
    end

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
        return nk.json_encode({ error = "INVALID_MODE" })
    end

    -- 🔐 SAFETY CHECK
    if type(nk.matchmaker_add) ~= "function" then
        nk.logger_error("matchmaker_add is not a function")
        return nk.json_encode({ error = "MATCHMAKER_UNAVAILABLE" })
    end

    local ok, ticket = pcall(
        nk.matchmaker_add,
        context.user_id,
        context.session_id,
        "",
        1,
        required_players,
        { mode = mode },
        {}
    )

    if not ok then
        nk.logger_error("matchmaker_add failed: " .. tostring(ticket))
        return nk.json_encode({ error = "MATCHMAKER_FAILED" })
    end

    return nk.json_encode({
        status = "searching",
        ticket = ticket,
        mode = mode,
        players_required = required_players
    })
end

nk.register_rpc(rpc_matchmake_start, "matchmake_start")
