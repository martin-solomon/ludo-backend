-- rpc_claim_daily_login_reward.lua
-- FINAL, SAFE DAILY LOGIN CLAIM

local nk = require("nakama")
local rate_limit = require("utils_rate_limit")
local daily_login_rewards = require("daily_login_rewards")

local DAILY_REWARDS = {10,20,30,40,50,60,70}

local function today()
  return os.date("!%Y-%m-%d")
end

local function rpc_claim_daily_login_reward(context, payload)
  if not context or not context.user_id then
    return nk.json_encode({ error = "unauthorized" })
  end

  -- explicit intent
  local data = nk.json_decode(payload or "{}")
  if data.confirm ~= true then
    return nk.json_encode({ error = "explicit_claim_required" })
  end

  -- rate limit
  if not rate_limit.check(context, "daily_login_claim", 1) then
    return nk.json_encode({ error = "too_many_requests" })
  end

  local user_id = context.user_id
  local day = today()

  -- 🔒 CLAIM LOCK (ABSOLUTE AUTHORITY)
  local existing = nk.storage_read({
    { collection = "daily_login_claims", key = day, user_id = user_id }
  })

  if existing and #existing > 0 then
    return nk.json_encode({ error = "already_claimed_today" })
  end

  local state = daily_login_rewards.get_state(user_id)
  local reward = DAILY_REWARDS[state.current_day] or DAILY_REWARDS[1]

  -- 🔐 WRITE CLAIM LOCK FIRST
  nk.storage_write({
    {
      collection = "daily_login_claims",
      key = day,
      user_id = user_id,
      value = {
        reward = reward,
        claimed_at = os.time()
      },
      permission_read = 0,
      permission_write = 0
    }
  })

  -- 💰 WALLET UPDATE
  nk.wallet_update(
    user_id,
    { coins = reward },
    { reason = "daily_login", day = state.current_day },
    false
  )

  -- 🔁 ADVANCE / RESET STREAK
  state.current_day = state.current_day + 1
  if state.current_day > 7 then
    state.current_day = 1
  end

  daily_login_rewards.save_state(user_id, state)

  return nk.json_encode({
    success = true,
    reward = reward,
    next_day = state.current_day
  })
end

nk.register_rpc(rpc_claim_daily_login_reward, "daily.login.claim")
