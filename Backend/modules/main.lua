-- main.lua
-- Central loader for Nakama Lua modules.
-- SAFE version based on last known working runtime.

local nk = require("nakama")

------------------------------------------------
-- Optional helpers (must NOT touch nk)
------------------------------------------------
pcall(function()
  require("main_helpers")
end)

------------------------------------------------
-- Safe require helper (for logging only)
------------------------------------------------
local function safe_require(name)
  local ok, result = pcall(require, name)
  if not ok then
    nk.logger_error("main.lua: require '" .. name .. "' failed: " .. tostring(result))
    return nil
  end
  nk.logger_info("main.lua: required '" .. name .. "'")
  return result
end

------------------------------------------------
-- 1) Core helpers (KEEP — already working)
------------------------------------------------
safe_require("utils_rpc")

------------------------------------------------
-- 2) Core account / profile RPCs
------------------------------------------------
safe_require("create_guest_profile")
safe_require("create_user")
safe_require("convert_guest_to_permanent")
safe_require("admin_delete_account")
safe_require("guest_cleanup")

------------------------------------------------
-- 3) Match logic (AUTO-REGISTERED BY NAKAMA)
-- IMPORTANT: DO NOT call nk.match_register
------------------------------------------------
safe_require("ludo_match")

------------------------------------------------
-- 4) Match-related RPCs
------------------------------------------------
safe_require("rpc_create_match")
safe_require("rpc_quick_join")
safe_require("rpc_player_list")
safe_require("rpc_match_start")
safe_require("rpc_get_profile")

------------------------------------------------
-- 5) Startup confirmation
------------------------------------------------
nk.logger_info("✅ main.lua loaded successfully (project-safe)")
