-- rpc_quick_join.lua
local nk = require("nakama")

local function safe_decode(payload)
  local ok, body = pcall(nk.json_decode, payload or "{}")
  return ok and body or {}
end

local function gen_room_id()
  math.randomseed(os.time() + tonumber(string.sub(tostring(math.random()), 3, 6)))
  return string.format("%04d", math.random(1000,9999))
end

local function players_for_type(t)
  if t == "1v1" then return 2 end
  if t == "1v2" then return 3 end
  if t == "1v3" then return 4 end
  if t == "2v2" then return 4 end
  return 2
end

local function quick_join(context, payload)
  if not context.user_id then
    return nk.json_encode({ error = "not_authenticated" })
  end

  local params = safe_decode(payload)
  local match_type = params.matchType or params.match_type or "1v1"

  -- Try to find an open match with same type (label.match_type used)
  local ok, matches = pcall(function()
    return nk.match_list(50, true, nil, 1, 1, "+label.match_type:" .. match_type)
  end)
  if not ok then
    nk.logger_error("rpc_quick_join: match_list failed: " .. tostring(matches))
    matches = {}
  end

  if type(matches) == "table" and #matches > 0 then
    local found = matches[1]
    return nk.json_encode({ matchId = found.match_id, roomId = (found.label and found.label.room_id) })
  end

  -- Create a new match
  local room_id = gen_room_id()
  local params_table = { match_type = match_type, room_id = room_id }
  local ok2, match_id = pcall(function() return nk.match_create("ludo_match", params_table) end)
  if not ok2 then
    nk.logger_error("rpc_quick_join: match_create failed: " .. tostring(match_id))
    return nk.json_encode({ error = "internal_error" })
  end

  -- Try to fetch username from storage profile
  local username = "Player"
  local ok3, stored = pcall(nk.storage_read, { { collection = "user_profiles", key = "profile", user_id = context.user_id } })
  if ok3 and type(stored) == "table" and stored[1] and stored[1].value and stored[1].value.username then
    username = stored[1].value.username
  end

  local playerSeats = {
    { userId = context.user_id, username = username, seat = 0 }
  }

  return nk.json_encode({
    matchId = match_id,
    roomId = room_id,
    hostUserId = context.user_id,
    maxPlayers = players_for_type(match_type),
    playerSeats = playerSeats
  })
end

nk.register_rpc(quick_join, "match.quick_join")