local nk = require("nakama")

local function rpc_get_leaderboard(context, payload)
  if not context or not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local input = nk.json_decode(payload or "{}")
  local limit = input.limit or 20
  local cursor = input.cursor

nk.leaderboard_record_write(
  "global_wins",        -- leaderboard_id
  user_id,              -- owner_id
  username or user_id,  -- display name
  1,                    -- score (wins)
  nil,                  -- subscore (MUST be number or nil)
  { wins = 1 }          -- metadata (optional)
)

  return nk.json_encode({
    records = records,
    cursor = new_cursor
  })
end

nk.register_rpc(rpc_get_leaderboard, "get_leaderboard")

