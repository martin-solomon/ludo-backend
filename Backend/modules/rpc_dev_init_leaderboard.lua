local nk = require("nakama")

local function rpc_dev_init_leaderboard(context, payload)
    if not context or not context.user_id then
        return nk.json_encode({ error = "unauthorized" }), 401
    end

    -- Create FIRST record → this makes leaderboard exist
    nk.leaderboard_record_write(
        "global_wins",
        context.user_id,
        "InitUser",
        1,
        { dev_init = true }
    )

    return nk.json_encode({
        success = true,
        message = "Leaderboard initialized with first record"
    })
end

nk.register_rpc(rpc_dev_init_leaderboard, "dev_init_leaderboard")
