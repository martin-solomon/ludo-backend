local nk = require("nakama")

-- =========================================================
-- ADMIN: CREATE GLOBAL WINS LEADERBOARD (ONE-TIME)
-- =========================================================
local function admin_create_leaderboard(context, payload)

  -- 🔒 ADMIN ONLY
  if not context.user_id or not context.is_admin then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  -- ✅ CREATE LEADERBOARD
  nk.leaderboard_create(
    "global_wins",   -- leaderboard id
    false,           -- authoritative (server controlled)
    "desc",          -- higher wins = higher rank
    "incr",          -- wins only increment
    nil,             -- no reset (lifetime leaderboard)
    { "wins" }       -- metadata fields
  )

  return nk.json_encode({
    success = true,
    leaderboard = "global_wins"
  })
end

nk.register_rpc(admin_create_leaderboard, "admin_create_leaderboard")
