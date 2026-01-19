local nk = require("nakama")

-- ENTRY POINT ONLY
-- This does NOT create matches or join matches itself.
-- It routes to existing, proven RPCs.

local function rpc_match_entry(context, payload)
    if not context or not context.user_id then
        return nk.json_encode({ error = "NO_SESSION" }), 401
    end

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

    -- ROUTING LOGIC (NOT MATCHMAKING LOGIC)
    if mode == "solo" or mode == "clash" or mode == "solo_rush" then
        -- Use quick join pool
        return nk.rpc("rpc_quick_join", nk.json_encode({
            mode = mode
        }), context)
    end

    if mode == "team_up" then
        -- Team-based entry
        return nk.rpc("rpc_create_match", nk.json_encode({
            mode = mode
        }), context)
    end

    return nk.json_encode({ error = "INVALID_MODE" }), 400
end

nk.register_rpc(rpc_match_entry, "match_entry")
