local nk = require("nakama")

local function rpc_quick_join(context, payload)
  if not context.user_id then
    return nk.json_encode({ error = "NO_SESSION" }), 401
  end

  local params = nk.json_decode(payload or "{}")
  local mode = params.mode or "solo_1v1"

  -- Matchmaker properties
  local properties = {
    mode = mode
  }

  local query = "+properties.mode:" .. mode

  -- Add player to matchmaker
  nk.matchmaker_add(
    context.user_id,
    context.session_id,
    query,
    properties,
    get_expected_players(mode), -- min
    get_expected_players(mode)  -- max
  )

  return nk.json_encode({
    status = "SEARCHING",
    mode = mode
  })
end

nk.register_rpc(rpc_quick_join, "quick_join")
