-- main.lua
-- Central loader for Nakama Lua modules.
-- Designed to be crash-safe, order-correct, and production-ready.

local nk = require("nakama")

-------------------------------------------------------------
-- Helper: safely require a module without crashing runtime
-------------------------------------------------------------
local function safe_require(name)
  local ok, result = pcall(require, name)
  if not ok then
    nk.logger_error("main.lua: require '" .. name .. "' failed: " .. tostring(result))
    return nil, result
  end
  nk.logger_info("main.lua: required '" .. name .. "'")
  return result, nil
end

-------------------------------------------------------------
-- 0) Optional helpers (MUST NOT TOUCH nk)
-------------------------------------------------------------
pcall(function()
  require("main_helpers")
end)

-------------------------------------------------------------
-- 1) Core account / profile RPCs
-- These modules SELF-REGISTER their RPCs internally
-------------------------------------------------------------
local rpc_core = {
  "create_guest_profile",
  "create_user",
  "convert_guest_to_permanent",
  "admin_delete_account",
  "guest_cleanup"
}

for _, m in ipairs(rpc_core) do
  safe_require(m)
end

-------------------------------------------------------------
-- 2) Authoritative Match Registration (CRITICAL ORDER)
-- This MUST happen before utils/helpers
-------------------------------------------------------------
local ludo_match, match_err = safe_require("ludo_match")
if ludo_match then
  nk.match_register("ludo_match", ludo_match)
  nk.logger_info("main.lua: ludo_match registered successfully")
else
  nk.logger_error("main.lua: ludo_match NOT registered: " .. tostring(match_err))
end

-------------------------------------------------------------
-- 3) Match & profile related RPCs (self-registering)
-------------------------------------------------------------
safe_require("rpc_create_match")
safe_require("rpc_get_profile")

-------------------------------------------------------------
-- 4) Late RPCs that depend on match / core logic
-------------------------------------------------------------
local rpc_late = {
  "rpc_quick_join",
  "rpc_player_list",
  "rpc_match_start"
}

for _, m in ipairs(rpc_late) do
  safe_require(m)
end

-------------------------------------------------------------
-- 5) Utility helpers (LOAD LAST)
-- utils_rpc MUST NOT overwrite nk
-------------------------------------------------------------
safe_require("utils_rpc")

-------------------------------------------------------------
-- 6) Final startup confirmation
-------------------------------------------------------------
nk.logger_info("✅ main.lua loaded successfully — runtime stable")
