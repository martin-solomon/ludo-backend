-- update_daily_tasks.lua
-- Dynamic progress updater for Daily Tasks (System-2)

local nk = require("nakama")
local M = {}

local function today()
  return os.date("!%Y-%m-%d")
end

-- =====================================================
-- Update daily task progress by event
-- =====================================================
function M.update(user_id, event, amount)
  amount = amount or 1
  local date = today()

  -- Read today's tasks
  local objects = nk.storage_read({
    {
      collection = "daily_tasks",
      key = date,
      user_id = user_id
    }
  })

  if not objects or #objects == 0 then
    -- Tasks not assigned yet (safe exit)
    return
  end

  local data = objects[1].value
  local tasks = data.tasks
  local updated = false

  for _, task in pairs(tasks) do
    -- Skip claimed or completed tasks
    if not task.claimed and task.progress < task.goal then
      if task.event == event then
        task.progress = math.min(task.progress + amount, task.goal)
        updated = true
      end
    end
  end

  if not updated then
    return
  end

  -- Write back updated progress
  nk.storage_write({
    {
      collection = "daily_tasks",
      key = date,
      user_id = user_id,
      value = data,
      permission_read = 1,
      permission_write = 0
    }
  })
end

return M
