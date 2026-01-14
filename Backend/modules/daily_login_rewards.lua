-- daily_login_rewards.lua
-- DAILY LOGIN STREAK STATE (NO CLAIM LOGIC)

local nk = require("nakama")
local M = {}

function M.get_state(user_id)
  local r = nk.storage_read({
    { collection = "daily_login_rewards", key = "state", user_id = user_id }
  })

  if r and #r > 0 then
    return r[1].value
  end

  return { current_day = 1 }
end

function M.save_state(user_id, state)
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
