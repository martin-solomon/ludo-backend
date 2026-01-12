local nk = require("nakama")
local daily_rewards = require("daily_rewards_logic")

local function get_daily_rewards(context, payload)
  if not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local status = daily_rewards.get_status(context.user_id)

  return nk.json_encode(status)
end

nk.register_rpc(get_daily_rewards, "daily.rewards.get")
