-- rpc_daily_rewards.lua
-- SYSTEM 1: Daily Rewards (Login Rewards)

local nk = require("nakama")

--------------------------------------------------
-- CONFIG
--------------------------------------------------

local REWARD_TABLE = {
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

--------------------------------------------------
-- HELPERS
--------------------------------------------------

local function today()
  return os.date("!%Y-%m-%d")
end

local function days_between(date1, date2)
  local y1, m1, d1 = date1:match("(%d+)%-(%d+)%-(%d+)")
  local y2, m2, d2 = date2:match("(%d+)%-(%d+)%-(%d+)")
  local t1 = os.time({ year=y1, month=m1, day=d1, hour=0 })
  local t2 = os.time({ year=y2, month=m2, day=d2, hour=0 })
  return math.floor(os.difftime(t1, t2) / 86400)
end

local function load_state(user_id)
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

local function reset_if_needed(state)
  if days_between(today(), state.week_start) >= 7 then
    state.week_start = today()
    state.last_claim = nil
    state.current_day = 1
    return true
  end
  return false
end

--------------------------------------------------
-- RPC: FETCH DAILY REWARDS
--------------------------------------------------

local function daily_rewards_fetch(context, payload)
  if not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local state = load_state(context.user_id)
  reset_if_needed(state)

  return nk.json_encode({
    current_day = state.current_day,
    claimed_today = (state.last_claim == today()),
    rewards = REWARD_TABLE
  })
end

--------------------------------------------------
-- RPC: CLAIM DAILY REWARD
--------------------------------------------------

local function daily_rewards_claim(context, payload)
  if not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local state = load_state(context.user_id)
  reset_if_needed(state)

  if state.last_claim == today() then
    return nk.json_encode({ error = "already_claimed_today" }), 400
  end

  local reward = REWARD_TABLE[state.current_day]
  if not reward then
    return nk.json_encode({ error = "invalid_reward_day" }), 500
  end

  nk.wallet_update(context.user_id, { coins = reward.coins }, {}, false)

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
      user_id = context.user_id,
      value = state,
      permission_read = 0,
      permission_write = 0
    }
  })

  return nk.json_encode({
    success = true,
    reward = reward,
    next_day = state.current_day
  })
end

--------------------------------------------------
-- ✅ RPC REGISTRATION (MANDATORY)
--------------------------------------------------

nk.register_rpc(daily_rewards_fetch, "daily_rewards.fetch")
nk.register_rpc(daily_rewards_claim, "daily_rewards.claim")
