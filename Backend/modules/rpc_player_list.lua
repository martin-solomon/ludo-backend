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

  -- 3. Get User IDs from Presences
  -- We need to collect all User IDs to fetch their full account info
  local user_ids = {}
  local presences = match.presences or {}
  
  -- Also check internal state if available (for authoritative logic)
  if match.state and match.state.player_seats then
    for _, p in pairs(match.state.player_seats) do
      table.insert(user_ids, p.user_id)
    end
  else
    -- Fallback to standard presences
    for _, p in ipairs(presences) do
      table.insert(user_ids, p.user_id)
    end
  end

  -- If no players, return empty
  if #user_ids == 0 then
    return nk.json_encode({ players = {} })
  end

  -- 4. Fetch Full User Accounts (to get Avatar, Name, Level)
  local users = nk.users_get_id(user_ids)
  local enriched_list = {}

  for _, user in ipairs(users) do
    -- Decode the metadata (where avatar/level are usually stored)
    local metadata = {}
    if user.metadata and user.metadata ~= "" then
      local status, res = pcall(nk.json_decode, user.metadata)
      if status then metadata = res end
    end

    table.insert(enriched_list, {
      userId = user.id,
      username = user.username,
      displayName = user.display_name or user.username, -- Fallback to username
      avatarId = metadata.avatarId or "1",              -- Default to "1" if missing
      level = metadata.level or 1,                      -- Default to 1 if missing
      seat = 0 -- You can calculate seat logic here if needed
    })
  end

  return nk.json_encode({ players = enriched_list })
end

nk.register_rpc(player_list, "match.player_list")
