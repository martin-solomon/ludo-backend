-- rpc_admin_create_leaderboard.lua
local nk = require("nakama")

local function rpc_admin_create_leaderboard(context, payload)
  if not context.user_id or not context.is_admin then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  nk.register_leaderboard(
    "global_wins",  -- leaderboard id
    false,          -- authoritative
    "desc",         -- higher wins rank higher
    "incr",         -- increment only
    nil,            -- no reset (lifetime)
    { "wins" }      -- metadata
  )

  return nk.json_encode({ success = true })
end

nk.register_rpc(rpc_admin_create_leaderboard, "admin_create_leaderboard")
