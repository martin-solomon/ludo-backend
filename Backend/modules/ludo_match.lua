-- ludo_match.lua
local nk = require("nakama")

local M = {}

function M.match_init(context, params)
  local state = {
    players = {},
    expected_players = params.expected_players or 2,
    started = false,
  }

  -- ✅ MUST return: state, tick_rate, label
  return state, 1, "ludo"
end

function M.match_join_attempt(context, dispatcher, tick, state, presence, metadata)
  if #state.players >= state.expected_players then
    return false, "match_full"
  end
  return true
end

function M.match_join(context, dispatcher, tick, state, presences)
  for _, p in ipairs(presences) do
    table.insert(state.players, p)
  end

  if #state.players == state.expected_players then
    state.started = true
    dispatcher.broadcast_message(1, nk.json_encode({
      type = "match_start"
    }))
  end

  return state
end

function M.match_loop(context, dispatcher, tick, state, messages)
  return state
end

function M.match_terminate(context, dispatcher, tick, state, grace)
  return state
end

return M
