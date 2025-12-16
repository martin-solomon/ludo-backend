local nk = require("nakama")

local function rpc_get_leaderboard(context, payload)
  local records = nk.leaderboard_records_list(
    "global_level",
    nil,
    20,
    nil,
    nil
  )

  return nk.json_encode(records)
end

nk.register_rpc(rpc_get_leaderboard, "get_leaderboard")
