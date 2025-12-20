local nk = require("nakama")

local function get_daily_tasks(context, payload)
  if not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local objects = nk.storage_read({
    {
      collection = "daily_tasks",
      key = "today",
      user_id = context.user_id
    }
  })

  if #objects == 0 then
    return nk.json_encode({}), 200
  end

  return nk.json_encode(objects[1].value), 200
end

nk.register_rpc(get_daily_tasks, "daily.tasks.get")
