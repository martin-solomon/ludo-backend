local nk = require("nakama")

-- Mode → expected players (FROZEN)
local MODE_PLAYERS = {
  solo = 2,
  clash = 3,
  solo_rush = 4,
  team_up = 4,
}

local function rpc_match_entry(context, payload)
  -- 1. Session check
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

  local expected_players = MODE_PLAYERS[mode]

  -- 3. Try quick join existing match
  local matches = nk.match_list(
    10,
    true,
    "ludo_match",
    { mode = mode },
    expected_players,
    expected_players
  )

  if matches and #matches > 0 then
    return nk.json_encode({
      action = "JOIN",
      match_id = matches[1].match_id
    }), 200
  end

  -- 4. Otherwise create new match
  local match_id = nk.match_create("ludo_match", {
    mode = mode,
    expected_players = expected_players
  })

  return nk.json_encode({
    action = "CREATE",
    match_id = match_id
  }), 200
end

nk.register_rpc(rpc_match_entry, "match_entry")
