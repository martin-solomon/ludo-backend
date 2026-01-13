local nk = require("nakama")

local DAILY_REWARDS = {10, 20, 30, 40, 50, 60, 70}

local function today_date()
    return os.date("!%Y-%m-%d")
end

local function rpc_get_daily_login_rewards(context, payload)
    if not context or not context.user_id then
        return nk.json_encode({ error = "unauthorized" }), 401
    end

    local user_id = context.user_id
    local today = today_date()

    local records = nk.storage_read({
        {
            collection = "daily_login_rewards",
            key = "state",
            user_id = user_id
        }
    })

    local state = {
        current_day = 1,
        last_claim_date = ""
    }

    if records and #records > 0 then
        state = records[1].value
    end

    local claimed_today = (state.last_claim_date == today)

    return nk.json_encode({
        current_day = state.current_day,
        claimed_today = claimed_today,
        rewards = DAILY_REWARDS
    })
end

nk.register_rpc(rpc_get_daily_login_rewards, "get_daily_login_rewards")
