-- ludo_match.lua
local nk = require("nakama")
local M = {}

function M.match_init(context, params)
  local state = {
    players = {},
    turn_order = {},
    current_turn = nil,
    dice_value = nil,

    game_started = false,
    game_over = false,

    winner = nil,
    rewards = nil,

    created_at = os.time()
  }

  local tick_rate = 1
  return state, tick_rate
end

function M.match_join(context, dispatcher, tick, state, presences)
  for _, p in ipairs(presences) do
    state.players[p.user_id] = p
    table.insert(state.turn_order, p.user_id)
    nk.logger_info("Player joined: " .. p.user_id)
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

function M.match_leave(context, dispatcher, tick, state, presences)
  for _, p in ipairs(presences) do
    state.players[p.user_id] = nil
    nk.logger_info("Player left: " .. p.user_id)
  end
  return state
end

function M.match_loop(context, dispatcher, tick, state, messages)
  if state.game_over then
    return state
  end

  for _, message in ipairs(messages) do
    local user_id = message.sender.user_id
    local data = nk.json_decode(message.data)

    -- Enforce turn order
    if user_id ~= state.current_turn then
      nk.logger_warn("Invalid turn attempt by " .. user_id)
      return state
    end

    -- Dice roll request
    if data.action == "roll_dice" then
      local dice = math.random(1, 6)
      state.dice_value = dice

      dispatcher.broadcast_message(1, nk.json_encode({
        type = "dice_result",
        user_id = user_id,
        value = dice
      }))

      -- TEMP WIN CONDITION (for testing)
      if dice == 6 then
        state.game_over = true
        state.winner = user_id
        state.rewards = {
          coins = 100,
          xp = 50
        }

        dispatcher.broadcast_message(1, nk.json_encode({
          type = "game_over",
          winner = user_id,
          rewards = state.rewards
        }))

        nk.logger_info("Match ended. Winner: " .. user_id)
        return state
      end

      -- Move to next turn
      local idx = 1
      for i, uid in ipairs(state.turn_order) do
        if uid == user_id then
          idx = i
          break
        end
      end

      state.current_turn = state.turn_order[(idx % #state.turn_order) + 1]

      dispatcher.broadcast_message(1, nk.json_encode({
        type = "next_turn",
        user_id = state.current_turn
      }))
    end
  end

  return state
end

function M.match_terminate(context, dispatcher, tick, state, grace_seconds)
  return state
end

return M
