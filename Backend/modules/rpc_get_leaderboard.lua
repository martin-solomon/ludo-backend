local nk = require("nakama")

-- =========================================================
-- LEVEL + WINS LEADERBOARD FETCH
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

  local results = {}

  for _, record in ipairs(records or {}) do
    local user_id = record.owner_id

    -- Read profile for display data
    local objects = nk.storage_read({
      { collection = "profile", key = "player", user_id = user_id }
    })

    local profile = {}
    if objects and #objects > 0 then
      profile = objects[1].value or {}
    end

    table.insert(results, {
      rank = record.rank,
      user_id = user_id,
      player_name = profile.username or record.username or "Player",
      level = profile.level or 1,
      wins = profile.wins or 0,
      avatar_id = profile.avatar_id or "default"
    })
  end

  return nk.json_encode({
    records = results,
    cursor = new_cursor
  })
end

nk.register_rpc(rpc_get_leaderboard, "get_leaderboard")
