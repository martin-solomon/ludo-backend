-- main.lua
-- Central loader for Nakama Lua modules.
-- SAFE version with explicit match registration (required for Lua)

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
-- 1) Core helpers
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
-- 3) Match logic (EXPLICIT REGISTRATION REQUIRED)
------------------------------------------------
local ludo_match = safe_require("ludo_match")
if ludo_match then
  nk.match_register("ludo_match", ludo_match)
  nk.logger_info("✅ Match handler 'ludo_match' registered")
else
  nk.logger_error("❌ ludo_match failed to load — match creation will fail")
end

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
