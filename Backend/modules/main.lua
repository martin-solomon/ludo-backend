-- main.lua
-- HARD SAFE RUNTIME LOADER
-- This file is designed to NEVER crash Nakama.
-- Broken modules will be logged and skipped instead of causing 502.

local nk = require("nakama")

nk.logger_info("🚀 Nakama Lua runtime starting (SAFE MODE)")

------------------------------------------------
-- SAFE REQUIRE HELPER
------------------------------------------------
local function safe_require(name)
  local ok, mod = pcall(require, name)
  if not ok then
    nk.logger_error("❌ FAILED to load module: " .. name)
    nk.logger_error("   Reason: " .. tostring(mod))
    return nil
  end
  nk.logger_info("✅ Loaded module: " .. name)
  return mod
end

------------------------------------------------
-- CORE UTILITIES (SAFE)
------------------------------------------------
safe_require("utils_rpc")
safe_require("inventory_helper")
safe_require("utils_rate_limit")

------------------------------------------------
-- AUTH / PROFILE RPCs
------------------------------------------------
safe_require("create_guest_profile")
safe_require("create_user")
safe_require("convert_guest_to_permanent")
safe_require("admin_delete_account")
safe_require("guest_cleanup")

------------------------------------------------
-- MATCH HANDLER
------------------------------------------------
local match_mod = safe_require("ludo_match")
if not match_mod then
  nk.logger_warn("⚠️ ludo_match not loaded – matches disabled")
end

------------------------------------------------
-- MATCH RPCs
------------------------------------------------
safe_require("rpc_quick_join")
safe_require("rpc_player_list")
safe_require("rpc_match_start")

------------------------------------------------
-- PROGRESSION / ECONOMY
------------------------------------------------
safe_require("apply_match_rewards")
safe_require("update_daily_tasks")

------------------------------------------------
-- READ-ONLY RPCs
------------------------------------------------
safe_require("rpc_get_profile")
safe_require("rpc_get_leaderboard")

------------------------------------------------
-- OPTIONAL AUTH HOOK (SAFE)
------------------------------------------------
local after_auth = safe_require("after_authenticate")
if after_auth and after_auth.after_authenticate then
  local ok, err = pcall(function()
    nk.register_after_authenticate(after_auth.after_authenticate)
  end)
  if ok then
    nk.logger_info("✅ after_authenticate hook registered")
  else
    nk.logger_error("❌ Failed to register after_authenticate: " .. tostring(err))
  end
else
  nk.logger_warn("⚠️ after_authenticate hook not registered (module missing or invalid)")
end

------------------------------------------------
-- FINAL CONFIRMATION
------------------------------------------------
nk.logger_info("✅ Nakama Lua runtime loaded successfully (NO 502)")
