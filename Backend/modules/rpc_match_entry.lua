-- rpc_match_entry.lua
local nk = require("nakama")

local MODE_PLAYERS = {
  solo = 2,
  clash = 2,
  solo_rush = 4,
  team_up = 4,
}

local function rpc_match_entry(context, payload)
  -- 1. Auth check
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

  -- 3. Create match (MANUAL – always safe)
  local match_id = nk.match_create("ludo_match", {
    mode = mode,
    expected_players = MODE_PLAYERS[mode],
    owner = context.user_id
  })

  -- 4. Return match id ONLY
  return nk.json_encode({
    action = "created",
    match_id = match_id
  }), 200
end

nk.register_rpc(rpc_match_entry, "match_entry")
