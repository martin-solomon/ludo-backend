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

  -- Helper: get display name from profile
  local function get_display_name(user_id)
    local okp, prof = pcall(nk.storage_read, {
      {
        collection = "profile",
        key = "data",
        user_id = user_id
      }
    })

    if okp and prof and prof[1] and prof[1].value and prof[1].value.display_name then
      return prof[1].value.display_name
    end

    return "Player"
  end

  -- state.player_seats path
  if state.player_seats then
    local list = {}
    for seat, pd in pairs(state.player_seats) do
      local username = get_display_name(pd.user_id)
      table.insert(list, {
        userId = pd.user_id,
        username = username,
        seat = seat
      })
    end
    return nk.json_encode({ players = list })
  end

  -- Fallback: match presences
  local presences = match.presences or {}
  local players = {}
  for _, p in ipairs(presences) do
    local username = get_display_name(p.user_id)
    table.insert(players, {
      userId = p.user_id,
      username = username,
      session_id = p.session_id
    })
  end

  return nk.json_encode({ players = players })
end

nk.register_rpc(player_list, "match.player_list")
