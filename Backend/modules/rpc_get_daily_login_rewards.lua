local nk = require("nakama")
local state_mod = require("daily_login_state")

local DAILY_REWARDS = {10,20,30,40,50,60,70}

local function today()
  return os.date("!%Y-%m-%d")
end

local function rpc_get(context, payload)
  if not context.user_id then
    return nk.json_encode({ success=false, error="unauthorized" })
  end

  local state = state_mod.get_or_create(context.user_id)

  return nk.json_encode({
    success = true,
    current_day = state.current_day,
    claimed_today = (state.last_claim_date == today()),
    rewards = DAILY_REWARDS
  })
end

nk.register_rpc(rpc_get, "get_daily_login_rewards")
