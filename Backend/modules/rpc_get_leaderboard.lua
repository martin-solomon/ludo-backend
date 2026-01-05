local nk = require("nakama")

local function rpc_get_leaderboard(context, payload)
  -- 🔒 AUTH REQUIRED
  if not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local input = nk.json_decode(payload or "{}")

  -- Optional cursor for pagination
  local cursor = input.cursor or nil
  local limit = input.limit or 20

  local records, new_cursor = nk.leaderboard_records_list(
    "global_level",
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
