local nk = require("nakama")
local M = {}

function M.match_init(context, params)
  return {
    players = {},
    expected_players = params.expected_players or 2,
    game_started = false,
    version = 1
  }
end

function M.match_join_attempt(context, dispatcher, tick, state, presence, metadata)
  return true, state
end

function M.match_join(context, dispatcher, tick, state, presences)
  for _, p in ipairs(presences) do
    state.players[p.user_id] = p
  end
  return state
end

function M.match_leave(context, dispatcher, tick, state, presences)
  for _, p in ipairs(presences) do
    state.players[p.user_id] = nil
  end
  return state
end

function M.match_loop(context, dispatcher, tick, state, messages)
  return state
end

function M.match_signal(context, dispatcher, tick, state, data)
  return state
end

function M.match_terminate(context, dispatcher, tick, state, grace)
  return state
end

return M
