local nk = require("nakama")
local avatar_catalog = require("avatar_catalog")

local function rpc_get_leaderboard(context, payload)
  if not context or not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local input = payload and payload ~= "" and nk.json_decode(payload) or {}
  local limit = input.limit or 20
  local cursor = input.cursor

  local records, new_cursor = nk.leaderboard_records_list(
    "ludo_global",   -- 🔥 SAME ID AS WRITE
    nil,
    limit,
    cursor,
    nil
  )

  local results = {}

  for _, record in ipairs(records or {}) do
    local user_id = record.owner_id

    local objects = nk.storage_read({
      { collection = "user_profiles", key = user_id, user_id = user_id }
    })

    local profile = objects and objects[1] and objects[1].value or {}

    ----------------------------------------------------------
    -- ✅ NEW AVATAR LOGIC (REPLACED)
    ----------------------------------------------------------
    local avatar = profile.active_avatar
    if not avatar or not avatar_catalog.is_valid(avatar.id) then
      avatar = avatar_catalog.DEFAULT
    end
    ----------------------------------------------------------

    table.insert(results, {
      rank = record.rank,
      user_id = user_id,
      player_name = profile.username or record.username or "Player",
      level = profile.level or 1,
      wins = record.score,
      avatar = avatar
    })
  end

  return nk.json_encode({
    records = results,
    cursor = new_cursor
  })
end

nk.register_rpc(rpc_get_leaderboard, "get_leaderboard")
