-- main.lua
-- Central loader for Nakama Lua modules. Uses safe_require so a broken module
-- doesn't stop the whole runtime from starting.

local nk = require("nakama")

------------------------------------------------
-- GLOBAL WINS LEADERBOARD (ONCE)
------------------------------------------------
-- Purpose:
--   - Rank players by ONLINE match wins
--   - Higher wins = higher rank
--   - Persistent across restarts
--   - Auto-sorted & paginated by Nakama
--
-- IMPORTANT:
--   - Records are updated ONLY from online match end logic
--   - No frontend writes
------------------------------------------------
nk.register_leaderboard(
  "global_wins",      -- leaderboard id
  false,              -- authoritative (server-controlled)
  "desc",             -- higher wins rank higher
  "incr",             -- wins only increase
  nil,                -- no reset (lifetime leaderboard)
  { "wins" }          -- metadata fields (optional)
)

------------------------------------------------
-- 0) Optional helpers (non-fatal)
------------------------------------------------
pcall(function()
  require("main_helpers")
end)

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
-- 1) Low-level helpers (loaded FIRST)
------------------------------------------------
safe_require("utils_rpc")
safe_require("inventory_helper")

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
-- 5) Startup confirmation
------------------------------------------------
nk.logger_info("main.lua loaded: runtime modules required and RPCs registered.")
