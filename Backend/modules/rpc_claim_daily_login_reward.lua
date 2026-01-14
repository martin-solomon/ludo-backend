-- rpc_claim_daily_login_reward.lua
-- SYSTEM-1: DAILY LOGIN CLAIM (RPC SAFE)

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
  -- 🔐 AUTH CHECK
  if not context or not context.user_id then
    return nk.json_encode({ success = false, error = "unauthorized" })
  end

  -- 🔐 EXPLICIT INTENT
  local data = {}
  if payload and payload ~= "" then
    local ok, decoded = pcall(nk.json_decode, payload)
    if ok and type(decoded) == "table" then
      data = decoded
    end
  end

  if data.confirm ~= true then
    return nk.json_encode({ success = false, error = "explicit_claim_required" })
  end

  -- 🛡️ RATE LIMIT
  local ok = rate_limit.check(context, "daily_login_claim", 1)
  if not ok then
    return nk.json_encode({ success = false, error = "too_many_requests" })
  end

  local user_id = context.user_id
  local today_str = today()

  -- 🧾 WALLET MUST EXIST
  local wallet = nk.wallet_get(user_id)
  if not wallet or wallet.coins == nil then
    return nk.json_encode({ success = false, error = "wallet_not_initialized" })
  end

  local state = daily_login_rewards.get_state(user_id)

  -- ❌ ALREADY CLAIMED TODAY
  if state.last_claim_date == today_str then
    return nk.json_encode({ success = false, error = "already_claimed_today" })
  end

  -- 🔁 RESET STREAK IF SKIPPED A DAY
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

  -- 🔒 ADVANCE STATE
  state.current_day = day + 1
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

  -- ✅ SINGLE RETURN (RPC SAFE)
  return nk.json_encode({
    success = true,
    reward = reward,
    next_day = state.current_day
  })
end

nk.register_rpc(rpc_claim_daily_login_reward, "daily.login.claim")
