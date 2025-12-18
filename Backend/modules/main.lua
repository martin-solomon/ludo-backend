-- main.lua
-- Central loader for Nakama Lua modules. Uses safe_require so a broken module
-- doesn't stop the whole runtime from starting.

local nk = require("nakama")

-- 0) Optional helpers (non-fatal)
pcall(function() require("main_helpers") end)

-- Helper: safely require a module and log any error without crashing startup.
local function safe_require(name)
  local ok, result = pcall(require, name)
  if not ok then
    nk.logger_error("main.lua: require '" .. name .. "' failed: " .. tostring(result))
    return nil, result
  end
  nk.logger_info("main.lua: required '" .. name .. "'")
  return result, nil
end

----------------------------------------------------------------
-- 1) Low-level helpers
----------------------------------------------------------------
safe_require("utils_rpc")

----------------------------------------------------------------
-- 2) Core account / profile RPCs
----------------------------------------------------------------
local rpc_first = {
  "create_guest_profile",
  "create_user",
  "convert_guest_to_permanent",
  "admin_delete_account",
  "guest_cleanup"
}

for _, m in ipairs(rpc_first) do
  safe_require(m)
end

----------------------------------------------------------------
-- 3) Authoritative Match Registration (CRITICAL)
----------------------------------------------------------------
local ludo_match, match_err = safe_require("ludo_match")
if ludo_match then
  nk.match_register("ludo_match", ludo_match)
  nk.logger_info("main.lua: ludo_match registered successfully")
else
  nk.logger_warn("main.lua: ludo_match NOT registered: " .. tostring(match_err))
end

----------------------------------------------------------------
-- 4) Match-related & gameplay RPCs
----------------------------------------------------------------
-- These depend on match existing
safe_require("rpc_create_match")
safe_require("rpc_get_profile")

-- Existing late RPCs
local rpc_late = {
  "rpc_quick_join",
  "rpc_player_list",
  "rpc_match_start"
}

for _, m in ipairs(rpc_late) do
  safe_require(m)
end

----------------------------------------------------------------
-- 5) Final startup log
----------------------------------------------------------------
nk.logger_info("✅ main.lua loaded: matches + RPCs registered safely")
