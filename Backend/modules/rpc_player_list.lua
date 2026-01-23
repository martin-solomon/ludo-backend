local nk = require("nakama")
local avatar_catalog = require("avatar_catalog")

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
  local user_seat_map = {}
  if match.state and match.state.seat_owners then
    for seat, uid in pairs(match.state.seat_owners) do
      user_seat_map[uid] = seat
    end
  end

  -- 4. Collect User IDs
  local user_ids = {}
  local presences = match.presences or {}
  
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

    ----------------------------------------------------------
    -- ✅ AVATAR LOGIC (REPLACED ONLY THIS PART)
    ----------------------------------------------------------
    local objects = nk.storage_read({
      { collection = "user_profiles", key = user.id, user_id = user.id }
    })

    local profile = objects and objects[1] and objects[1].value or {}

    local avatar = profile.active_avatar
    if not avatar or not avatar_catalog.is_valid(avatar.id) then
      avatar = avatar_catalog.DEFAULT
    end
    ----------------------------------------------------------

    table.insert(enriched_list, {
      userId = user.id,
      username = user.username,
      displayName = user.display_name or user.username,

      -- NEW AVATAR FIELD
      avatar = avatar,

      level = profile.level or 1,

      -- Seat logic untouched
      seat = user_seat_map[user.id] or 0 
    })
  end

  return nk.json_encode({ players = enriched_list })
end

nk.register_rpc(player_list, "match.player_list")
