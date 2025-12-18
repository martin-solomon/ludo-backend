-- main.lua
-- Minimal, production-safe Nakama runtime bootstrap

local nk = require("nakama")

------------------------------------------------
-- 1. Load core RPC modules (self-registering)
------------------------------------------------
require("create_guest_profile")
require("create_user")
require("convert_guest_to_permanent")
require("admin_delete_account")
require("guest_cleanup")

------------------------------------------------
-- 2. Load and register authoritative match
------------------------------------------------
local ludo_match = require("ludo_match")

-- IMPORTANT: ludo_match MUST return a table
-- with match_init, match_join, match_loop, etc.
nk.match_register("ludo_match", ludo_match)

------------------------------------------------
-- 3. Load match-related RPCs (self-registering)
------------------------------------------------
require("rpc_create_match")
require("rpc_get_profile")

------------------------------------------------
-- 4. Done
------------------------------------------------
nk.logger_info("✅ main.lua loaded successfully (stable runtime)")
