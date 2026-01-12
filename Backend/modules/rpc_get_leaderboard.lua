local nk = require("nakama")

-- ======================================
-- CREATE LEADERBOARD (SAFE, ON STARTUP)
-- ======================================
nk.leaderboard_create(
  "global_wins",
  false,   -- non-authoritative
  "desc",  -- higher wins rank higher
  "best",
  nil,
  {},
  false
)

-- ======================================
-- READ LEADERBOARD
-- ======================================
local function rpc_get_leaderboard(context, payload)
  if not context or not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local input = payload and payload ~= "" and nk.json_decode(payload) or {}
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
      wins = record.score,
      avatar_id = profile.avatar_id or "default"
    })
  end

  return nk.json_encode({
    records = results,
    cursor = new_cursor
  })
end

nk.register_rpc(rpc_get_leaderboard, "get_leaderboard")

-- ======================================
-- WRITE WIN (INCREMENT)
-- ======================================
local function rpc_submit_win(context, payload)
  if not context or not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  nk.leaderboard_record_write(
    "global_wins",
    context.user_id,
    1,
    0,
    {},
    "incr"
  )

  return nk.json_encode({ status = "ok" })
end

nk.register_rpc(rpc_submit_win, "submit_win")
