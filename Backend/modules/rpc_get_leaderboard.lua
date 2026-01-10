local nk = require("nakama")

-- =========================================================
-- BOSS DAY-3 : WINS LEADERBOARD FETCH
-- =========================================================
-- Purpose:
--   Fetch global leaderboard sorted by ONLINE match wins
--
-- Features:
--   - Descending order (handled by Nakama)
--   - Pagination support
--   - Persistent across restarts
--
-- Leaderboard ID:
--   global_wins
-- =========================================================

local function rpc_get_leaderboard(context, payload)

    -- 🔒 AUTH REQUIRED
    if not context or not context.user_id then
        return nk.json_encode({ error = "unauthorized" }), 401
    end

    local input = nk.json_decode(payload or "{}")

    local cursor = input.cursor or nil
    local limit = input.limit or 20

    -- 🔥 FETCH WINS LEADERBOARD
    local records, new_cursor = nk.leaderboard_records_list(
        "global_wins",   -- ✅ WINS leaderboard
        nil,             -- owner_id (nil = global)
        limit,
        cursor,
        nil              -- expiry (unused)
    )

    return nk.json_encode({
        records = records,
        cursor = new_cursor
    })
end

-- RPC REGISTRATION
nk.register_rpc(rpc_get_leaderboard, "get_leaderboard")
