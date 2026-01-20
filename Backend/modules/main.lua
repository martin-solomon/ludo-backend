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
-- 3.5) Matchmaker → Match bridge (REQUIRED)
------------------------------------------------

nk.register_matchmaker_matched(function(context, matched_users)
  -- All matched users share same mode
  local mode = matched_users[1].properties.mode or "solo_1v1"

  -- Create authoritative match
  local match_id = nk.match_create("ludo_match", {
    mode = mode
  })

  -- Join all matched users into the match
  for _, user in ipairs(matched_users) do
    nk.match_join(match_id, user.user_id, user.session_id)
  end

  nk.logger_info(
    "Matchmaker created ludo_match " .. match_id ..
    " for mode=" .. mode ..
    " players=" .. tostring(#matched_users)
  )
end)

------------------------------------------------
-- 4) Match-related RPCs
------------------------------------------------
local rpc_late = {
  "rpc_quick_join",
  "rpc_player_list",
  "rpc_match_start"
}

for _, m in ipairs(rpc_late) do
  safe_require(m)
end

------------------------------------------------
-- 5) ✅ LEADERBOARD-RELATED MODULES (ONLY ADDITION)
------------------------------------------------
-- Updates wins + leaderboard after ONLINE match
safe_require("apply_match_rewards")

-- Fetch leaderboard for frontend
safe_require("rpc_get_leaderboard")

safe_require("rpc_dev_init_leaderboard")


------------------------------------------------
-- 6) Startup confirmation
------------------------------------------------
nk.logger_info("main.lua loaded: runtime modules required and RPCs registered.")

-----------------------------------------------
-- daily login rewards
-----------------------------------------------
safe_require("rpc_get_daily_login_rewards")
safe_require("rpc_claim_daily_login_reward")

-----------------------------------------------
-- daily tasks (System-2)
-----------------------------------------------
safe_require("rpc_get_daily_tasks")
safe_require("rpc_claim_daily_task")
