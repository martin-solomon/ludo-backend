local nk = require("nakama")

--------------------------------------------------
-- CREATE LEADERBOARD (SAFE, IDEMPOTENT)
--------------------------------------------------
nk.leaderboard_create(
  "global_rank",
  false,   -- non-authoritative
  "desc",
  "best",
  nil,
  {},
  false
)

--------------------------------------------------
-- FETCH LEADERBOARD
--------------------------------------------------
local function rpc_get_leaderboard(context, payload)
  if not context or not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local input = payload and payload ~= "" and nk.json_decode(payload) or {}
  local limit = input.limit or 20
  local cursor = input.cursor

  local records, new_cursor = nk.leaderboard_records_list(
    "global_rank",
    nil,
    limit,
    cursor,
    nil
  )

  local results = {}

  for _, record in ipairs(records or {}) do
    table.insert(results, {
      rank = record.rank,
      user_id = record.owner_id,
      player_name = record.metadata.display_name or "Player",
      level = record.metadata.level or 1,
      wins = record.metadata.wins or 0,
      avatar_id = record.metadata.avatar_id or "default"
    })
  end

  return nk.json_encode({
    records = results,
    cursor = new_cursor
  })
end

nk.register_rpc(rpc_get_leaderboard, "get_leaderboard")
