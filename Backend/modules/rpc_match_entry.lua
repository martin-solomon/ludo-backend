local nk = require("nakama")

-- In-memory waiting matches
-- Structure:
-- waiting_matches[mode] = {
--   match_id = string,
--   expected_players = number,
--   joined = number
-- }
local waiting_matches = {}

-- Mode → player count mapping (FROZEN)
local MODE_PLAYERS = {
    solo = 2,
    clash = 3,
    solo_rush = 4,
    team_up = 4,
}

local function rpc_match_entry(context, payload)
    -- 1. Validate session
    if not context or not context.user_id then
        return nk.json_encode({ error = "NO_SESSION" })
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
    if not mode or not MODE_PLAYERS[mode] then
        return nk.json_encode({ error = "INVALID_MODE" })
    end

    local expected_players = MODE_PLAYERS[mode]

    -- 3. Reuse waiting match if exists
    local waiting = waiting_matches[mode]

    if waiting then
        waiting.joined = waiting.joined + 1

        -- If match is now full, clear waiting slot
        if waiting.joined >= waiting.expected_players then
            waiting_matches[mode] = nil
        end

        return nk.json_encode({
            match_id = waiting.match_id,
            mode = mode,
            status = "joined_existing"
        })
    end

    -- 4. Create new match
    local match_id = nk.match_create("ludo_match", {
        mode = mode,
        expected_players = expected_players,
        owner = context.user_id
    })

    -- 5. Register as waiting match
    waiting_matches[mode] = {
        match_id = match_id,
        expected_players = expected_players,
        joined = 1
    }

    return nk.json_encode({
        match_id = match_id,
        mode = mode,
        status = "created_new"
    })
end

nk.register_rpc(rpc_match_entry, "match_entry")
