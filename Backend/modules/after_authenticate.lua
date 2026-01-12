local nk = require("nakama")
local daily_rewards = require("daily_rewards_logic")

local function after_authenticate(context, payload)
    if not context or not context.user_id then
        return
    end

    -- DAILY REWARD TRIGGER (FIRST LOGIN OF THE DAY)
    daily_rewards.on_login(context.user_id)
end

nk.register_after_authenticate(after_authenticate)
