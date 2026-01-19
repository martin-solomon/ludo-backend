local nk = require("nakama")

-- Mode → required players
local MODE_PLAYERS = {
  solo = 2,
  clash = 3,
  solo_rush = 4,
  team_up = 4,
}

local function rpc_match_entry(context, payload)
  -- 1. Validate session
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

  local required_players = MODE_PLAYERS[mode]

  -- 3. Try to find existing open match
  local matches = nk.match_list(
    10,                 -- limit
    false,              -- authoritative
    nil,                -- label
    nil,                -- min_size
    required_players    -- max_size
  )

  for _, match in ipairs(matches) do
    if match.size < required_players then
      -- Join existing match
      nk.match_join(match.match_id, context.user_id, context.username)
      return nk.json_encode({
        action = "joined",
        match_id = match.match_id
      }), 200
    end
  end

  -- 4. No match found → create new one
  local match_id = nk.match_create("ludo_match", {
    mode = mode,
    expected_players = required_players
  })

  return nk.json_encode({
    action = "created",
    match_id = match_id
  }), 200
end

nk.register_rpc(rpc_match_entry, "match_entry")
