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
  },
  avatar_4 = {
    id  = "avatar_4",
    url = "https://newcol-api.nlsn.in/assets/piret_avatar.png"
  },
  avatar_5 = {
    id  = "avatar_5",
    url = "https://newcol-api.nlsn.in/assets/profile_avatar_1.png"
  },
  avatar_6 = {
    id  = "avatar_6",
    url = "https://newcol-api.nlsn.in/assets/profile_avatar_2.png"
  },
  avatar_7 = {
    id  = "avatar_7",
    url = "https://newcol-api.nlsn.in/assets/profile_avatar_3.png"
  }, 
  avatar_8 = {
    id  = "avatar_8",
    url = "https://newcol-api.nlsn.in/assets/profile_avatar_4.png"
  },
  avatar_9 = {
    id  = "avatar_9",
    url = "https://newcol-api.nlsn.in/assets/profile_avatar_5.png"
  },
  avatar_10 = {
    id  = "avatar_10",
    url = "https://newcol-api.nlsn.in/assets/queen_avatar.png"
  },
  avatar_11 = {
    id  = "avatar_11",
    url = "https://newcol-api.nlsn.in/assets/robot_avatar.png"
  },
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



