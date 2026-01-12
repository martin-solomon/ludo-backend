-- daily_login_task.lua
-- Fixed daily login reward (server authority)

local LOGIN_TASK = {
  id = "daily_login",
  title = "Daily Login Reward",
  type = "login",
  target = 1,
  reward = {
    coins = 50
  }
}

return LOGIN_TASK
