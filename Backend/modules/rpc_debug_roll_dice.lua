local nk = require("nakama")
local daily_progress = require("daily_task_progress") -- ✅ ADDED

local function rpc_debug_roll_dice(context, payload)
  if not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local data = nk.json_decode(payload)
  local match_id = data.match_id

  if not match_id then
    return nk.json_encode({ error = "match_id required" }), 400
  end

  -- THIS sends a REAL match message
  nk.match_send(
    match_id,
    1,
    nk.json_encode({
      action = "roll_dice"
    }),
    context.user_id
  )

  -- ✅ DAILY TASK: DICE ROLL (ADDED)
  daily_progress.increment(context.user_id, "dice_roll", 1)

  return nk.json_encode({ status = "dice_requested" })
end

nk.register_rpc(rpc_debug_roll_dice, "debug.roll_dice")
