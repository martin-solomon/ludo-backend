-- daily_task_assigner.lua
-- Assigns 5 daily tasks per user (random, non-repeat, reward capped)

local nk = require("nakama")
local CATALOG = require("daily_task_catalog")

local M = {}

local MAX_DAILY_TASKS = 5
local MAX_DAILY_COINS = 150
local HISTORY_LIMIT = 30

local function today()
  return os.date("!%Y-%m-%d")
end

-- Utility: shuffle array
local function shuffle(t)
  for i = #t, 2, -1 do
    local j = math.random(i)
    t[i], t[j] = t[j], t[i]
  end
end

-- Read recent history
local function get_history(user_id)
  local r = nk.storage_read({
    { collection = "daily_task_history", key = "recent", user_id = user_id }
  })
  return (r[1] and r[1].value.recent_task_ids) or {}
end

-- Save recent history
local function save_history(user_id, history)
  nk.storage_write({
    {
      collection = "daily_task_history",
      key = "recent",
      user_id = user_id,
      value = { recent_task_ids = history },
      permission_read = 0,
      permission_write = 0
    }
  })
end

-- MAIN ASSIGN FUNCTION
function M.assign_if_needed(user_id)
  local date = today()

  -- Already assigned?
  local existing = nk.storage_read({
    { collection = "daily_tasks", key = date, user_id = user_id }
  })
  if existing and #existing > 0 then
    return existing[1].value
  end

  local history = get_history(user_id)
  local history_map = {}
  for _, id in ipairs(history) do history_map[id] = true end

  -- Filter catalog (avoid recent)
  local pool = {}
  for _, task in ipairs(CATALOG) do
    if not history_map[task.id] then
      table.insert(pool, task)
    end
  end

  shuffle(pool)

  local selected = {}
  local total_reward = 0

  for _, task in ipairs(pool) do
    if #selected >= MAX_DAILY_TASKS then break end
    if total_reward + task.reward <= MAX_DAILY_COINS then
      selected[#selected + 1] = task
      total_reward = total_reward + task.reward
    end
  end

  -- Build storage object
  local tasks = {}
  for _, t in ipairs(selected) do
    tasks[t.id] = {
      progress = 0,
      goal = t.goal,
      reward = t.reward,
      claimed = false,
      event = t.event,
      description = t.description
    }
  end

  local data = {
    date = date,
    total_reward = total_reward,
    tasks = tasks
  }

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

  -- Update history
  for _, t in ipairs(selected) do
    table.insert(history, 1, t.id)
  end
  while #history > HISTORY_LIMIT do
    table.remove(history)
  end
  save_history(user_id, history)

  return data
end

return M
