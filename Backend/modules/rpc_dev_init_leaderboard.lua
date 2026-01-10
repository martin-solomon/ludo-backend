local nk = require("nakama")

-- =========================================================
-- DEV ONLY: Initialize Global Wins Leaderboard
-- =========================================================
-- Purpose:
--   - Ensure leaderboard exists
--   - Insert ONE dummy record
--
-- REMOVE AFTER VERIFICATION
-- =========================================================

local function rpc_dev_init_leaderboard(context, payload)

    -- Auth required (any logged-in user)
    if not context or not context.user_id then
        return nk.json_encode({ error = "unauthorized" }), 401
    end

    -- 1️⃣ Create leaderboard (SAFE even if already exists)
    nk.register_leaderboard(
        "global_wins",
        false,      -- authoritative
        "desc",     -- higher wins rank higher
        "incr",     -- increment only
        nil,        -- no reset (lifetime)
        { "wins" }
    )

    -- 2️⃣ Insert ONE dummy win
    nk.leaderboard_record_write(
        "global_wins",
        context.user_id,
        "InitUser",
        1,
        { wins = 1 }
    )

    return nk.json_encode({
        success = true,
        message = "global_wins leaderboard initialized"
    })
end

nk.register_rpc(rpc_dev_init_leaderboard, "dev_init_leaderboard")
