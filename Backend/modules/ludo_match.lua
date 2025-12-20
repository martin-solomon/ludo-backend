-- ludo_match.lua
local nk = require("nakama")

local apply_rewards = require("apply_match_rewards")
local update_daily_tasks = require("update_daily_tasks")

local M = {}

------------------------------------------------
-- match_init
------------------------------------------------
function M.match_init(context, params)
  local state = {
    players = {},
    turn_order = {},
    current_turn = nil,
    dice_value = nil,

    game_started = false,
    game_over = false,

    winner = nil,
    created_at = os.time()
  }

  return state, 1, "ludo_match"
end

------------------------------------------------
-- match_join_attempt
------------------------------------------------
function M.match_join_attempt(context, dispatcher, tick, state, presence, metadata)
  return state, true
end

------------------------------------------------
-- match_join
------------------------------------------------
function M.match_join(context, dispatcher, tick, state, presences)
  for _, p in ipairs(presences) do
    state.players[p.user_id] = {
      user_id = p.user_id,
      username = p.username
    }

    local exists = false
    for _, uid in ipairs(state.turn_order) do
      if uid == p.user_id then
        exists = true
        break
      end
    end

    if not exists then
      table.insert(state.turn_order, p.user_id)
    end
  end

  if #state.turn_order >= 2 and not state.game_started then
    state.game_started = true
    state.current_turn = state.turn_order[1]

    dispatcher.broadcast_message(1, nk.json_encode({
      type = "game_started",
      first_turn = state.current_turn
    }))
  end

  return state
end

------------------------------------------------
-- match_leave (MANDATORY)
------------------------------------------------
function M.match_leave(context, dispatcher, tick, state, presences)
  for _, p in ipairs(presences) do
    state.players[p.user_id] = nil
    nk.logger_info("Player left match: " .. p.user_id)
  end
  return state
end

------------------------------------------------
-- match_loop (AUTHORITATIVE CORE)
------------------------------------------------
function M.match_loop(context, dispatcher, tick, state, messages)
  if state.game_over then
    return state
  end

  for _, message in ipairs(messages) do
    local user_id = message.sender.user_id
    local data = nk.json_decode(message.data)

    -- TURN ENFORCEMENT (ANTI-CHEAT)
    if user_id ~= state.current_turn then
      nk.logger_warn("Invalid turn attempt by " .. user_id)
      return state
    end

    if data.action == "roll_dice" then
      local dice = math.random(1, 6)
      state.dice_value = dice

      dispatcher.broadcast_message(1, nk.json_encode({
        type = "dice_result",
        user_id = user_id,
        value = dice
      }))

      -- WIN CONDITION
      if dice == 6 then
        state.game_over = true
        state.winner = user_id

        local rewards = { coins = 100, xp = 50 }
        apply_rewards(user_id, rewards)
        update_daily_tasks(user_id, "win")

        dispatcher.broadcast_message(1, nk.json_encode({
          type = "game_over",
          winner = user_id,
          rewards = rewards
        }))

        return state
      end

      -- NEXT TURN
      for i, uid in ipairs(state.turn_order) do
        if uid == user_id then
          state.current_turn = state.turn_order[(i % #state.turn_order) + 1]
          break
        end
      end

      dispatcher.broadcast_message(1, nk.json_encode({
        type = "next_turn",
        user_id = state.current_turn
      }))
    end
  end

  return state
end

------------------------------------------------
-- match_signal (REQUIRED FOR RPC)
------------------------------------------------
function M.match_signal(context, dispatcher, tick, state, data)
  local signal = nk.json_decode(data)

  table.insert(state.turn_order, state.current_turn) -- noop safety
  table.insert(state.players, state.players) -- noop safety

  table.insert(state._signals or {}, signal)
  return state
end

------------------------------------------------
-- match_terminate
------------------------------------------------
function M.match_terminate(context, dispatcher, tick, state, grace_seconds)
  return state
end

return M
