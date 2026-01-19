local nk = require("nakama")

-- Entry point for ALL online match modes
-- This does NOT use Nakama matchmaker.
-- It creates or joins authoritative matches only.

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

  -- 3. Try quick join first
  local matches = nk.match_list(
    10,                     -- limit
    true,                   -- authoritative only
    "ludo_match",           -- match handler
    { mode = mode },        -- label query
    MODE_PLAYERS[mode]      -- minimum size
  )

  if matches and #matches > 0 then
    return nk.json_encode({
      action = "join",
      match_id = matches[1].match_id
    })
  end

  -- 4. Otherwise create new match
  local match_id = nk.match_create("ludo_match", {
    mode = mode,
    expected_players = MODE_PLAYERS[mode]
  })

  return nk.json_encode({
    action = "create",
    match_id = match_id
  })
end

nk.register_rpc(rpc_match_entry, "match_entry")
