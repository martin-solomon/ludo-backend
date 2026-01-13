-- rpc_claim_daily_task.lua
-- Claim reward for a completed daily task (System-2)

local nk = require("nakama")

local function today()
  return os.date("!%Y-%m-%d")
end

local function rpc_claim_daily_task(context, payload)
  -- 🔐 Auth check
  if not context or not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local user_id = context.user_id

  -- 📦 Parse payload
  local data = {}
  if payload and payload ~= "" then
    local ok, decoded = pcall(nk.json_decode, payload)
    if ok and type(decoded) == "table" then
      data = decoded
    end
  end

  local task_id = data.task_id
  if not task_id or task_id == "" then
    return nk.json_encode({ error = "task_id_required" }), 400
  end

  local date = today()

  -- 📖 Read today's tasks
  local objects = nk.storage_read({
    {
      collection = "daily_tasks",
      key = date,
      user_id = user_id
    }
  })

  if not objects or #objects == 0 then
    return nk.json_encode({ error = "no_tasks_for_today" }), 404
  end

  local daily = objects[1].value
  local task = daily.tasks[task_id]

  if not task then
    return nk.json_encode({ error = "task_not_found" }), 404
  end

  -- ❌ Already claimed
  if task.claimed then
    return nk.json_encode({ error = "task_already_claimed" }), 409
  end

  -- ❌ Not completed
  if task.progress < task.goal then
    return nk.json_encode({ error = "task_not_completed" }), 409
  end

  local reward = tonumber(task.reward) or 0
  if reward <= 0 then
    return nk.json_encode({ error = "invalid_reward" }), 500
  end

  --------------------------------------------------
  -- 💰 AUTHORITATIVE WALLET UPDATE (THE FIX)
  --------------------------------------------------
  nk.wallet_update(
    user_id,
    { coins = reward },
    {
      reason = "daily_task",
      task_id = task_id,
      date = date
    },
    false -- authoritative = false (server is authority)
  )

  -- 🔒 Mark task as claimed
  task.claimed = true

  nk.storage_write({
    {
      collection = "daily_tasks",
      key = date,
      user_id = user_id,
      value = daily,
      permission_read = 1,
      permission_write = 0
    }
  })

  -- ✅ Success
  return nk.json_encode({
    success = true,
    task_id = task_id,
    reward = reward
  })
end

nk.register_rpc(rpc_claim_daily_task, "daily.tasks.claim")
