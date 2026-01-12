local nk = require("nakama")

--------------------------------------------------
-- CREATE LEADERBOARD (SAFE, IDEMPOTENT)
-- Runs on server startup
--------------------------------------------------
nk.leaderboard_create(
  "global_rank",
  false,      -- non-authoritative
  "desc",     -- higher score = higher rank
  "best",     -- best score wins
  nil,        -- no reset (lifetime)
  {},
  false
)

--------------------------------------------------
-- SUBMIT / UPDATE LEADERBOARD SCORE
-- Called AFTER ONLINE MATCH RESULT
--------------------------------------------------
local function submit_rank_update(user_id, profile)
  local level = profile.level or 1
  local wins  = profile.wins or 0

  -- Composite score: LEVEL first, WINS second
  local score = (level * 1000000) + wins

  nk.leaderboard_record_write(
    "global_rank",
    user_id,
    profile.display_name or profile.username or user_id,
    score,
    0,
    {
      level = level,
      wins = wins,
      avatar_id = profile.avatar_id or "default"
    }
  )
end

--------------------------------------------------
-- FETCH LEADERBOARD (FOR FRONTEND)
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
      player_name = profile.display_name or "Player",
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

--------------------------------------------------
-- OPTIONAL DEV / TEST RPC
-- Call this only for testing (remove later)
--------------------------------------------------
local function rpc_submit_win(context, payload)
  if not context or not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local objects = nk.storage_read({
    { collection = "profile", key = "player", user_id = context.user_id }
  })

  if not objects or #objects == 0 then
    return nk.json_encode({ error = "profile_not_found" }), 404
  end

  local profile = objects[1].value

  -- simulate win
  profile.wins = (profile.wins or 0) + 1

  nk.storage_write({
    {
      collection = "profile",
      key = "player",
      user_id = context.user_id,
      value = profile,
      permission_read = 1,
      permission_write = 0
    }
  })

  submit_rank_update(context.user_id, profile)

  return nk.json_encode({ success = true })
end

nk.register_rpc(rpc_submit_win, "submit_win")

--------------------------------------------------
-- EXPORT (FOR MATCH HANDLER USE)
--------------------------------------------------
return {
  submit_rank_update = submit_rank_update
}
