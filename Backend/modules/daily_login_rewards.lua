-- daily_login_rewards.lua
-- System-1: Daily Login Rewards (STATE ONLY, NO COINS)

local nk = require("nakama")

local M = {}

-- Fixed weekly reward table (used by CLAIM RPC)
M.DAILY_REWARDS = {10, 20, 30, 40, 50, 60, 70}

local function today_date()
  return os.date("!%Y-%m-%d")
end

--------------------------------------------------
-- Ensure daily login state exists (SAFE ON LOGIN)
--------------------------------------------------
function M.ensure_state(user_id)
  if not user_id then return end

  local records = nk.storage_read({
    {
      collection = "daily_login_rewards",
      key = "state",
      user_id = user_id
    }
  })

  -- First-time user → initialize
  if not records or #records == 0 then
    nk.storage_write({
      {
        collection = "daily_login_rewards",
        key = "state",
        user_id = user_id,
        value = {
          current_day = 1,        -- Day 1 is next claim
          last_claim_date = ""    -- Nothing claimed yet
        },
        permission_read = 1,
        permission_write = 0
      }
    })
  end
end

--------------------------------------------------
-- Read helper (used by GET RPC)
--------------------------------------------------
function M.get_state(user_id)
  local today = today_date()

  local records = nk.storage_read({
    {
      collection = "daily_login_rewards",
      key = "state",
      user_id = user_id
    }
  })

  local state = {
    current_day = 1,
    last_claim_date = ""
  }

  if records and #records > 0 then
    state = records[1].value
  end

  return {
    current_day = state.current_day,
    claimed_today = (state.last_claim_date == today),
    rewards = M.DAILY_REWARDS
  }
end

return M
