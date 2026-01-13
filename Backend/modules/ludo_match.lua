-- ludo_match.lua (PRODUCTION – PHASE A + B + STEP-8)
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
    match_finished = false,
    game_over = false,
    winner = nil,
    version = 1,

    -- ⏳ Track last player action
    last_action_time = os.time()
  }

  return state
end

------------------------------------------------
-- match_loop
------------------------------------------------
function M.match_loop(context, dispatcher, tick, state, messages)

  -- ⏳ ABANDON / FORFEIT CHECK
  if not state.match_finished then
    if os.time() - state.last_action_time > 60 then
      state.match_finished = true
      state.game_over = true

      local winner_id = nil
      for _, presence in pairs(state.players) do
        winner_id = presence.user_id
        break
      end

      if winner_id then
        state.winner = winner_id
        local rewards = { coins = 100, xp = 50 }

        local profile = apply_rewards(winner_id, rewards, context.match_id)

        if profile then
          nk.leaderboard_record_write(
            "global_level",
            winner_id,
            profile.level,
            { coins = profile.coins }
          )
        end

        dispatcher.broadcast_message(1, nk.json_encode({
          type = "game_over",
          winner = winner_id,
          reason = "opponent_timeout",
          rewards = rewards,
          version = state.version
        }))
      end

      return state
    end
  end

  for _, msg in ipairs(messages) do
    local user_id = msg.sender.user_id
    local data = nk.json_decode(msg.data)

    if data.type == "roll_dice" then
      if state.match_finished then
        return state
      end

      state.last_action_time = os.time()

      local dice = math.random(1, 6)
      state.dice_value = dice

      -- 📅 DAILY TASK: PLAY MATCH
      update_daily_tasks(user_id, "play", 1)

      dispatcher.broadcast_message(1, nk.json_encode({
        type = "dice_result",
        user_id = user_id,
        value = dice,
        version = state.version
      }))

      ------------------------------------------------
      -- 🟦 PAWN MOVEMENT HOOK (NEW)
      -- Purpose: Connect pawn gameplay → daily tasks
      ------------------------------------------------

      -- Example pawn movement logic (placeholder)
      local steps_moved = dice
      local from_base = (dice == 6)       -- example condition
      local reached_home = false          -- real logic comes later

      -- 📅 DAILY TASK: PAWN MOVED
      update_daily_tasks(user_id, "pawn_move", steps_moved)

      if from_base then
        update_daily_tasks(user_id, "pawn_base", 1)
      end

      if reached_home then
        update_daily_tasks(user_id, "pawn_home", 1)
      end

      ------------------------------------------------
      -- 🏆 WIN CONDITION
      ------------------------------------------------
      if dice == 6 then
        if state.match_finished then
          return state
        end

        state.match_finished = true
        state.game_over = true
        state.winner = user_id

        local rewards = { coins = 100, xp = 50 }

        local profile = apply_rewards(user_id, rewards, context.match_id)

        -- 📅 DAILY TASK: WIN MATCH
        update_daily_tasks(user_id, "win", 1)

        if profile then
          nk.leaderboard_record_write(
            "global_level",
            user_id,
            profile.level,
            { coins = profile.coins }
          )
        end

        dispatcher.broadcast_message(1, nk.json_encode({
          type = "game_over",
          winner = user_id,
          rewards = rewards,
          version = state.version
        }))
      end
    end
  end

  return state
end

------------------------------------------------
-- match_terminate
------------------------------------------------
function M.match_terminate(context, dispatcher, tick, state, grace_seconds)
  return state
end

return M
