local nk = require("nakama")

local M = {}

-- fixed reward table
local DAILY_REWARDS = {10, 20, 30, 40, 50, 60, 70}

local function today_date()
    return os.date("!%Y-%m-%d")
end

function M.process_login(context)
    if not context or not context.user_id then
        return
    end

    local user_id = context.user_id
    local today = today_date()

    -- read existing state
    local records = nk.storage_read({
        {
            collection = "daily_login_rewards",
            key = "state",
            user_id = user_id
        }
    })

    local state
    if records and #records > 0 then
        state = records[1].value
    else
        state = {
            current_day = 1,
            last_claim_date = ""
        }
    end

    -- already claimed today
    if state.last_claim_date == today then
        return
    end

    -- grant reward
    local day = state.current_day
    local reward = DAILY_REWARDS[day] or 10

    nk.wallet_update(user_id, { coins = reward })

    -- advance day
    day = day + 1
    if day > 7 then
        day = 1
    end

    state.current_day = day
    state.last_claim_date = today

    -- save updated state
    nk.storage_write({
        {
            collection = "daily_login_rewards",
            key = "state",
            user_id = user_id,
            value = state,
            permission_read = 1,
            permission_write = 0
        }
    })
end

return M
