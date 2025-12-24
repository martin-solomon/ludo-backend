local nk = require("nakama")

local function get_daily_tasks(context, payload)
  if not context.user_id then
    return nk.json_encode({ error = "unauthorized" })
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

    -- reset if date changed
    if stored.date == today then
      tasks = stored
    end
  end

  -- ⚠️ IMPORTANT: RETURN ONLY ONE VALUE
  return nk.json_encode(tasks)
end

nk.register_rpc(get_daily_tasks, "daily.tasks.get")
