local nk = require("nakama")
local rewards_config = require("daily_rewards_config")

local M = {}

local function today()
  return os.date("%Y-%m-%d")
end

-- Storage key used
local COLLECTION = "daily_rewards"
local KEY = "progress"

--------------------------------------------------
-- Called on FIRST login of the day
--------------------------------------------------
function M.on_login(user_id)
  local objects = nk.storage_read({
    { collection = COLLECTION, key = KEY, user_id = user_id }
  })

  local data = objects[1] and objects[1].value or {
    day = 0,
    last_claim_date = "",
    week_start = today()
  }

  -- Already claimed today
  if data.last_claim_date == today() then
    return
  end

  -- Advance day
  data.day = data.day + 1

  -- Weekly reset
  if data.day > 7 then
    data.day = 1
    data.week_start = today()
  end

  local reward = rewards_config[data.day]
  if not reward then return end

  -- 💰 APPLY COINS
  nk.wallet_update(user_id, {
    coins = reward.coins
  }, {}, false)

  data.last_claim_date = today()

  nk.storage_write({
    {
      collection = COLLECTION,
      key = KEY,
      user_id = user_id,
      value = data,
      permission_read = 1,
      permission_write = 0
    }
  })
end

--------------------------------------------------
-- Fetch status for UI
--------------------------------------------------
function M.get_status(user_id)
  local objects = nk.storage_read({
    { collection = COLLECTION, key = KEY, user_id = user_id }
  })

  local data = objects[1] and objects[1].value or {
    day = 0,
    last_claim_date = "",
    week_start = today()
  }

  return {
    current_day = data.day,
    claimed_today = (data.last_claim_date == today())
  }
end

return M
