-- daily_login_rewards.lua
-- SYSTEM-1: DAILY LOGIN REWARDS (STATE ONLY, NO AUTO-CLAIM)

local nk = require("nakama")

local M = {}

local function today_date()
  return os.date("!%Y-%m-%d")
end

-- Ensure state exists (called on login / account creation)
function M.ensure_state(user_id)
  local records = nk.storage_read({
    {
      collection = "daily_login_rewards",
      key = "state",
      user_id = user_id
    }
  })

  if records and #records > 0 then
    return records[1].value
  end

  local state = {
    current_day = 1,        -- 1..7
    last_claim_date = ""    -- empty means not claimed today
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

-- READ-ONLY helper (used by get_daily_login_rewards)
function M.get_state(user_id)
  local records = nk.storage_read({
    {
      collection = "daily_login_rewards",
      key = "state",
      user_id = user_id
    }
  })

  if records and #records > 0 then
    return records[1].value
  end

  return {
    current_day = 1,
    last_claim_date = ""
  }
end

return M
