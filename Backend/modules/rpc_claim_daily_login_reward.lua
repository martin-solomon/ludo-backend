local nk = require("nakama")
local rate_limit = require("utils_rate_limit")
local daily_login_rewards = require("daily_login_rewards")

local DAILY_REWARDS = {10, 20, 30, 40, 50, 60, 70}

local function today()
  return os.date("!%Y-%m-%d")
end

local function rpc_claim_daily_login_reward(context, payload)
  if not context or not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  -- 🔒 Explicit intent required
  local data = nk.json_decode(payload or "{}")
  if data.confirm ~= true then
    return nk.json_encode({ error = "explicit_claim_required" }), 400
  end

  -- 🔒 Rate-limit
  local ok = rate_limit.check(context, "daily_login_claim", 1)
  if not ok then
    return nk.json_encode({ error = "too_many_requests" }), 429
  end

  local user_id = context.user_id
  local today_str = today()

  -- 🔒 Ensure wallet exists
  local wallet = nk.wallet_get(user_id)
  if not wallet or wallet.coins == nil then
    return nk.json_encode({ error = "wallet_not_initialized" }), 500
  end

  local state = daily_login_rewards.get_state(user_id)

  -- ❌ Double claim block
  if state.last_claim_date == today_str then
    return nk.json_encode({ error = "already_claimed_today" }), 409
  end

  local day = state.current_day
  local reward = DAILY_REWARDS[day] or DAILY_REWARDS[1]

  -- 💰 AUTHORITATIVE COIN UPDATE
  nk.wallet_update(
    user_id,
    { coins = reward },
    { reason = "daily_login", day = day },
    false
  )

  -- Advance day
  day = day + 1
  if day > 7 then day = 1 end

  state.current_day = day
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
