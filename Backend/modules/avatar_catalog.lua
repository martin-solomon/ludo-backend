-- avatar_catalog.lua
-- Single source of truth for all avatar definitions

local M = {}

-- 🔒 Backend-owned avatar catalog
M.CATALOG = {
  avatar_1 = {
    id  = "avatar_1",
    url = "https://newcol-api.nlsn.in/assets/boy_avatar.png"
  },
  avatar_2 = {
    id  = "avatar_2",
    url = "https://newcol-api.nlsn.in/assets/knight_avatar.png"
  },
  avatar_3 = {
    id  = "avatar_3",
    url = "https://newcol-api.nlsn.in/assets/magicien_avatar.png"
  }
}

-- ✅ Default avatar (used everywhere safely)
M.DEFAULT = M.CATALOG.avatar_1

-- ✅ Validate avatar id exists
function M.is_valid(avatar_id)
  return avatar_id ~= nil and M.CATALOG[avatar_id] ~= nil
end

-- ✅ Get full avatar object (id + url)
function M.get(avatar_id)
  return M.CATALOG[avatar_id] or M.DEFAULT
end

return M
