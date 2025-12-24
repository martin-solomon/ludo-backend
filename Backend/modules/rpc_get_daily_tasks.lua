local nk = require("nakama")

local function get_daily_tasks(context, payload)
  if not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local today = os.date("%Y-%m-%d")

  local objects = nk.storage_read({
    {
      collection = "daily_tasks",
      key = "today",
      user_id = context.user_id
    }
  })

  -- 🟢 DEFAULT DAILY STRUCTURE (SAFE FALLBACK)
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

  -- 📦 EXISTING DATA
  if objects and #objects > 0 then
    local stored = objects[1].value

    -- 🔄 RESET IF DATE CHANGED
    if stored.date == today then
      tasks = stored
    end
  end

  -- 🛡️ GUARANTEE FIELDS (ANTI-NIL)
  tasks.play_matches = tasks.play_matches or 0
  tasks.win_matches = tasks.win_matches or 0
  tasks.dice_rolls = tasks.dice_rolls or 0
  tasks.completed = tasks.completed or {
    play = false,
    win = false,
    dice = false
  }

  return nk.json_encode(tasks), 200
end

nk.register_rpc(get_daily_tasks, "daily.tasks.get")
