local nk = require("nakama")
local rate_limit = require("utils_rate_limit")

--------------------------------------------------
-- DUPLICATE REWARD PREVENTION
--------------------------------------------------
local function reward_already_given(user_id, match_id)
  local result = nk.storage_read({
    {
      collection = "match_rewards",
      key = match_id,
      user_id = user_id
    }
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
-- CORE APPLY REWARDS (ONLINE MATCH ONLY)
--------------------------------------------------
local function apply_rewards(user_id, rewards, match_id)
  if not match_id then
    nk.logger_error("apply_rewards blocked: missing match_id")
    return nil
  end

  if reward_already_given(user_id, match_id) then
    nk.logger_warn("Duplicate reward blocked | user=" .. user_id)
    return nil
  end

  local objects = nk.storage_read({
    {
      collection = "profile",
      key = "player",
      user_id = user_id
    }
  })

  if not objects or #objects == 0 then
    return nil
  end

  local profile = objects[1].value

  --------------------------------------------------
  -- PROFILE UPDATES
  --------------------------------------------------
  profile.coins = (profile.coins or 0) + (rewards.coins or 0)
  profile.coins = math.max(0, profile.coins)

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

  mark_reward_given(user_id, match_id)

  --------------------------------------------------
  -- UPDATE GLOBAL WINS LEADERBOARD
  -- ONLINE MATCHES ONLY
  --------------------------------------------------
  local username = profile.username or user_id

  nk.leaderboard_record_write(
    "global_wins",     -- leaderboard id
    user_id,           -- owner
    username,          -- display name
    1,                 -- increment wins by 1
    { wins = true }    -- metadata (optional)
  )

  --------------------------------------------------
  -- ECONOMY AUDIT LOG (READ-ONLY)
  --------------------------------------------------
  nk.storage_write({
    {
      collection = "economy_log",
      key = nk.uuid_v4(),
      user_id = user_id,
      value = {
        source = "match_reward",
        match_id = match_id,
        coins_delta = rewards.coins or 0,
        xp_delta = rewards.xp or 0,
        timestamp = os.time()
      },
      permission_read = 0,
      permission_write = 0
    }
  })

  return profile
end

--------------------------------------------------
-- RPC (TESTING ONLY)
--------------------------------------------------
local function apply_match_rewards_rpc(context, payload)
  if not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local ok, reason = rate_limit.check(context, "apply_match_rewards", 2)
  if not ok then
    return nk.json_encode({ error = reason }), 429
  end

  local input = nk.json_decode(payload or "{}")

  if not input.user_id or not input.match_id then
    return nk.json_encode({ error = "missing_params" }), 400
  end

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
