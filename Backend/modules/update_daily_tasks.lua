-- update_daily_tasks.lua
local nk = require("nakama")

local function update_daily_tasks(user_id, result)
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
      play_matches = 0,
      win_matches = 0,
      completed = false
    }
  else
    tasks = objects[1].value
  end

  tasks.play_matches = (tasks.play_matches or 0) + 1

  if result == "win" then
    tasks.win_matches = (tasks.win_matches or 0) + 1
  end

  if tasks.play_matches >= 5 and tasks.win_matches >= 1 then
    tasks.completed = true
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

return update_daily_tasks
