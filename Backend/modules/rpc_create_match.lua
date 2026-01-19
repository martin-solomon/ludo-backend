local nk = require("nakama")

local MODE_PLAYERS = {
  solo = 2,
  clash = 2,
  solo_rush = 4,
  team_up = 4
}

local function rpc_create_match(context, payload)
  if not context.user_id then
    return nk.json_encode({ error = "NO_SESSION" }), 401
  end

  local data = nk.json_decode(payload or "{}")
  local mode = data.mode

  if not MODE_PLAYERS[mode] then
    return nk.json_encode({ error = "INVALID_MODE" }), 400
  end

  local match_id = nk.match_create("ludo_match", {
    expected_players = MODE_PLAYERS[mode],
    mode = mode
  })

  return nk.json_encode({
    match_id = match_id
  }), 200
end

nk.register_rpc(rpc_create_match, "create_match")
