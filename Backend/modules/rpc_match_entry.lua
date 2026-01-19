-- rpc_match_entry.lua
local nk = require("nakama")

local MODE_PLAYERS = {
  solo = 2,
  clash = 2,
  solo_rush = 4,
  team_up = 4,
}

local function rpc_match_entry(context, payload)
  if not context.user_id then
    return nk.json_encode({ error = "NO_SESSION" }), 401
  end

  local input = {}
  if payload and payload ~= "" then
    input = nk.json_decode(payload)
  end

  local mode = input.mode
  if not MODE_PLAYERS[mode] then
    return nk.json_encode({ error = "INVALID_MODE" }), 400
  end

  local match_id = nk.match_create("ludo_match", {
    mode = mode,
    expected_players = MODE_PLAYERS[mode],
  })

  return nk.json_encode({
    match_id = match_id
  }), 200
end

nk.register_rpc(rpc_match_entry, "match_entry")
