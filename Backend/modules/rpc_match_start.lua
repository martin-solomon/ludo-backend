-- rpc_match_start.lua
local nk = require("nakama")

local function safe_decode(payload)
  local ok, body = pcall(nk.json_decode, payload or "{}")
  return ok and body or {}
end

local function match_start(context, payload)
  if not context.user_id then
    return nk.json_encode({ error = "not_authenticated" })
  end

  local params = safe_decode(payload)
  local match_id = params.matchId or params.match_id
  if not match_id then
    return nk.json_encode({ error = "matchId required" })
  end

  local ok, mdata = pcall(nk.match_get, match_id)
  if not ok or not mdata then
    return nk.json_encode({ error = "match_not_found" })
  end

  -- ensure requester is present in the match presences
  local requester = context.user_id
  local present = false
  local presences = mdata.presences or {}
  for _, p in ipairs(presences) do
    if p.user_id == requester then
      present = true
      break
    end
  end
  if not present then
    return nk.json_encode({ error = "not_in_match" })
  end

  -- Check player count
  local player_count = #presences
  if player_count < 2 then
    return nk.json_encode({ error = "not_enough_players" })
  end

  -- Minimal implementation: return ok. Frontend should only present start option to host.
  return nk.json_encode({ status = "ok", players = player_count })
end

nk.register_rpc(match_start, "match.start")