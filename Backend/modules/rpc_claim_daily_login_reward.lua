local nk = require("nakama")
local daily_login_state = require("daily_login_rewards")

local DAILY_REWARDS = {10,20,30,40,50,60,70}

local function today()
  return os.date("!%Y-%m-%d")
end

local function rpc_claim(context, payload)
  if not context or not context.user_id then
    return nk.json_encode({ success = false, error = "unauthorized" })
  end

  local data = nk.json_decode(payload or "{}")
  if data.confirm ~= true then
    return nk.json_encode({ success = false, error = "confirm_required" })
  end

  local user_id = context.user_id
  local now = today()

  local state = daily_login_state.get(user_id)

  -- Already claimed today
  if state.last_claim_date == now then
    return nk.json_encode({
      success = false,
      error = "already_claimed_today"
    })
  end

  -- Reset streak if skipped a day
  if state.last_claim_date ~= "" and state.last_claim_date ~= now then
    local diff = os.difftime(os.time(), os.time{year=state.last_claim_date:sub(1,4), month=state.last_claim_date:sub(6,7), day=state.last_claim_date:sub(9,10)})
    if diff > 86400 then
      state.current_day = 1
    end
  end

  local reward = DAILY_REWARDS[state.current_day] or DAILY_REWARDS[1]

  -- WALLET UPDATE (ONLY HERE)
  nk.wallet_update(
    user_id,
    { coins = reward },
    { reason = "daily_login", day = state.current_day },
    false
  )

  -- Advance day
  state.last_claim_date = now
  state.current_day = state.current_day + 1
  if state.current_day > 7 then state.current_day = 1 end

  daily_login_state.update(user_id, state)

  return nk.json_encode({
    success = true,
    reward = reward,
    next_day = state.current_day
  })
end

nk.register_rpc(rpc_claim, "daily.login.claim")

