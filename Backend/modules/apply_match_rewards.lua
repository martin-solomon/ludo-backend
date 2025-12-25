-- apply_match_rewards.lua
local nk = require("nakama")

-- =====================================================
-- PHASE C ADDITION: REWARD DUPLICATE PREVENTION (NEW)
-- =====================================================
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
      value = {
        given_at = os.time()
      },
      permission_read = 0,
      permission_write = 0
    }
  })
end

-- =====================================================
-- CORE SERVER REWARD LOGIC (USED BY MATCH)
-- =====================================================
local function apply_rewards(user_id, rewards, match_id)
  -- 🔒 PHASE C: Require match_id
  if not match_id then
    nk.logger_error("apply_rewards blocked: missing match_id")
    return nil
  end

  -- 🔒 PHASE C: Prevent duplicate rewards
  if reward_already_given(user_id, match_id) then
    nk.logger_warn(
      string.format(
        "Duplicate reward prevented | user=%s | match=%s",
        user_id,
        match_id
      )
    )
    return nil
  end

  -- Read existing profile
  local objects = nk.storage_read({
    {
      collection = "profile",
      key = "player",
      user_id = user_id
    }
  })

  if not objects or #objects == 0 then
    nk.logger_error("apply_rewards: profile not found for user_id %s", user_id)
    return nil
  end

  local profile = objects[1].value

  -- Safety defaults (UNCHANGED)
  profile.coins = profile.coins or 0
  profile.xp = profile.xp or 0
  profile.level = profile.level or 1
  profile.wins = profile.wins or 0
  profile.matches_played = profile.matches_played or 0

  -- Apply rewards (UNCHANGED)
  profile.coins = profile.coins + (rewards.coins or 0)
  profile.xp = profile.xp + (rewards.xp or 0)
  profile.wins = profile.wins + 1
  profile.matches_played = profile.matches_played + 1

  -- Level formula (UNCHANGED)
  profile.level = math.floor(profile.xp / 100) + 1

  -- Write back (SERVER AUTHORITATIVE)
  nk.storage_write({
    {
      collection = "profile",
      key = "player",
      user_id = user_id,
      value = profile,
      permission_read = 1,
      permission_write = 0 -- 🔒 LOCKED (Phase D-2)
    }
  })

  -- 🔐 PHASE C: Lock reward for this match
  mark_reward_given(user_id, match_id)

  nk.logger_info(
    string.format(
      "Rewards applied | user=%s | coins=%d | xp=%d | level=%d | match=%s",
      user_id,
      profile.coins,
      profile.xp,
      profile.level,
      match_id
    )
  )

  return profile
end

-- =====================================================
-- RPC (FOR TESTING ONLY – POSTMAN)
-- =====================================================
local function apply_match_rewards_rpc(context, payload)
  if not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local input = nk.json_decode(payload or "{}")

  if not input.user_id then
    return nk.json_encode({ error = "missing_user_id" }), 400
  end

  -- 🔒 PHASE C: Require match_id even for testing
  if not input.match_id then
    return nk.json_encode({ error = "missing_match_id" }), 400
  end

  local profile = apply_rewards(
    input.user_id,
    {
      coins = input.coins or 0,
      xp = input.xp or 0
    },
    input.match_id
  )

  if not profile then
    return nk.json_encode({
      success = false,
      reason = "reward_not_applied"
    })
  end

  return nk.json_encode({
    success = true,
    profile = profile
  })
end

nk.register_rpc(apply_match_rewards_rpc, "apply_match_rewards")

-- EXPORT CORE FUNCTION FOR MATCH USE
return apply_rewards

