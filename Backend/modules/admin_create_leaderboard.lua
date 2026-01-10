local nk = require("nakama")

local function admin_create_leaderboards(context, payload)
  if not context.user_id or not context.is_admin then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  -- Create ONLY if not exists
  nk.register_leaderboard(
    "global_wins",
    false,      -- authoritative
    "desc",     -- higher wins = higher rank
    "incr",     -- only increment
    nil,        -- no reset (lifetime)
    { "wins" }
  )

  return nk.json_encode({ success = true })
end

nk.register_rpc(admin_create_leaderboards, "admin_create_leaderboards")
