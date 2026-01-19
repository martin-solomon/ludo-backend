local nk = require("nakama")

local function rpc_matchmake_start(context, payload)
    -- Validate session
    if not context or not context.user_id then
        return { error = "NO_SESSION" }
    end

    -- Payload is already a table
    local input = payload or {}

    local mode = input.mode
    if not mode then
        return { error = "MODE_REQUIRED" }
    end

    -- Mode → required players
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
        return { error = "INVALID_MODE" }
    end

    -- Add to matchmaker
    local ticket = nk.matchmaker_add(
        context.user_id,
        context.session_id,
        "",
        1,
        required_players,
        { mode = mode }
    )

    -- SUCCESS: return ONE table only
    return {
        status = "searching",
        ticket = ticket,
        mode = mode,
        players_required = required_players
    }
end

nk.register_rpc(rpc_matchmake_start, "matchmake_start")
