local nk = require("nakama")

local function player_list(context, payload)
  -- 1. Parse Payload
  local params = {}
  if payload and payload ~= "" then
    params = nk.json_decode(payload)
  end
  
  local match_id = params.matchId or params.match_id
  if not match_id then
    return nk.json_encode({ error = "matchId required" })
  end

  -- 2. Get Match State
  local ok, match = pcall(nk.match_get, match_id)
  if not ok or not match then
    return nk.json_encode({ error = "match_not_found" })
  end

  -- 3. Identify Who is Sitting Where
  -- We read the 'seat_owners' table we just added to ludo_match.lua
  local user_seat_map = {}
  if match.state and match.state.seat_owners then
    -- Reverse the map: Seat->User becomes User->Seat
    for seat, uid in pairs(match.state.seat_owners) do
      user_seat_map[uid] = seat
    end
  end

  -- 4. Collect User IDs
  local user_ids = {}
  local presences = match.presences or {}
  
  -- Use seat owners if available (most reliable), otherwise presences
  if match.state and match.state.seat_owners then
    for _, uid in pairs(match.state.seat_owners) do
      table.insert(user_ids, uid)
    end
  else
    for _, p in ipairs(presences) do
      table.insert(user_ids, p.user_id)
    end
  end

  if #user_ids == 0 then
    return nk.json_encode({ players = {} })
  end

  -- 5. Fetch Full User Accounts
  local users = nk.users_get_id(user_ids)
  local enriched_list = {}

  for _, user in ipairs(users) do
    local metadata = {}
    if user.metadata and user.metadata ~= "" then
      local status, res = pcall(nk.json_decode, user.metadata)
      if status then metadata = res end
    end

    table.insert(enriched_list, {
      userId = user.id,
      username = user.username,
      displayName = user.display_name or user.username,
      avatarId = metadata.avatarId or "1",
      level = metadata.level or 1,
      
      -- ✅ NEW: Send the correct seat number!
      -- Frontend uses this to rotate the board (If I am 3, rotate board so 3 is bottom)
      seat = user_seat_map[user.id] or 0 
    })
  end

  return nk.json_encode({ players = enriched_list })
end

nk.register_rpc(player_list, "match.player_list")
