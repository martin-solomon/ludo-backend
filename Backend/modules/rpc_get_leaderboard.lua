local nk = require("nakama")

-- =========================================================
-- BOSS DAY-3 : WINS LEADERBOARD FETCH
-- =========================================================
local function rpc_get_leaderboard(context, payload)

  if not context or not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local input = nk.json_decode(payload or "{}")
  local limit = input.limit or 20
  local cursor = input.cursor

  local records, new_cursor = nk.leaderboard_records_list(
    "global_wins",
    nil,
    limit,
    cursor,
    nil
  )

  return nk.json_encode({
    records = records,
    cursor = new_cursor
  })
end

nk.register_rpc(rpc_get_leaderboard, "get_leaderboard")
