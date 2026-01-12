local nk = require("nakama")

local function rpc_get_leaderboard(context, payload)
  if not context or not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local input = payload and payload ~= "" and nk.json_decode(payload) or {}
  local limit = input.limit or 20
  local cursor = input.cursor

  local records, new_cursor = nk.leaderboard_records_list(
    "ludo_global",   -- SAME ID AS WRITE
    nil,
    limit,
    cursor,
    nil
  )

  local results = {}

  for _, record in ipairs(records or {}) do
    local user_id = record.owner_id

    -- Fetch public profile (display name)
    local objects = nk.storage_read({
      {
        collection = "profile",
        key = "data",
        user_id = user_id
      }
    })

    local profile = objects and objects[1] and objects[1].value or {}

    table.insert(results, {
      rank = record.rank,
      user_id = user_id,
      player_name = profile.display_name or "Player",
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
