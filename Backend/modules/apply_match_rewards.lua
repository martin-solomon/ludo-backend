local nk = require("nakama")
local rate_limit = require("utils_rate_limit")

-- 🟩 DAILY TASKS
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
-- APPLY ONLINE MATCH REWARDS (AUTHORITATIVE)
--------------------------------------------------
local function apply_rewards(user_id, rewards, match_id)
  if not match_id or reward_already_given(user_id, match_id) then
    return nil
  end

  --------------------------------------------------
  -- READ PROFILE (NO COINS HERE)
  --------------------------------------------------
  local objects = nk.storage_read({
    { collection = "profile", key = "player", user_id = user_id }
  })
  if not objects or #objects == 0 then return nil end

  local profile = objects[1].value

  --------------------------------------------------
  -- UPDATE NON-ECONOMY STATS
  --------------------------------------------------
  local xp_gain = rewards.xp or 0

  profile.xp = (profile.xp or 0) + xp_gain
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
  -- 💰 WALLET UPDATE (ONLY SOURCE OF COINS)
  --------------------------------------------------
  local coin_reward = rewards.coins or 0
  if coin_reward > 0 then
    nk.wallet_update(
      user_id,
      { coins = coin_reward },
      { reason = "match_reward", match_id = match_id },
      false
    )
  end

  --------------------------------------------------
  -- 🟩 DAILY TASK GAMEPLAY HOOKS
  --------------------------------------------------
  daily_tasks.update(user_id, "match_played", 1)
  daily_tasks.update(user_id, "match_complete", 1)
  daily_tasks.update(user_id, "match_no_quit", 1)
  daily_tasks.update(user_id, "match_win", 1)

  --------------------------------------------------
  -- FINALIZE (DUPLICATE LOCK)
  --------------------------------------------------
  mark_reward_given(user_id, match_id)

  --------------------------------------------------
  -- 🏆 LEADERBOARD UPDATE
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
-- DEV TEST RPC (SAFE)
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

  return nk.json_encode({ success = true })
end

nk.register_rpc(apply_match_rewards_rpc, "apply_match_rewards")

return apply_rewards
