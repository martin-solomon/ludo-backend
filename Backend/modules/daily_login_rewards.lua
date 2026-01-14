-- daily_login_rewards.lua
-- SYSTEM-1: DAILY LOGIN REWARDS (STATE ONLY)

local nk = require("nakama")

local M = {}

--------------------------------------------------
-- Ensure daily login state exists
-- Called from create_user / create_guest_profile
--------------------------------------------------
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
    current_day = 1,        -- 1..7 (next claimable day)
    last_claim_date = ""    -- empty = not claimed today
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

--------------------------------------------------
-- Read-only accessor
--------------------------------------------------
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

  -- Safety fallback (should not normally happen)
  return {
    current_day = 1,
    last_claim_date = ""
  }
end

return M
