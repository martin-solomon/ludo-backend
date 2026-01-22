-- main.lua (Debug Trap Version)
local nk = require("nakama")

-- 🔍 TRAP FUNCTION: Checks if the matchmaker function is still alive
local function check_health(stage_name)
  if not nk.matchmaker_add then
    nk.logger_error("❌ CRITICAL: 'nk.matchmaker_add' WAS DELETED BY: " .. stage_name)
  else
    nk.logger_info("✅ OK: matchmaker exists after " .. stage_name)
  end
end

-- 1. Check immediately at startup
check_health("STARTUP (Initial Load)")

-- ✅ Seed RNG ONCE
math.randomseed(os.time())

-- 0) Optional helpers
pcall(function() require("main_helpers") end)

-- Helper: safely require a module and log any error
local function safe_require(name)
  local ok, result = pcall(require, name)
  if not ok then
    nk.logger_error("main.lua: require '" .. name .. "' failed: " .. tostring(result))
    return nil, result
  end
  
  -- 🔍 TRAP: Check if this specific file killed the matchmaker
  check_health("Loading " .. name)
  
  nk.logger_info("main.lua: required '" .. name .. "'")
  return result, nil
end

------------------------------------------------
-- 1) Low-level helpers
------------------------------------------------
safe_require("utils_rpc")

------------------------------------------------
-- 2) Account / profile lifecycle RPCs
------------------------------------------------
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

------------------------------------------------
-- 3) Match handler
------------------------------------------------
local match_mod, match_err = safe_require("ludo_match")
if not match_mod then
  nk.logger_warn(
    "main.lua: ludo_match not loaded or returned nil: " .. tostring(match_err)
  )
end

------------------------------------------------
-- 3.5) Matchmaker -> Match bridge (REQUIRED)
------------------------------------------------
local function on_matchmaker_matched(context, matched_users)
  if not matched_users or #matched_users == 0 then return end
  local mode = matched_users[1].properties.mode or "solo_1v1"
  local match_id = nk.match_create("ludo_match", { mode = mode })

  for _, user in ipairs(matched_users) do
    nk.match_join(match_id, user.user_id, user.session_id)
  end

  for _, user in ipairs(matched_users) do
    nk.storage_write({
      {
        collection = "matchmaking",
        key = "active_match",
        user_id = user.user_id,
        value = { matchId = match_id },
        permission_read = 1,
        permission_write = 0
      }
    })
  end
  nk.logger_info("Matchmaker created ludo_match " .. match_id)
end

if not _G.__MATCHMAKER_REGISTERED then
  nk.register_matchmaker_matched(on_matchmaker_matched)
  _G.__MATCHMAKER_REGISTERED = true
end
check_health("Matchmaker Registration Block") -- Check here too

------------------------------------------------
-- 4) Match-related RPCs
------------------------------------------------
local rpc_late = {
  "rpc_quick_join",
  "rpc_player_list",
  "rpc_match_start",
  "rpc_matchmaker_cancel"
}

for _, m in ipairs(rpc_late) do
  safe_require(m)
end

------------------------------------------------
-- 5) Leaderboard-related modules
------------------------------------------------
safe_require("apply_match_rewards")
safe_require("rpc_get_leaderboard")
safe_require("rpc_dev_init_leaderboard")

------------------------------------------------
-- 6) Startup confirmation
------------------------------------------------
nk.logger_info("main.lua loaded: runtime modules required and RPCs registered.")

------------------------------------------------
-- Daily login rewards
------------------------------------------------
safe_require("rpc_get_daily_login_rewards")
safe_require("rpc_claim_daily_login_reward")

------------------------------------------------
-- Daily tasks (System-2)
------------------------------------------------
safe_require("rpc_get_daily_tasks")
safe_require("rpc_claim_daily_task")
