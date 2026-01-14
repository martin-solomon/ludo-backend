-- rpc_get_daily_login_rewards.lua

local nk = require("nakama")
local daily_login_rewards = require("daily_login_rewards")

local DAILY_REWARDS = {10,20,30,40,50,60,70}

local function today()
  return os.date("!%Y-%m-%d")
end

local function rpc_get_daily_login_rewards(context, payload)
  if not context or not context.user_id then
    return nk.json_encode({ error = "unauthorized" })
  end

  local user_id = context.user_id
  local day = today()

  -- 🔒 Check claim lock
  local claim = nk.storage_read({
    { collection = "daily_login_claims", key = day, user_id = user_id }
  })

  local claimed_today = (claim and #claim > 0)

  local state = daily_login_rewards.get_state(user_id)

  return nk.json_encode({
    success = true,
    current_day = state.current_day,
    claimed_today = claimed_today,
    rewards = DAILY_REWARDS
  })
end

nk.register_rpc(rpc_get_daily_login_rewards, "get_daily_login_rewards")
