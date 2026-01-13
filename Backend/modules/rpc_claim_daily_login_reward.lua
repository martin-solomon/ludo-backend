local nk = require("nakama")

local DAILY_REWARDS = {10, 20, 30, 40, 50, 60, 70}

local function today()
  return os.date("!%Y-%m-%d")
end

local function rpc_claim_daily_login_reward(context, payload)
  if not context or not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local user_id = context.user_id
  local date = today()

  -- Read state
  local objects = nk.storage_read({
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

  if objects and #objects > 0 then
    state = objects[1].value
  end

  -- 🔒 BLOCK DOUBLE CLAIM
  if state.last_claim_date == date then
    return nk.json_encode({ error = "already_claimed_today" }), 409
  end

  -- Determine reward
  local reward = DAILY_REWARDS[state.current_day]
  if not reward then
    state.current_day = 1
    reward = DAILY_REWARDS[1]
  end

  --------------------------------------------------
  -- 💰 UPDATE WALLET (AUTHORITATIVE)
  --------------------------------------------------
  nk.wallet_update(
    user_id,
    { coins = reward },
    { reason = "daily_login", day = state.current_day },
    false
  )

  --------------------------------------------------
  -- 🔒 UPDATE STATE (LOCK TODAY)
  --------------------------------------------------
  state.last_claim_date = date
  state.current_day = state.current_day + 1
  if state.current_day > 7 then
    state.current_day = 1
  end

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

  return nk.json_encode({
    success = true,
    reward = reward,
    next_day = state.current_day
  })
end

nk.register_rpc(rpc_claim_daily_login_reward, "daily.login.claim")
