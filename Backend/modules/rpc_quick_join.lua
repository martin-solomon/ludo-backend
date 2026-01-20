local nk = require("nakama")

local function get_expected_players(mode)
  if mode == "solo_1v1" then return 2 end
  if mode == "duo_3p" then return 3 end
  if mode == "solo_4p" then return 4 end
  if mode == "team_2v2" then return 4 end
  return 2
end

local function rpc_quick_join(context, payload)
  if not context.user_id then
    return nk.json_encode({ error = "NO_SESSION" }), 401
  end

  local data = nk.json_decode(payload or "{}")
  local mode = data.mode or "solo_1v1"

  local expected = get_expected_players(mode)

  -- Matchmaker query (CRITICAL)
  local query = "+properties.mode:" .. mode

  nk.matchmaker_add(
    context.user_id,
    context.session_id,
    query,
    { mode = mode },      -- properties
    expected,             -- min players
    expected              -- max players
  )

  return nk.json_encode({
    status = "SEARCHING",
    mode = mode,
    players_required = expected
  })
end

nk.register_rpc(rpc_quick_join, "quick_join")
