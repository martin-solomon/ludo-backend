-- ludo_match.lua
local nk = require("nakama")

local M = {}

------------------------------------------------
-- match_init (MUST return: state, tick_rate, label)
------------------------------------------------
function M.match_init(context, params)
  local state = {
    players = {},
    expected_players = params.expected_players or 2,
    mode = params.mode,
    started = false,
  }

  local tick_rate = 1
  local label = "ludo_" .. (params.mode or "unknown")

  return state, tick_rate, label
end

------------------------------------------------
-- match_join_attempt (REQUIRED)
------------------------------------------------
function M.match_join_attempt(context, dispatcher, tick, state, presence, metadata)
  if #state.players >= state.expected_players then
    return false, "match_full"
  end
  return true
end

------------------------------------------------
-- match_join (REQUIRED)
------------------------------------------------
function M.match_join(context, dispatcher, tick, state, presences)
  for _, p in ipairs(presences) do
    state.players[p.user_id] = p
  end

  if not state.started and table.count(state.players) >= state.expected_players then
    state.started = true
    dispatcher.broadcast_message(1, nk.json_encode({
      type = "match_started",
      mode = state.mode,
    }))
  end

  return state
end

------------------------------------------------
-- match_leave (REQUIRED)
------------------------------------------------
function M.match_leave(context, dispatcher, tick, state, presences)
  for _, p in ipairs(presences) do
    state.players[p.user_id] = nil
  end
  return state
end

------------------------------------------------
-- match_loop (REQUIRED)
------------------------------------------------
function M.match_loop(context, dispatcher, tick, state, messages)
  for _, msg in ipairs(messages) do
    dispatcher.broadcast_message(1, msg.data)
  end
  return state
end

------------------------------------------------
-- match_signal (OPTIONAL BUT SAFE)
------------------------------------------------
function M.match_signal(context, dispatcher, tick, state, data)
  return state, "ok"
end

------------------------------------------------
-- match_terminate (REQUIRED)
------------------------------------------------
function M.match_terminate(context, dispatcher, tick, state, grace_seconds)
  return state
end

return M
