local nk = require("nakama")

local M = {}

------------------------------------------------
-- match_init (MUST return 3 values)
------------------------------------------------
function M.match_init(context, params)
  local state = {
    players = {},
    expected_players = params.expected_players or 2,
    started = false,
    version = 1
  }

  -- return: state, tick_rate, label
  return state, 1, "ludo"
end

------------------------------------------------
-- match_join_attempt (MUST exist)
------------------------------------------------
function M.match_join_attempt(context, dispatcher, tick, state, presence, metadata)
  if state.started then
    return false, "MATCH_ALREADY_STARTED"
  end

  return true
end

------------------------------------------------
-- match_join (MUST exist)
------------------------------------------------
function M.match_join(context, dispatcher, tick, state, presences)
  for _, p in ipairs(presences) do
    state.players[p.user_id] = p
  end

  -- Start game when enough players joined
  local count = 0
  for _ in pairs(state.players) do count = count + 1 end

  if count >= state.expected_players then
    state.started = true
    dispatcher.broadcast_message(1, nk.json_encode({
      type = "match_start",
      players = state.players,
      version = state.version
    }))
  end

  return state
end

------------------------------------------------
-- match_leave (MUST exist)
------------------------------------------------
function M.match_leave(context, dispatcher, tick, state, presences)
  for _, p in ipairs(presences) do
    state.players[p.user_id] = nil
  end

  return state
end

------------------------------------------------
-- match_loop
------------------------------------------------
function M.match_loop(context, dispatcher, tick, state, messages)
  for _, msg in ipairs(messages) do
    dispatcher.broadcast_message(1, msg.data)
  end
  return state
end

------------------------------------------------
-- match_signal (MUST exist)
------------------------------------------------
function M.match_signal(context, dispatcher, tick, state, data)
  return state, data
end

------------------------------------------------
-- match_terminate
------------------------------------------------
function M.match_terminate(context, dispatcher, tick, state, grace_seconds)
  return state
end

return M
