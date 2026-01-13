local nk = require("nakama")
local daily_tasks = require("update_daily_tasks") -- ✅ NEW

local function rpc_debug_roll_dice(context, payload)
  -- 🔒 Auth check
  if not context or not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local user_id = context.user_id

  -- 🔎 Decode payload safely
  local data = {}
  if payload then
    local ok, decoded = pcall(nk.json_decode, payload)
    if ok and type(decoded) == "table" then
      data = decoded
    end
  end

  local match_id = data.match_id
  if not match_id then
    return nk.json_encode({ error = "match_id required" }), 400
  end

  ------------------------------------------------------------------
  -- 🎲 SEND REAL MATCH MESSAGE (UNCHANGED BEHAVIOR)
  ------------------------------------------------------------------
  nk.match_send(
    match_id,
    1,
    nk.json_encode({ action = "roll_dice" }),
    user_id
  )

  ------------------------------------------------------------------
  -- 🟩 DAILY TASK GAMEPLAY HOOK (NEW)
  -- Purpose: Progress dice-related daily tasks
  ------------------------------------------------------------------

  -- Base dice roll (always)
  daily_tasks.update(user_id, "dice_roll", 1)

  -- Optional debug dice value (if provided)
  local dice_value = tonumber(data.dice_value)

  if dice_value then
    -- Rolled a six
    if dice_value == 6 then
      daily_tasks.update(user_id, "dice_six", 1)
    end

    -- Even / odd
    if dice_value % 2 == 0 then
      daily_tasks.update(user_id, "dice_even", 1)
    else
      daily_tasks.update(user_id, "dice_odd", 1)
    end
  end

  ------------------------------------------------------------------
  -- ✅ RESPONSE
  ------------------------------------------------------------------
  return nk.json_encode({
    status = "dice_requested",
    daily_tasks_updated = true
  })
end

nk.register_rpc(rpc_debug_roll_dice, "debug.roll_dice")
