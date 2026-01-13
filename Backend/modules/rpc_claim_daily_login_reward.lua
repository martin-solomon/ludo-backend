-- rpc_claim_daily_login_reward.lua
-- Claim daily login reward (System-1) — HARDENED & PRODUCTION SAFE

local nk = require("nakama")
local rate_limit = require("utils_rate_limit")

local DAILY_REWARDS = {10, 20, 30, 40, 50, 60, 70}

local function today()
  return os.date("!%Y-%m-%d")
end

local function rpc_claim_daily_login_reward(context, payload)
  --------------------------------------------------
  -- 🔐 AUTH CHECK
  --------------------------------------------------
  if not context or not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local user_id = context.user_id
  local date = today()

  --------------------------------------------------
  -- 🔐 HARDENING #1 — RATE LIMIT (ANTI-SPAM)
  --------------------------------------------------
  local ok, reason = rate_limit.check(context, "daily_login_claim", 1)
  if not ok then
    return nk.json_encode({ error = "too_many_requests" }), 429
  end

  --------------------------------------------------
  -- 📦 PARSE PAYLOAD
  --------------------------------------------------
  local data = {}
  if payload and payload ~= "" then
    local success, decoded = pcall(nk.json_decode, payload)
    if success and type(decoded) == "table" then
      data = decoded
    end
  end

  --------------------------------------------------
  -- 🔐 HARDENING #2 — EXPLICIT USER INTENT REQUIRED
  --------------------------------------------------
  if data.confirm ~= true then
    return nk.json_encode({ error = "explicit_claim_required" }), 400
  end

  --------------------------------------------------
  -- 📖 READ DAILY LOGIN STATE
  --------------------------------------------------
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

  --------------------------------------------------
  -- 🔒 BLOCK DOUBLE CLAIM (SAME DAY)
  --------------------------------------------------
  if state.last_claim_date == date then
    return nk.json_encode({ error = "already_claimed_today" }), 409
  end

  --------------------------------------------------
  -- 🔐 HARDENING #3 — WALLET MUST EXIST
  --------------------------------------------------
  local wallet = nk.wallet_get(user_id)
  if not wallet or wallet.coins == nil then
    return nk.json_encode({ error = "wallet_not_initialized" }), 500
  end

  --------------------------------------------------
  -- 🎁 DETERMINE REWARD
  --------------------------------------------------
  local reward = DAILY_REWARDS[state.current_day]
  if not reward then
    state.current_day = 1
    reward = DAILY_REWARDS[1]
  end

  --------------------------------------------------
  -- 💰 GRANT COINS (AUTHORITATIVE)
  --------------------------------------------------
  nk.wallet_update(
    user_id,
    { coins = reward },
    { reason = "daily_login", day = state.current_day },
    true
  )

  --------------------------------------------------
  -- 🔒 UPDATE STATE (ADVANCE DAY, LOCK TODAY)
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

  --------------------------------------------------
  -- ✅ SUCCESS
  --------------------------------------------------
  return nk.json_encode({
    success = true,
    reward = reward,
    next_day = state.current_day
  })
end

nk.register_rpc(rpc_claim_daily_login_reward, "daily.login.claim")
