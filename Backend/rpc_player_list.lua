-- rpc_player_list.lua
local nk = require("nakama")

local function safe_decode(payload)
  local ok, body = pcall(nk.json_decode, payload or "{}")
  return ok and body or {}
end

local function player_list(context, payload)
  local params = safe_decode(payload)
  local match_id = params.matchId or params.match_id
  if not match_id then
    return nk.json_encode({ error = "matchId required" })
  end

  local ok, match = pcall(nk.match_get, match_id)
  if not ok or not match then
    return nk.json_encode({ error = "match_not_found" })
  end

  local state = match.state
  if not state then
    return nk.json_encode({ players = {} })
  end

  -- state.player_seats may not exist in minimal handler; fallback to scanning presences
  if state.player_seats then
    local list = {}
    for seat, pd in pairs(state.player_seats) do
      table.insert(list, { userId = pd.user_id, username = pd.username, seat = seat })
    end
    return nk.json_encode({ players = list })
  end

  -- Fallback: try reading current presences from match (match.presences)
  local presences = match.presences or {}
  local players = {}
  for _, p in ipairs(presences) do
    table.insert(players, { userId = p.user_id, username = p.username, session_id = p.session_id })
  end

  return nk.json_encode({ players = players })
end

nk.register_rpc(player_list, "match.player_list")