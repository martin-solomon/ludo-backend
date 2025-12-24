-- update_daily_tasks.lua
local nk = require("nakama")

local M = {}

-- 🆕 PHASE C-2: Always use UTC server day
local function get_server_day()
  return os.date("!%Y-%m-%d")
end

-- 🆕 PHASE C-2: Check if a task is already locked for today
local function is_task_locked(user_id, task_key, today)
  local lock = nk.storage_read({
    {
      collection = "task_locks",
      key = task_key,
      user_id = user_id
    }
  })

  if lock and #lock > 0 and lock[1].value.day == today then
    return true
  end

  return false
end

-- 🆕 PHASE C-2: Lock a task once completed
local function lock_task(user_id, task_key, today)
  nk.storage_write({
    {
      collection = "task_locks",
      key = task_key,
      user_id = user_id,
      value = {
        day = today,
        completed = true
      },
      permission_read = 0,
      permission_write = 0
    }
  })
end

function M.update(user_id, event)
  -- 🔁 REPLACED INTERNAL DAY CALCULATION (NO LOGIC CHANGE)
  local today = get_server_day()

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

  -- 🔄 DAILY RESET (UNCHANGED)
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

  -- 🆕 PHASE C-2: Prevent duplicate task abuse
  if event == "play" and is_task_locked(user_id, "play", today) then
    nk.logger_warn("Daily PLAY task already completed | user=%s", user_id)
    return
  end

  if event == "win" and is_task_locked(user_id, "win", today) then
    nk.logger_warn("Daily WIN task already completed | user=%s", user_id)
    return
  end

  if event == "roll_dice" and is_task_locked(user_id, "dice", today) then
    nk.logger_warn("Daily DICE task already completed | user=%s", user_id)
    return
  end

  -- 📈 UPDATE PROGRESS (UNCHANGED)
  if event == "play" then
    tasks.play_matches = tasks.play_matches + 1
  elseif event == "win" then
    tasks.win_matches = tasks.win_matches + 1
  elseif event == "roll_dice" then
    tasks.dice_rolls = tasks.dice_rolls + 1
  end

  -- ✅ TASK COMPLETION LOGIC (UNCHANGED)
  if tasks.play_matches >= 5 and not tasks.completed.play then
    tasks.completed.play = true
    lock_task(user_id, "play", today)
  end

  if tasks.win_matches >= 1 and not tasks.completed.win then
    tasks.completed.win = true
    lock_task(user_id, "win", today)
  end

  if tasks.dice_rolls >= 5 and not tasks.completed.dice then
    tasks.completed.dice = true
    lock_task(user_id, "dice", today)
  end

  -- 💾 WRITE BACK (UNCHANGED)
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
