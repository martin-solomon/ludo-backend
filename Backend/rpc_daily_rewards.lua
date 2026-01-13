local DAILY_REWARDS = {
  [1] = { coins = 10 },
  [2] = { coins = 20 },
  [3] = { coins = 30 },
  [4] = { coins = 40 },
  [5] = { coins = 50 },
  [6] = { coins = 60 },
  [7] = { coins = 70 }
}

local COLLECTION = "daily_rewards"
local KEY = "status"

local function today()
  return os.date("!%Y-%m-%d")
end

local function get_state(nk, user_id)
  local r = nk.storage_read({
    { collection = COLLECTION, key = KEY, user_id = user_id }
  })

  if r and #r > 0 then
    return r[1].value
  end

  local state = {
    week_start = today(),
    last_claim = nil,
    current_day = 1
  }

  nk.storage_write({
    {
      collection = COLLECTION,
      key = KEY,
      user_id = user_id,
      value = state,
      permission_read = 0,
      permission_write = 0
    }
  })

  return state
end

local function get_daily_rewards(nk, user_id)
  local state = get_state(nk, user_id)

  return {
    day = state.current_day,
    claimed_today = (state.last_claim == today()),
    reward = DAILY_REWARDS[state.current_day],
    all_rewards = DAILY_REWARDS
  }
end

local function claim_daily_reward(nk, user_id)
  local state = get_state(nk, user_id)

  if state.last_claim == today() then
    return nil, "already_claimed"
  end

  local reward = DAILY_REWARDS[state.current_day]
  if not reward then
    return nil, "invalid_day"
  end

  nk.wallet_update(user_id, { coins = reward.coins }, {}, false)

  state.last_claim = today()
  state.current_day = state.current_day + 1

  if state.current_day > 7 then
    state.current_day = 1
    state.week_start = today()
    state.last_claim = nil
  end

  nk.storage_write({
    {
      collection = COLLECTION,
      key = KEY,
      user_id = user_id,
      value = state,
      permission_read = 0,
      permission_write = 0
    }
  })

  return reward, nil
end

return {
  get = get_daily_rewards,
  claim = claim_daily_reward
}
