-- daily_login_rewards.lua
-- SYSTEM-1: DAILY LOGIN REWARDS (STATE ONLY)

local nk = require("nakama")
local M = {}

-- Ensure state exists (called from create_user / create_guest_profile)
function M.ensure_state(user_id)
  local r = nk.storage_read({
    { collection = "daily_login_rewards", key = "state", user_id = user_id }
  })

  if r and #r > 0 then
    return r[1].value
  end

  local state = {
    current_day = 1,        -- 1..7
    last_claim_date = ""    -- YYYY-MM-DD
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

-- Read-only accessor
function M.get_state(user_id)
  local r = nk.storage_read({
    { collection = "daily_login_rewards", key = "state", user_id = user_id }
  })

  if r and #r > 0 then
    return r[1].value
  end

  -- safety fallback
  return {
    current_day = 1,
    last_claim_date = ""
  }
end

return M
