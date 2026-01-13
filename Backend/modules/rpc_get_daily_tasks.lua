-- rpc_get_daily_tasks.lua
-- Fetch today's assigned daily tasks (read-only)

local nk = require("nakama")

-- Rate limiting (already used in your system)
local rate_limit = require("utils_rate_limit")

-- Daily task assigner (NEW)
local task_assigner = require("daily_task_assigner")

local function rpc_get_daily_tasks(context, payload)
  -- 🔐 Auth check
  if not context or not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  -- 🔒 Rate limit: 1 request / second
  local ok, reason = rate_limit.check(context, "daily_tasks_get", 1)
  if not ok then
    return nk.json_encode({ error = reason }), 429
  end

  local user_id = context.user_id

  -- 🧠 Assign tasks if not already assigned today
  local data = task_assigner.assign_if_needed(user_id)

  -- ✅ Return UI-ready data
  return nk.json_encode({
    date = data.date,
    total_reward = data.total_reward,
    tasks = data.tasks
  })
end

nk.register_rpc(rpc_get_daily_tasks, "daily.tasks.get")
