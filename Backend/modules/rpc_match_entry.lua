local nk = require("nakama")

-- In-memory waiting matches
-- waiting[mode] = { match_id = "...", joined = number, expected = number }
local waiting = {}

local MODE_PLAYERS = {
  solo = 2,
  clash = 3,
  solo_rush = 4,
  team_up = 4,
}

local function rpc_match_entry(context, payload)
  -- 1. Validate session
  if not context or not context.user_id then
    return nk.json_encode({ error = "NO_SESSION" })
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
    return nk.json_encode({ error = "INVALID_MODE" })
  end

  local expected = MODE_PLAYERS[mode]

  -- 3. Find or create match
  local entry = waiting[mode]

  if not entry or entry.joined >= expected then
    local match_id = nk.match_create("ludo_match", {
      mode = mode,
      expected_players = expected
    })

    entry = {
      match_id = match_id,
      joined = 0,
      expected = expected
    }

    waiting[mode] = entry
  end

  -- 4. Join match
  nk.match_join(entry.match_id, context.user_id)

  entry.joined = entry.joined + 1

  -- 5. Cleanup when full
  if entry.joined >= entry.expected then
    waiting[mode] = nil
  end

  -- 6. Return match_id
  return nk.json_encode({
    match_id = entry.match_id,
    mode = mode
  })
end

nk.register_rpc(rpc_match_entry, "match_entry")
