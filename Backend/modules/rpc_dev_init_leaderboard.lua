-- dev_init_leaderboard.lua
local nk = require("nakama")

local function rpc_dev_init_leaderboard(context, payload)
  if not context or not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  -- ✅ Create leaderboard by writing FIRST record
  nk.leaderboard_record_write(
    "global_wins",          -- leaderboard_id
    context.user_id,        -- owner_id
    "InitUser",             -- username
    1,                      -- score (wins)
    nil,                    -- subscore (MUST be number or nil)
    { init = true }         -- metadata
  )

  return nk.json_encode({
    success = true,
    message = "Leaderboard initialized"
  })
end

nk.register_rpc(rpc_dev_init_leaderboard, "dev_init_leaderboard")
