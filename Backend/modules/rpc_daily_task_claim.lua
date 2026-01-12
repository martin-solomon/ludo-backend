local nk = require("nakama")

local function today()
  return os.date("%Y-%m-%d")
end

local function rpc_daily_task_claim(context, payload)
  if not context or not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local input = nk.json_decode(payload or "{}")
  local task_id = input.task_id

  if not task_id then
    return nk.json_encode({ error = "task_id_required" }), 400
  end

  -- Read today's tasks
  local objects = nk.storage_read({
    {
      collection = "daily_tasks",
      key = "today",
      user_id = context.user_id
    }
  })

  if not objects or #objects == 0 then
    return nk.json_encode({ error = "no_tasks_for_today" }), 404
  end

  local data = objects[1].value

  if data.date ~= today() then
    return nk.json_encode({ error = "tasks_expired" }), 409
  end

  local task = nil
  for _, t in ipairs(data.tasks) do
    if t.id == task_id then
      task = t
      break
    end
  end

  if not task then
    return nk.json_encode({ error = "task_not_found" }), 404
  end

  if task.claimed then
    return nk.json_encode({ error = "already_claimed" }), 409
  end

  if (task.progress or 0) < (task.target or 0) then
    return nk.json_encode({ error = "task_not_completed" }), 409
  end

  -- Apply reward to wallet
  if task.reward and task.reward.coins then
    nk.wallet_update(
      context.user_id,
      { coins = task.reward.coins },
      { source = "daily_task", task_id = task.id },
      false
    )
  end

  -- Mark task claimed
  task.claimed = true
  task.claimed_at = nk.time()

  -- Save back
  nk.storage_write({
    {
      collection = "daily_tasks",
      key = "today",
      user_id = context.user_id,
      value = data,
      permission_read = 2,
      permission_write = 0
    }
  })

  return nk.json_encode({
    success = true,
    task_id = task.id,
    reward = task.reward
  })
end

nk.register_rpc(rpc_daily_task_claim, "daily.tasks.claim")
