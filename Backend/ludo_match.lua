-- ludo_match.lua (PRODUCTION – PHASE A + B + STEP-5)
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

    -- ⏳ STEP-5: Track last player action
    last_action_time = os.time()
  }

  return state
end

------------------------------------------------
-- match_loop
------------------------------------------------
function M.match_loop(context, dispatcher, tick, state, messages)

  -- ⏳ STEP-5: ABANDON / FORFEIT CHECK
  if not state.match_finished then
    if os.time() - state.last_action_time > 60 then
      state.match_finished = true
      state.game_over = true

      -- determine remaining player as winner
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

      -- ⏱ Update last action time (STEP-5)
      state.last_action_time = os.time()

      local dice = math.random(1, 6)
      state.dice_value = dice

      -- 📅 DAILY PLAY TASK
      update_daily_tasks(user_id, "play")

      dispatcher.broadcast_message(1, nk.json_encode({
        type = "dice_result",
        user_id = user_id,
        value = dice,
        version = state.version
      }))

      -- 🏆 WIN CONDITION (SINGLE SOURCE OF TRUTH)
      if dice == 6 then
        if state.match_finished then
          return state
        end

        state.match_finished = true
        state.game_over = true
        state.winner = user_id

        local rewards = { coins = 100, xp = 50 }

        -- 🎁 APPLY REWARDS (SAFE)
        local profile = apply_rewards(user_id, rewards, context.match_id)

        -- 📅 DAILY WIN TASK
        update_daily_tasks(user_id, "win")

        -- 🏆 LEADERBOARD UPDATE (LOCKED)
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
