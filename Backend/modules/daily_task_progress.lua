-- daily_task_progress.lua
-- SERVER AUTHORITY: updates daily task progress

local nk = require("nakama")

local M = {}

local function today()
  return os.date("%Y-%m-%d")
end

function M.increment(user_id, task_type, amount)
  amount = amount or 1

  local objects = nk.storage_read({
    {
      collection = "tasks",
      key = "daily",
      user_id = user_id
    }
  })

  if not objects or #objects == 0 then
    return
  end

  local data = objects[1].value
  if data.date ~= today() then
    return
  end

  local changed = false

  for _, task in ipairs(data.tasks) do
    if task.type == task_type and not task.claimed then
      if task.progress < task.target then
        task.progress = math.min(task.progress + amount, task.target)
        changed = true
      end
    end
  end

  if changed then
    nk.storage_write({
      {
        collection = "tasks",
        key = "daily",
        user_id = user_id,
        value = data,
        permission_read = 2,
        permission_write = 0
      }
    })
  end
end

return M
