local nk = require("nakama")

local function rpc_dev_init_leaderboard(context, payload)
  -- Must be authenticated (normal user is fine for DEV)
  if not context or not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  -- 🔥 WRITE FIRST RECORD (THIS CREATES THE LEADERBOARD)
  nk.leaderboard_record_write(
    "global_wins",              -- leaderboard_id
    context.user_id,            -- owner_id
    "InitPlayer",               -- display name
    0,                           -- score (wins = 0 is OK)
    nil,                         -- subscore MUST be number or nil
    { init = true }              -- metadata
  )

  return nk.json_encode({
    success = true,
    message = "global_wins leaderboard initialized"
  })
end

nk.register_rpc(rpc_dev_init_leaderboard, "dev_init_leaderboard")
