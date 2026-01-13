local nk = require("nakama")

local DAILY_REWARDS = {10, 20, 30, 40, 50, 60, 70}

local function today()
  return os.date("!%Y-%m-%d")
end

local function rpc_claim_daily_login_reward(context, payload)
  -- 🔐 Auth check
  if not context or not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local user_id = context.user_id
  local today_date = today()

  -- 📖 Read stored state
  local objects = nk.storage_read({
    {
      collection = "daily_login_rewards",
      key = "state",
      user_id = user_id
    }
  })

  -- ✅ Canonical state (ONLY SOURCE OF TRUTH)
  local stored = {
    day_index = 0,           -- how many rewards already claimed
    last_claim_date = ""
  }

  if objects and #objects > 0 and type(objects[1].value) == "table" then
    stored.day_index = tonumber(objects[1].value.day_index) or 0
    stored.last_claim_date = objects[1].value.last_claim_date or ""
  end

  --------------------------------------------------
  -- 🔒 BLOCK DOUBLE CLAIM (HARD LOCK)
  --------------------------------------------------
  if stored.last_claim_date == today_date then
    return nk.json_encode({ error = "already_claimed_today" }), 409
  end

  --------------------------------------------------
  -- 🎁 DETERMINE REWARD (SAFE)
  --------------------------------------------------
  local reward = DAILY_REWARDS[stored.day_index + 1]

  -- Reset cycle after day 7
  if not reward then
    stored.day_index = 0
    reward = DAILY_REWARDS[1]
  end

  --------------------------------------------------
  -- 💰 UPDATE WALLET (AUTHORITATIVE, ANTI-CHEAT)
  --------------------------------------------------
  nk.wallet_update(
    user_id,
    { coins = reward },
    { reason = "daily_login", day = stored.day_index + 1 },
    false
  )

  --------------------------------------------------
  -- 📌 ADVANCE PROGRESSION (ONCE PER DAY)
  --------------------------------------------------
  stored.day_index = stored.day_index + 1
  stored.last_claim_date = today_date

  --------------------------------------------------
  -- 💾 SAVE STATE
  --------------------------------------------------
  nk.storage_write({
    {
      collection = "daily_login_rewards",
      key = "state",
      user_id = user_id,
      value = stored,
      permission_read = 1,
      permission_write = 0
    }
  })

  --------------------------------------------------
  -- ✅ RESPONSE (FRONTEND SAFE)
  --------------------------------------------------
  return nk.json_encode({
    success = true,
    reward = reward,
    next_day = stored.day_index + 1
  })
end

nk.register_rpc(rpc_claim_daily_login_reward, "daily.login.claim")
