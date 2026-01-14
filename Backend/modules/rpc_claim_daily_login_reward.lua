local nk = require("nakama")
local state_mod = require("daily_login_state")

local DAILY_REWARDS = {10,20,30,40,50,60,70}

local function today()
  return os.date("!%Y-%m-%d")
end

local function rpc_claim(context, payload)
  if not context.user_id then
    return nk.json_encode({ success=false, error="unauthorized" })
  end

  local data = nk.json_decode(payload or "{}")
  if data.confirm ~= true then
    return nk.json_encode({ success=false, error="explicit_claim_required" })
  end

  local user_id = context.user_id
  local now = today()

  -- 🔒 READ STATE
  local state = state_mod.get_or_create(user_id)

  -- 🔒 BLOCK DOUBLE CLAIM
  if state.last_claim_date == now then
    return nk.json_encode({ success=false, error="already_claimed_today" })
  end

  -- 🔁 STREAK RESET IF SKIPPED
  if state.last_claim_date ~= "" then
    local diff = os.difftime(
      os.time({year=tonumber(now:sub(1,4)), month=tonumber(now:sub(6,7)), day=tonumber(now:sub(9,10))}),
      os.time({year=tonumber(state.last_claim_date:sub(1,4)), month=tonumber(state.last_claim_date:sub(6,7)), day=tonumber(state.last_claim_date:sub(9,10))})
    )
    if diff > 86400 then
      state.current_day = 1
    end
  end

  local reward = DAILY_REWARDS[state.current_day] or 10

  -- 🔐 WRITE STATE FIRST (AUTHORITATIVE)
  state.last_claim_date = now
  state.current_day = state.current_day + 1
  if state.current_day > 7 then state.current_day = 1 end

  nk.storage_write({
    {
      collection = "daily_login_state",
      key = "state",
      user_id = user_id,
      value = state,
      permission_read = 1,
      permission_write = 0
    }
  })

  -- 💰 WALLET UPDATE (ONLY AFTER STATE COMMIT)
  nk.wallet_update(user_id, { coins = reward }, { reason="daily_login" })

  return nk.json_encode({
    success = true,
    reward = reward
  })
end

nk.register_rpc(rpc_claim, "daily.login.claim")
