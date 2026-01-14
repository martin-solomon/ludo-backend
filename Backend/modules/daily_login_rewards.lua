-- daily_login_rewards.lua
-- SYSTEM-1: DAILY LOGIN STATE (NO AUTO-CLAIM)

local nk = require("nakama")

local M = {}

-- Ensure state exists ONCE (never reset)
function M.ensure(user_id)
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
    last_claim_date = ""    -- empty means not claimed yet
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
function M.get(user_id)
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

  return M.ensure(user_id)
end

return M
