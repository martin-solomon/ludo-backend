local nk = require("nakama")

local DAILY_REWARDS = {10, 20, 30, 40, 50, 60, 70}

local function today_date()
    return os.date("!%Y-%m-%d")
end

local function rpc_get_daily_login_rewards(context, payload)
    -- 🔐 Auth check
    if not context or not context.user_id then
        return nk.json_encode({ error = "unauthorized" }), 401
    end

    local user_id = context.user_id
    local today = today_date()

    -- 📖 Read stored state
    local records = nk.storage_read({
        {
            collection = "daily_login_rewards",
            key = "state",
            user_id = user_id
        }
    })

    -- ✅ DEFAULT STATE (authoritative)
    local stored = {
        day_index = 0,           -- how many rewards already claimed
        last_claim_date = ""
    }

    if records and #records > 0 and type(records[1].value) == "table" then
        stored.day_index = tonumber(records[1].value.day_index) or 0
        stored.last_claim_date = records[1].value.last_claim_date or ""
    end

    -- 🧠 Calendar protection only
    local claimed_today = (stored.last_claim_date == today)

    -- 🎯 UI day is DERIVED, never stored
    local current_day = stored.day_index + 1

    -- ⛔ Clamp to max rewards
    if current_day > #DAILY_REWARDS then
        current_day = #DAILY_REWARDS
    end

    -- 📤 READ-ONLY RESPONSE (NO MUTATION)
    return nk.json_encode({
        current_day = current_day,
        claimed_today = claimed_today,
        rewards = DAILY_REWARDS
    })
end

nk.register_rpc(rpc_get_daily_login_rewards, "get_daily_login_rewards")
