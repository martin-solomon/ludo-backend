-- rpc_get_daily_login_rewards.lua
-- READ-ONLY DAILY LOGIN STATUS (NO MUTATION)

local nk = require("nakama")
local daily_login_rewards = require("daily_login_rewards")

local DAILY_REWARDS = {10, 20, 30, 40, 50, 60, 70}

local function today_date()
  return os.date("!%Y-%m-%d")
end

local function rpc_get_daily_login_rewards(context, payload)
  if not context or not context.user_id then
    return nk.json_encode({
      success = false,
      error = "unauthorized"
    })
  end

  local user_id = context.user_id
  local today = today_date()

  -- 🔒 Read authoritative state
  local state = daily_login_rewards.get_state(user_id)

  local claimed_today = (state.last_claim_date == today)

  -- 📤 PURE READ RESPONSE
  return nk.json_encode({
    success = true,
    current_day = state.current_day,   -- 1..7
    claimed_today = claimed_today,
    rewards = DAILY_REWARDS
  })
end

nk.register_rpc(rpc_get_daily_login_rewards, "get_daily_login_rewards")
