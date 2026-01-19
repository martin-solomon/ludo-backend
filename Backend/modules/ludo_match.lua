local nk = require("nakama")

local M = {}

------------------------------------------------
-- REQUIRED: match_init MUST return (state, tick_rate)
------------------------------------------------
function M.match_init(context, params)
  local state = {
    players = {},
    mode = params.mode,
    expected_players = params.expected_players,
    owner = params.owner,
    started = false,
    version = 1
  }

  local tick_rate = 1 -- REQUIRED
  return state, tick_rate
end

------------------------------------------------
-- REQUIRED: match_join_attempt
------------------------------------------------
function M.match_join_attempt(context, dispatcher, tick, state, presence, metadata)
  if state.started then
    return false, "MATCH_ALREADY_STARTED"
  end

  return true
end

------------------------------------------------
-- REQUIRED: match_join
------------------------------------------------
function M.match_join(context, dispatcher, tick, state, presences)
  for _, p in ipairs(presences) do
    state.players[p.user_id] = p
  end

  if not state.started and
     nk.table_size(state.players) >= state.expected_players then
    state.started = true

    dispatcher.broadcast_message(1, nk.json_encode({
      type = "match_start",
      players = nk.table_size(state.players),
      version = state.version
    }))
  end

  return state
end

------------------------------------------------
-- REQUIRED: match_loop
------------------------------------------------
function M.match_loop(context, dispatcher, tick, state, messages)
  -- Gameplay will be implemented in Phase-3
  return state
end

------------------------------------------------
-- REQUIRED: match_leave
------------------------------------------------
function M.match_leave(context, dispatcher, tick, state, presences)
  for _, p in ipairs(presences) do
    state.players[p.user_id] = nil
  end
  return state
end

------------------------------------------------
-- REQUIRED: match_terminate
------------------------------------------------
function M.match_terminate(context, dispatcher, tick, state, grace_seconds)
  return state
end

return M
