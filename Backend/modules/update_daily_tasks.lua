local nk = require("nakama")
local M = {}

local function today()
  return os.date("!%Y-%m-%d")
end

local function is_locked(user_id, key, day)
  local r = nk.storage_read({
    {
      collection = "task_locks",
      key = key,
      user_id = user_id
    }
  })
  return r and #r > 0 and r[1].value.day == day
end

local function lock_task(user_id, key, day)
  nk.storage_write({
    {
      collection = "task_locks",
      key = key,
      user_id = user_id,
      value = { day = day },
      permission_read = 0,
      permission_write = 0
    }
  })
end

function M.update(user_id, event)
  local day = today()

  local objects = nk.storage_read({
    {
      collection = "tasks",
      key = "daily",
      user_id = user_id
    }
  })

  local tasks = objects[1] and objects[1].value or {
    date = day,
    play_matches = 0,
    win_matches = 0,
    dice_rolls = 0,
    completed = { play=false, win=false, dice=false }
  }

  if tasks.date ~= day then
    tasks = {
      date = day,
      play_matches = 0,
      win_matches = 0,
      dice_rolls = 0,
      completed = { play=false, win=false, dice=false }
    }
  end

  if event == "play" and not is_locked(user_id, "play", day) then
    tasks.play_matches = tasks.play_matches + 1
  elseif event == "win" and not is_locked(user_id, "win", day) then
    tasks.win_matches = tasks.win_matches + 1
  elseif event == "roll_dice" and not is_locked(user_id, "dice", day) then
    tasks.dice_rolls = tasks.dice_rolls + 1
  end

  if tasks.play_matches >= 5 and not tasks.completed.play then
    tasks.completed.play = true
    lock_task(user_id, "play", day)
  end

  if tasks.win_matches >= 1 and not tasks.completed.win then
    tasks.completed.win = true
    lock_task(user_id, "win", day)
  end

  if tasks.dice_rolls >= 5 and not tasks.completed.dice then
    tasks.completed.dice = true
    lock_task(user_id, "dice", day)
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
