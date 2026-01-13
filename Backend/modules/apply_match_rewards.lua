local nk = require("nakama")
local rate_limit = require("utils_rate_limit")

-- 🟩 DAILY TASKS (NEW – REQUIRED)
local daily_tasks = require("update_daily_tasks")

--------------------------------------------------
-- DUPLICATE PROTECTION
--------------------------------------------------
local function reward_already_given(user_id, match_id)
  local result = nk.storage_read({
    { collection = "match_rewards", key = match_id, user_id = user_id }
  })
  return result and #result > 0
end

local function mark_reward_given(user_id, match_id)
  nk.storage_write({
    {
      collection = "match_rewards",
      key = match_id,
      user_id = user_id,
      value = { given_at = os.time() },
      permission_read = 0,
      permission_write = 0
    }
  })
end

--------------------------------------------------
-- APPLY ONLINE MATCH REWARDS
--------------------------------------------------
local function apply_rewards(user_id, rewards, match_id)
  if not match_id or reward_already_given(user_id, match_id) then
    return nil
  end

  local objects = nk.storage_read({
    { collection = "profile", key = "player", user_id = user_id }
  })
  if not objects or #objects == 0 then return nil end

  local profile = objects[1].value

  --------------------------------------------------
  -- PROFILE UPDATES
  --------------------------------------------------
  profile.coins = math.max(0, (profile.coins or 0) + (rewards.coins or 0))
  profile.xp = (profile.xp or 0) + (rewards.xp or 0)
  profile.wins = (profile.wins or 0) + 1
  profile.matches_played = (profile.matches_played or 0) + 1
  profile.level = math.floor(profile.xp / 100) + 1

  nk.storage_write({
    {
      collection = "profile",
      key = "player",
      user_id = user_id,
      value = profile,
      permission_read = 1,
      permission_write = 0
    }
  })

  --------------------------------------------------
  -- 🟩 DAILY TASK GAMEPLAY HOOKS (NEW)
  -- Purpose: Update match-based daily tasks
  --------------------------------------------------

  -- Match was played and completed
  daily_tasks.update(user_id, "match_played", 1)
  daily_tasks.update(user_id, "match_complete", 1)

  -- Match ended cleanly (reward implies no quit)
  daily_tasks.update(user_id, "match_no_quit", 1)

  -- Player won the match
  daily_tasks.update(user_id, "match_win", 1)

  --------------------------------------------------
  -- FINALIZE
  --------------------------------------------------
  mark_reward_given(user_id, match_id)

  --------------------------------------------------
  -- ✅ LEADERBOARD UPDATE (LEVEL → WINS)
  --------------------------------------------------
  local level = profile.level or 1
  local wins  = profile.wins or 0

  local score = (level * 1000000) + wins

  pcall(function()
    nk.leaderboard_record_write(
      "global_rank",
      user_id,
      score,
      0,
      {
        level = level,
        wins = wins,
        avatar_id = profile.avatar_id or "default",
        display_name = profile.display_name or "Player"
      }
    )
  end)

  return profile
end

--------------------------------------------------
-- TEST RPC (DEV ONLY)
--------------------------------------------------
local function apply_match_rewards_rpc(context, payload)
  if not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local input = nk.json_decode(payload or "{}")

  local profile = apply_rewards(
    input.user_id,
    { coins = input.coins or 0, xp = input.xp or 0 },
    input.match_id
  )

  if not profile then
    return nk.json_encode({ success = false })
  end

  return nk.json_encode({ success = true, profile = profile })
end

nk.register_rpc(apply_match_rewards_rpc, "apply_match_rewards")

return apply_rewards
