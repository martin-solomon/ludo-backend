-- rpc_claim_daily_task.lua
-- Claim reward for a completed daily task (System-2)
-- HARDENED & PRODUCTION SAFE

local nk = require("nakama")
local rate_limit = require("utils_rate_limit")

local function today()
  return os.date("!%Y-%m-%d")
end

local function rpc_claim_daily_task(context, payload)
  --------------------------------------------------
  -- 🔐 AUTH CHECK
  --------------------------------------------------
  if not context or not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local user_id = context.user_id
  local date = today()

  --------------------------------------------------
  -- 🔐 HARDENING #1 — RATE LIMIT (ANTI-SPAM)
  --------------------------------------------------
  local ok, reason = rate_limit.check(context, "daily_task_claim", 1)
  if not ok then
    return nk.json_encode({ error = "too_many_requests" }), 429
  end

  --------------------------------------------------
  -- 📦 PARSE PAYLOAD
  --------------------------------------------------
  local data = {}
  if payload and payload ~= "" then
    local success, decoded = pcall(nk.json_decode, payload)
    if success and type(decoded) == "table" then
      data = decoded
    end
  end

  --------------------------------------------------
  -- 🔐 HARDENING #2 — EXPLICIT USER INTENT REQUIRED
  --------------------------------------------------
  if data.confirm ~= true then
    return nk.json_encode({ error = "explicit_claim_required" }), 400
  end

  local task_id = data.task_id
  if not task_id or task_id == "" then
    return nk.json_encode({ error = "task_id_required" }), 400
  end

  --------------------------------------------------
  -- 📖 READ TODAY'S DAILY TASKS
  --------------------------------------------------
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
  local task = daily.tasks and daily.tasks[task_id]

  if not task then
    return nk.json_encode({ error = "task_not_found" }), 404
  end

  --------------------------------------------------
  -- 🔒 BLOCK DOUBLE CLAIM
  --------------------------------------------------
  if task.claimed == true then
    return nk.json_encode({ error = "task_already_claimed" }), 409
  end

  --------------------------------------------------
  -- 🔒 BLOCK INCOMPLETE TASK
  --------------------------------------------------
  if (task.progress or 0) < (task.goal or 0) then
    return nk.json_encode({ error = "task_not_completed" }), 409
  end

  --------------------------------------------------
  -- 🔐 HARDENING #3 — WALLET MUST EXIST
  --------------------------------------------------
  local wallet = nk.wallet_get(user_id)
  if not wallet or wallet.coins == nil then
    return nk.json_encode({ error = "wallet_not_initialized" }), 500
  end

  --------------------------------------------------
  -- 🎁 GRANT COINS (AUTHORITATIVE)
  --------------------------------------------------
  local reward = tonumber(task.reward) or 0
  if reward <= 0 then
    return nk.json_encode({ error = "invalid_reward" }), 500
  end

  nk.wallet_update(
    user_id,
    { coins = reward },
    { reason = "daily_task", task_id = task_id },
    true
  )

  --------------------------------------------------
  -- 🔒 MARK TASK AS CLAIMED
  --------------------------------------------------
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

  --------------------------------------------------
  -- ✅ SUCCESS
  --------------------------------------------------
  return nk.json_encode({
    success = true,
    task_id = task_id,
    reward = reward
  })
end

nk.register_rpc(rpc_claim_daily_task, "daily.tasks.claim")
