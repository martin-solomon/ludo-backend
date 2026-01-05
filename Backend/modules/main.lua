-- main.lua
-- Central loader for Nakama Lua modules.
-- Uses safe_require so a broken module does NOT crash the server.

local nk = require("nakama")

------------------------------------------------
-- Helper: safely require a module
------------------------------------------------
local function safe_require(name)
  local ok, result = pcall(require, name)
  if not ok then
    nk.logger_error("main.lua: require '" .. name .. "' failed: " .. tostring(result))
    return nil
  end
  nk.logger_info("main.lua: loaded '" .. name .. "'")
  return result
end

------------------------------------------------
-- 0) OPTIONAL HELPERS (NON-FATAL)
------------------------------------------------
safe_require("main_helpers")

------------------------------------------------
-- 1) CORE HELPERS (LOAD FIRST)
------------------------------------------------
safe_require("utils_rpc")
safe_require("utils_rate_limit")
safe_require("inventory_helper")

------------------------------------------------
-- 2) AUTH LIFECYCLE HOOKS (CRITICAL)
------------------------------------------------
-- after_authenticate.lua MUST return a table with function after_authenticate()
local after_auth = require("after_authenticate")
if after_auth and type(after_auth.after_authenticate) == "function" then
  nk.register_after_authenticate(after_auth.after_authenticate)
  nk.logger_info("main.lua: after_authenticate hook registered")
else
  nk.logger_warn("main.lua: after_authenticate hook NOT registered (missing or invalid)")
end

------------------------------------------------
-- 3) ACCOUNT / PROFILE RPCs
------------------------------------------------
local account_rpcs = {
  "create_guest_profile",
  "create_user",
  "convert_guest_to_permanent",
  "admin_delete_account",
  "guest_cleanup"
}

for _, mod in ipairs(account_rpcs) do
  safe_require(mod)
end

------------------------------------------------
-- 4) MATCH HANDLER
------------------------------------------------
-- ludo_match.lua RETURNS a match table
-- Nakama auto-registers it when required
local match_mod = safe_require("ludo_match")
if not match_mod then
  nk.logger_error("main.lua: ludo_match failed to load")
end

------------------------------------------------
-- 5) MATCH-RELATED RPCs
------------------------------------------------
local match_rpcs = {
  "rpc_quick_join",
  "rpc_player_list",
  "rpc_match_start"
}

for _, mod in ipairs(match_rpcs) do
  safe_require(mod)
end

------------------------------------------------
-- 6) ECONOMY / PROGRESSION
------------------------------------------------
safe_require("apply_match_rewards")
safe_require("update_daily_tasks")

------------------------------------------------
-- 7) READ-ONLY RPCs
------------------------------------------------
safe_require("rpc_get_profile")
safe_require("rpc_get_leaderboard")

------------------------------------------------
-- 8) STARTUP CONFIRMATION
------------------------------------------------
nk.logger_info("main.lua loaded successfully — Nakama runtime ready")
