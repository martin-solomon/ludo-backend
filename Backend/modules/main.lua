local nk = require("nakama")

------------------------------------------------------------------------
-- 🚑 EMERGENCY FIX: RESTORE MISSING MATCHMAKER
------------------------------------------------------------------------
if not nk.matchmaker_add then
    nk.logger_warn("⚠️ WARNING: nk.matchmaker_add is missing! Attempting to restore...")

    -- 1. Force clear the cached 'nakama' module
    package.loaded["nakama"] = nil

    -- 2. Require it again to get a FRESH copy
    local fresh_nk = require("nakama")

    -- 3. Check if the fresh copy has the function
    if fresh_nk.matchmaker_add then
        -- 4. Restore the function to our current 'nk' object
        nk.matchmaker_add = fresh_nk.matchmaker_add
        nk.logger_info("✅ SUCCESS: nk.matchmaker_add has been restored!")
        
        -- 5. Also fix the global cache so future requires are safe
        package.loaded["nakama"] = fresh_nk
    else
        nk.logger_error("❌ CRITICAL: Even the fresh reload is broken. Server version issue?")
    end
end
------------------------------------------------------------------------

-- ✅ Seed RNG ONCE
math.randomseed(os.time())

-- Helper: safely require a module
local function safe_require(name)
  local ok, result = pcall(require, name)
  if not ok then
    nk.logger_error("main.lua: require '" .. name .. "' failed: " .. tostring(result))
    return nil, result
  end
  return result, nil
end

------------------------------------------------
-- 1) Low-level helpers
------------------------------------------------
safe_require("utils_rpc")

----------------------------------------------
-- avatar
------------------------------------------------
safe_require("avatar_catalog")

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
  nk.logger_warn("main.lua: ludo_match error: " .. tostring(match_err))
end

------------------------------------------------
-- 3.5) Matchmaker -> Match bridge
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
end

if not _G.__MATCHMAKER_REGISTERED then
  nk.register_matchmaker_matched(on_matchmaker_matched)
  _G.__MATCHMAKER_REGISTERED = true
end

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
-- 5) Leaderboard & Rewards
------------------------------------------------
safe_require("apply_match_rewards")
safe_require("rpc_get_leaderboard")
-- safe_require("rpc_dev_init_leaderboard") 

------------------------------------------------
-- 6) Daily Tasks & Login
------------------------------------------------
safe_require("rpc_get_daily_login_rewards")
safe_require("rpc_claim_daily_login_reward")
safe_require("rpc_get_daily_tasks")
safe_require("rpc_claim_daily_task")




nk.logger_info("main.lua loaded: Modules loaded and matchmaker repaired.")
