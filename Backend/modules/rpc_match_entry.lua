local nk = require("nakama")

-- Mode → expected player count (FROZEN)
local MODE_PLAYERS = {
  solo = 2,
  clash = 3,
  solo_rush = 4,
  team_up = 4,
}

local function rpc_match_entry(context, payload)
  -- 1. Session validation
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

  local expected_players = MODE_PLAYERS[mode]

  -- 3. Try to find an existing waiting match
  local matches = nk.match_list(
    10,               -- limit
    true,             -- authoritative
    "ludo",           -- label (must match match_create)
    nil,              -- min size
    expected_players  -- max size
  )

  for _, m in ipairs(matches) do
    if m.size < expected_players then
      nk.match_join(m.match_id, context.user_id)
      return nk.json_encode({
        status = "JOINED",
        match_id = m.match_id,
        mode = mode
      })
    end
  end

  -- 4. No match found → create new
  local match_id = nk.match_create("ludo_match", {
    mode = mode,
    expected_players = expected_players,
    creator = context.user_id
  })

  return nk.json_encode({
    status = "CREATED",
    match_id = match_id,
    mode = mode
  })
end

nk.register_rpc(rpc_match_entry, "match_entry")
