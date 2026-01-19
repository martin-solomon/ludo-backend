local nk = require("nakama")

local MODE_PLAYERS = {
  solo = 2,
  clash = 2,
  solo_rush = 4,
  team_up = 4
}

local function rpc_match_entry(context, payload)
  if not context.user_id then
    return nk.json_encode({ error = "NO_SESSION" })
  end

  local input = {}
  if payload and payload ~= "" then
    local ok, decoded = pcall(nk.json_decode, payload)
    if ok then input = decoded end
  end

  local mode = input.mode
  if not MODE_PLAYERS[mode] then
    return nk.json_encode({ error = "INVALID_MODE" })
  end

  local match_id = nk.match_create("ludo_match", {
    expected_players = MODE_PLAYERS[mode]
  })

  return nk.json_encode({
    match_id = match_id
  })
end

nk.register_rpc(rpc_match_entry, "match_entry")
