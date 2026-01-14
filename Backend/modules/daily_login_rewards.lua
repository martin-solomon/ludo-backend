local nk = require("nakama")

local M = {}

local function today()
  return os.date("!%Y-%m-%d")
end

function M.get_or_create(user_id)
  local r = nk.storage_read({
    { collection = "daily_login_state", key = "state", user_id = user_id }
  })

  if r and #r > 0 then
    return r[1].value
  end

  local state = {
    current_day = 1,
    last_claim_date = ""
  }

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

  return state
end

return M
