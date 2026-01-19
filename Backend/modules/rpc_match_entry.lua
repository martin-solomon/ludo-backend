local nk = require("nakama")

-- Mode → required players (FROZEN CONTRACT)
local MODE_PLAYERS = {
  solo = 2,       -- 1v1
  clash = 3,      -- 1v1v1
  solo_rush = 4,  -- 1v1v1v1
  team_up = 4     -- 2v2
}

-- In-memory waiting rooms (authoritative, simple, safe)
-- waiting[mode] = { match_id = string, count = number }
local waiting = {}

local function rpc_match_entry(context, payload)
  -- 1. Session validation
  if not context or not context.user_id then
    return nk.json_encode({ error = "NO_SESSION" }), 401
  end

  -- 2. Parse payload
  local input = {}
  if payload and payload ~= "" then
    local ok, decoded = pcall(nk.json_decode, payload)
    if ok and type(decoded) == "table" then
      input = decoded
    end
  end

  local mode = input.mode
  if not mode or not MODE_PLAYERS[mode] then
    return nk.json_encode({ error = "INVALID_MODE" }), 400
  end

  local required = MODE_PLAYERS[mode]

  -- 3. Create waiting room if none
  if not waiting[mode] then
    local match_id = nk.match_create("ludo_match", {
      mode = mode,
      expected_players = required
    })

    waiting[mode] = {
      match_id = match_id,
      count = 0
    }
  end

  local room = waiting[mode]

  -- 4. Join match
  local ok, err = pcall(function()
    nk.match_join(room.match_id, { context.user_id })
  end)

  if not ok then
    return nk.json_encode({
      error = "MATCH_JOIN_FAILED",
      details = tostring(err)
    }), 500
  end

  room.count = room.count + 1

  -- 5. Room ready?
  if room.count >= required then
    waiting[mode] = nil

    return nk.json_encode({
      status = "MATCH_READY",
      match_id = room.match_id,
      players = required
    }), 200
  end

  -- 6. Still waiting
  return nk.json_encode({
    status = "WAITING",
    match_id = room.match_id,
    joined = room.count,
    required = required
  }), 200
end

nk.register_rpc(rpc_match_entry, "match_entry")
