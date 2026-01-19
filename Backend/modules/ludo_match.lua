local nk = require("nakama")

local M = {}

-- REQUIRED
function M.match_init(context, params)
  local state = {
    players = {},
    expected_players = params.expected_players or 2,
    started = false,
    version = 1
  }

  -- IMPORTANT: must return exactly 3 values
  return state, 1, "ludo_match"
end

-- REQUIRED
function M.match_join_attempt(context, dispatcher, tick, state, presence, metadata)
  return true
end

-- REQUIRED
function M.match_join(context, dispatcher, tick, state, presences)
  for _, p in ipairs(presences) do
    state.players[p.user_id] = p
  end

  if not state.started and nk.table_size(state.players) >= state.expected_players then
    state.started = true
    dispatcher.broadcast_message(1, nk.json_encode({
      type = "match_started",
      version = state.version
    }))
  end

  return state
end

-- REQUIRED
function M.match_leave(context, dispatcher, tick, state, presences)
  for _, p in ipairs(presences) do
    state.players[p.user_id] = nil
  end
  return state
end

-- REQUIRED
function M.match_loop(context, dispatcher, tick, state, messages)
  return state
end

-- REQUIRED
function M.match_terminate(context, dispatcher, tick, state, grace_seconds)
  return state
end

return M
