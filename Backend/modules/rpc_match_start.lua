local nk = require("nakama")

local function match_start(context, payload)
  if not context.user_id then
    return nk.json_encode({ error = "not_authenticated" })
  end

  local records = nk.storage_read({
    {
      collection = "matchmaking",
      key = "active_match",
      user_id = context.user_id
    }
  })

  if not records or #records == 0 then
    return nk.json_encode({ status = "waiting" })
  end

  local match_id = records[1].value.matchId
  if not match_id then
    return nk.json_encode({ status = "waiting" })
  end

  local ok, match = pcall(nk.match_get, match_id)
  if not ok or not match then
    return nk.json_encode({ status = "waiting" })
  end

  -- determine max players
  local max_players = 2
  local mode = match.state and match.state.mode or "solo_1v1"
  if mode == "duo_3p" then max_players = 3 end
  if mode == "solo_4p" or mode == "team_2v2" then max_players = 4 end

  -- 🔥 CLEAN UP STORAGE (IMPORTANT)
  nk.storage_delete({
    {
      collection = "matchmaking",
      key = "active_match",
      user_id = context.user_id
    }
  })

  return nk.json_encode({
    status = "ready",
    matchId = match_id,
    maxPlayers = max_players
  })
end

nk.register_rpc(match_start, "rpc_match_start")
