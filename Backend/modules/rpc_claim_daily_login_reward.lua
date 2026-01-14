-- rpc_claim_daily_login_reward.lua
-- CLAIM DAILY LOGIN REWARD (ON BUTTON TAP ONLY)

local nk = require("nakama")
local rate_limit = require("utils_rate_limit")
local daily_login_rewards = require("daily_login_rewards")

local DAILY_REWARDS = {10, 20, 30, 40, 50, 60, 70}

local function today()
  return os.date("!%Y-%m-%d")
end

local function rpc_claim(context, payload)
  if not context or not context.user_id then
    return nk.json_encode({ success = false, error = "unauthorized" })
  end

  local data = {}
  if payload and payload ~= "" then
    local ok, decoded = pcall(nk.json_decode, payload)
    if ok and type(decoded) == "table" then
      data = decoded
    end
  end

  -- 🔒 Explicit intent required
  if data.confirm ~= true then
    return nk.json_encode({ success = false, error = "explicit_claim_required" })
  end

  -- 🔒 Rate limit
  local ok = rate_limit.check(context, "daily_login_claim", 1)
  if not ok then
    return nk.json_encode({ success = false, error = "too_many_requests" })
  end

  local user_id = context.user_id
  local today_str = today()

  -- 🔒 Wallet must exist
  local wallet = nk.wallet_get(user_id)
  if not wallet or wallet.coins == nil then
    return nk.json_encode({ success = false, error = "wallet_not_initialized" })
  end

  local state = daily_login_rewards.get(user_id)

  -- 🔒 One claim per calendar day
  if state.last_claim_date == today_str then
    return nk.json_encode({ success = false, error = "already_claimed_today" })
  end

  local reward = DAILY_REWARDS[state.current_day] or DAILY_REWARDS[1]

  -- 💰 AUTHORITATIVE WALLET UPDATE
  nk.wallet_update(
    user_id,
    { coins = reward },
    { reason = "daily_login", day = state.current_day },
    false
  )

  -- 🔁 Advance / reset streak
  local next_day = state.current_day + 1
  if next_day > 7 then next_day = 1 end

  state.current_day = next_day
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
    next_day = next_day
  })
end

nk.register_rpc(rpc_claim, "daily.login.claim")
