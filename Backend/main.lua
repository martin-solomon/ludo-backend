local nk = require("nakama")

local function safe_require(name)
  local ok, err = pcall(require, name)
  if not ok then
    nk.logger_error("FAILED loading " .. name .. ": " .. tostring(err))
  else
    nk.logger_info("Loaded " .. name)
  end
end

-- CORE
safe_require("utils_rpc")

-- AUTH / PROFILE
safe_require("create_guest_profile")
safe_require("create_user")
safe_require("convert_guest_to_permanent")
safe_require("guest_cleanup")
safe_require("admin_delete_account")

-- MATCH
safe_require("ludo_match")
safe_require("rpc_quick_join")
safe_require("rpc_player_list")
safe_require("rpc_match_start")

-- LEADERBOARD
safe_require("apply_match_rewards")
safe_require("rpc_get_leaderboard")

nk.logger_info("Nakama Lua runtime started")
