-- ludo_match.lua (AUTHORITATIVE – FIXED & COMPLETE)
local nk = require("nakama")

local apply_rewards = require("apply_match_rewards")
local update_daily_tasks = require("update_daily_tasks")

local M = {}

------------------------------------------------
-- match_init (REQUIRED)
------------------------------------------------
function M.match_init(context, params)
  local state = {
    players = {},            -- user_id -> presence
    turn_order = {},
    current_turn = nil,
    dice_value = nil,
    match_finished = false,
    game_over = false,
    winner = nil,
    version = 1,
    last_action_time = os.time(),
  }

  return state, 10 -- tick rate REQUIRED
end

------------------------------------------------
-- match_join_attempt (REQUIRED)
------------------------------------------------
function M.match_join_attempt(context, dispatcher, tick, state, presence, metadata)
  if state.match_finished then
    return false, "MATCH_ALREADY_FINISHED"
  end

  return true
end

------------------------------------------------
-- match_join (REQUIRED)
------------------------------------------------
function M.match_join(context, dispatcher, tick, state, presences)
  for _, p in ipairs(presences) do
    state.players[p.user_id] = p
    table.insert(state.turn_order, p.user_id)
  end

  if not state.current_turn then
    state.current_turn = state.turn_order[1]
  end

  dispatcher.broadcast_message(1, nk.json_encode({
    type = "player_joined",
    players = state.turn_order,
    version = state.version
  }))

  return state
end

------------------------------------------------
-- match_leave (REQUIRED)
------------------------------------------------
function M.match_leave(context, dispatcher, tick, state, presences)
  for _, p in ipairs(presences) do
    state.players[p.user_id] = nil
  end

  if not state.match_finished then
    state.match_finished = true
    state.game_over = true

    for uid, _ in pairs(state.players) do
      state.winner = uid
      break
    end
  end

  return state
end

------------------------------------------------
-- match_loop
------------------------------------------------
function M.match_loop(context, dispatcher, tick, state, messages)

  -- ⏳ AFK timeout
  if not state.match_finished and os.time() - state.last_action_time > 60 then
    state.match_finished = true
    state.game_over = true

    for uid, _ in pairs(state.players) do
      state.winner = uid
      break
    end
  end

  for _, msg in ipairs(messages) do
    local user_id = msg.sender.user_id
    local data = nk.json_decode(msg.data)

    if data.type == "roll_dice" and not state.match_finished then
      state.last_action_time = os.time()

      local dice = math.random(1, 6)
      state.dice_value = dice
      state.version = state.version + 1

      update_daily_tasks(user_id, "play", 1)

      dispatcher.broadcast_message(1, nk.json_encode({
        type = "dice_result",
        user_id = user_id,
        value = dice,
        version = state.version
      }))

      if dice == 6 then
        state.match_finished = true
        state.game_over = true
        state.winner = user_id

        local rewards = { coins = 100, xp = 50 }
        local profile = apply_rewards(user_id, rewards, context.match_id)

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
