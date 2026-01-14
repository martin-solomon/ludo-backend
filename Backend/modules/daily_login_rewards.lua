-- daily_login_state.lua
-- SINGLE SOURCE OF TRUTH for daily login state

local nk = require("nakama")

local M = {}

local function today()
  return os.date("!%Y-%m-%d")
end

-- Create state ONCE, never reset
function M.ensure(user_id)
  local records = nk.storage_read({
    { collection = "daily_login_state", key = "state", user_id = user_id }
  })

  if records and #records > 0 then
    return records[1].value
  end

  local state = {
    current_day = 1,
    last_claim_date = "",
    created_at = today()
  }

  nk.storage_write({
    {
      collection = "daily_login_state",
      key = "state",
      user_id = user_id,
      value = state,
      permission_read = 1,
      permission_write = 0
    }
  })

  return state
end

function M.get(user_id)
  local records = nk.storage_read({
    { collection = "daily_login_state", key = "state", user_id = user_id }
  })

  if records and #records > 0 then
    return records[1].value
  end

  return M.ensure(user_id)
end

function M.update(user_id, state)
  nk.storage_write({
    {
      collection = "daily_login_rewards",
      key = "state",
      user_id = user_id,
      value = state,
      permission_read = 1,
      permission_write = 0
    }
  })
end

return M
