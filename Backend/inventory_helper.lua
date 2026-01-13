-- inventory_helper.lua
local nk = require("nakama")

local M = {}

-- This function guarantees inventory exists
function M.ensure_inventory(user_id)
  local objects = nk.storage_read({
    {
      collection = "inventory",
      key = "items",
      user_id = user_id
    }
  })

  -- If inventory already exists → return it
  if objects and #objects > 0 then
    return objects[1].value
  end

  -- Default inventory (FIRST TIME USER)
  local inventory = {
    boards = { "classic" },
    dice = { "default" },
    avatars = { "avatar_1" },
    emotes = {}
  }

  nk.storage_write({
    {
      collection = "inventory",
      key = "items",
      user_id = user_id,
      value = inventory,
      permission_read = 1,
      permission_write = 0
    }
  })

  nk.logger_info("Inventory created for user_id: " .. user_id)

  return inventory
end

return M
