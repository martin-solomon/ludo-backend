-- update_daily_tasks.lua
local nk = require("nakama")

local M = {}

function M.update(user_id, event)
  local today = os.date("%Y-%m-%d")

  local objects = nk.storage_read({
    {
      collection = "tasks",
      key = "daily",
      user_id = user_id
    }
  })

  local tasks

  if not objects or #objects == 0 then
    tasks = {
      date = today,
      play_matches = 0,
      win_matches = 0,
      dice_rolls = 0,
      completed = {
        play = false,
        win = false,
        dice = false
      }
    }
  else
    tasks = objects[1].value
  end

  -- 🔄 DAILY RESET
  if tasks.date ~= today then
    tasks = {
      date = today,
      play_matches = 0,
      win_matches = 0,
      dice_rolls = 0,
      completed = {
        play = false,
        win = false,
        dice = false
      }
    }
  end

  -- 📈 UPDATE PROGRESS
  if event == "play" then
    tasks.play_matches = tasks.play_matches + 1
  elseif event == "win" then
    tasks.win_matches = tasks.win_matches + 1
  elseif event == "roll_dice" then
    tasks.dice_rolls = tasks.dice_rolls + 1
  end

  -- ✅ TASK COMPLETION LOGIC
  if tasks.play_matches >= 5 then
    tasks.completed.play = true
  end

  if tasks.win_matches >= 1 then
    tasks.completed.win = true
  end

  if tasks.dice_rolls >= 5 then
    tasks.completed.dice = true
  end

  nk.storage_write({
    {
      collection = "tasks",
      key = "daily",
      user_id = user_id,
      value = tasks,
      permission_read = 1,
      permission_write = 0
    }
  })
end

return M
