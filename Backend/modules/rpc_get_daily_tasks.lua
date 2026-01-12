local nk = require("nakama")

local rate_limit = require("utils_rate_limit")
local DAILY_TASKS = require("daily_task_catalog")
local LOGIN_TASK = require("daily_login_task")

-- ------------------ helpers ------------------

local function shuffle(list)
  for i = #list, 2, -1 do
    local j = math.random(i)
    list[i], list[j] = list[j], list[i]
  end
end

local function pick_random_tasks(source, count)
  local copy = {}
  for i, t in ipairs(source) do
    copy[i] = t
  end

  shuffle(copy)

  local picked = {}
  for i = 1, count do
    table.insert(picked, copy[i])
  end

  return picked
end

-- ------------------ RPC ------------------

local function get_daily_tasks(context, payload)
  if not context.user_id then
    return nk.json_encode({ error = "unauthorized" })
  end

  -- rate limit: 1 request per second
  local ok, reason = rate_limit.check(context, "daily_tasks_get", 1)
  if not ok then
    return nk.json_encode({ error = reason })
  end

  local today = os.date("%Y-%m-%d")

  -- read existing daily tasks
  local objects = nk.storage_read({
    {
      collection = "daily_tasks",
      key = "today",
      user_id = context.user_id
    }
  })

  -- if today's tasks already exist, return them
  if objects and #objects > 0 then
    local stored = objects[1].value
    if stored.date == today then
      return nk.json_encode(stored)
    end
  end

  -- -------- assign new daily tasks --------

  local assigned_tasks = {}

  -- 1) fixed login task (always present)
  table.insert(assigned_tasks, {
    id = LOGIN_TASK.id,
    type = LOGIN_TASK.type,
    target = LOGIN_TASK.target,
    progress = 0,
    claimed = false,
    reward = LOGIN_TASK.reward
  })

  -- 2) pick 4 random rotating tasks
  local random_tasks = pick_random_tasks(DAILY_TASKS, 4)

  for _, task in ipairs(random_tasks) do
    table.insert(assigned_tasks, {
      id = task.id,
      type = task.type,
      target = task.target,
      progress = 0,
      claimed = false,
      reward = task.reward
    })
  end

  local daily_data = {
    date = today,
    tasks = assigned_tasks
  }

  -- save today's tasks
  nk.storage_write({
    {
      collection = "daily_tasks",
      key = "today",
      user_id = context.user_id,
      value = daily_data,
      permission_read = 2,
      permission_write = 0
    }
  })

  return nk.json_encode(daily_data)
end

nk.register_rpc(get_daily_tasks, "daily.tasks.get")
