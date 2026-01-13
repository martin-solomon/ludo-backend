local nk = require("nakama")

-- 🔒 PHASE D-3: Rate limiting
local rate_limit = require("utils_rate_limit")

-- 🟦 DAILY REWARDS LOGIC (EMBEDDED, NO NEW RPC)
local daily_rewards = require("daily_rewards_logic")

local function get_daily_tasks(context, payload)
  if not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  -- 🔒 Rate limit: 1 request per second per user
  local ok, reason = rate_limit.check(context, "daily_tasks_get", 1)
  if not ok then
    return nk.json_encode({ error = reason }), 429
  end

  local today = os.date("%Y-%m-%d")

  local objects = nk.storage_read({
    {
      collection = "tasks",   -- MUST MATCH update_daily_tasks.lua
      key = "daily",
      user_id = context.user_id
    }
  })

  local tasks = {
    date = today,
    play_matches = 0,
    win_matches = 0,
    dice_rolls = 0,
    completed = {
      play = false,
      win = false,
      dice = false
    }
  }

  if objects and #objects > 0 then
    local stored = objects[1].value

    -- reset only if date changed
    if stored.date == today then
      tasks = stored
    end
  end

  --------------------------------------------------
  -- 🟦 STEP-1: FETCH DAILY REWARDS STATE
  --------------------------------------------------
  local daily_rewards_state = daily_rewards.get(nk, context.user_id)

  --------------------------------------------------
  -- RETURN COMBINED RESPONSE
  --------------------------------------------------
  return nk.json_encode({
    tasks = tasks,
    daily_rewards = daily_rewards_state
  })
end

nk.register_rpc(get_daily_tasks, "daily.tasks.get")
