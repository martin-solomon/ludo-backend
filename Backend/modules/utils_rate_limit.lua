local nk = require("nakama")

local M = {}

-- simple in-memory rate guard (per node)
local last_call = {}

function M.check(context, key, cooldown_seconds)
  -- allow match calls always
  if context.execution_mode == "match" then
    return true
  end

  local user_id = context.user_id
  if not user_id then
    return false, "unauthorized"
  end

  local now = os.time()
  local k = user_id .. ":" .. key

  local last = last_call[k]
  if last and (now - last) < cooldown_seconds then
    return false, "rate_limited"
  end

  last_call[k] = now
  return true
end

return M
