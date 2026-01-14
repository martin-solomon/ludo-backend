-- rpc_claim_daily_login_reward.lua
-- SYSTEM-1: DAILY LOGIN CLAIM (AUTHORITATIVE)

local nk = require("nakama")
local rate_limit = require("utils_rate_limit")
local daily_login_rewards = require("daily_login_rewards")

local DAILY_REWARDS = {10, 20, 30, 40, 50, 60, 70}

local function today()
  return os.date("!%Y-%m-%d")
end

local function to_time(date_str)
  return os.time({
    year  = tonumber(date_str:sub(1,4)),
    month = tonumber(date_str:sub(6,7)),
    day   = tonumber(date_str:sub(9,10))
  })
end

local function rpc_claim_daily_login_reward(context, payload)
  if not context or not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  -- explicit intent required
  local data = nk.json_decode(payload or "{}")
  if data.confirm ~= true then
    return nk.json_encode({ error = "explicit_claim_required" }), 400
  end

  -- rate limit safety
  local ok = rate_limit.check(context, "daily_login_claim", 1)
  if not ok then
    return nk.json_encode({ error = "too_many_requests" }), 429
  end

  local user_id = context.user_id
  local today_str = today()

  -- wallet must exist
  local wallet = nk.wallet_get(user_id)
  if not wallet or wallet.coins == nil then
    return nk.json_encode({ error = "wallet_not_initialized" }), 500
  end

  local state = daily_login_rewards.get_state(user_id)

  -- already claimed today
  if state.last_claim_date == today_str then
    return nk.json_encode({ error = "already_claimed_today" }), 409
  end

  -- streak reset if skipped a day
  if state.last_claim_date ~= "" then
    local diff = os.difftime(
      to_time(today_str),
      to_time(state.last_claim_date)
    )

    if diff > 86400 then
      state.current_day = 1
    end
  end

  local day = state.current_day
  local reward = DAILY_REWARDS[day] or DAILY_REWARDS[1]

  -- 💰 AUTHORITATIVE WALLET UPDATE
  nk.wallet_update(
    user_id,
    { coins = reward },
    { reason = "daily_login", day = day },
    false
  )

  -- advance streak
  state.current_day = state.current_day + 1
  if state.current_day > 7 then
    state.current_day = 1
  end

  state.last_claim_date = today_str

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
