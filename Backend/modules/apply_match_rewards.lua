-- apply_match_rewards.lua
local nk = require("nakama")

local function apply_match_rewards_rpc(context, payload)
  -- Only server / match code should call this
  if not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local input = nk.json_decode(payload or "{}")
  local target_user_id = input.user_id
  local reward_coins = input.coins or 0
  local reward_xp = input.xp or 0

  if not target_user_id then
    return nk.json_encode({ error = "missing_user_id" }), 400
  end

  -- Read existing profile
  local objects = {
    {
      collection = "profile",
      key = "player",
      user_id = target_user_id
    }
  }

  local result = nk.storage_read(objects)
  if not result or #result == 0 then
    return nk.json_encode({ error = "profile_not_found" }), 404
  end

  local profile = result[1].value

  -- Default safety
  profile.coins = profile.coins or 0
  profile.xp = profile.xp or 0
  profile.level = profile.level or 1

  -- Apply rewards
  profile.coins = profile.coins + reward_coins
  profile.xp = profile.xp + reward_xp

  -- Simple level formula (can change later)
  -- Every 100 XP = +1 level
  profile.level = math.floor(profile.xp / 100) + 1

  -- Write back to storage (SERVER-ONLY)
  local write = {
    {
      collection = "profile",
      key = "player",
      user_id = target_user_id,
      value = profile,
      permission_read = 1,
      permission_write = 1 -- still open for now
    }
  }

  nk.storage_write(write)

  nk.logger_info(
    string.format(
      "Rewards applied to %s | coins +%d | xp +%d | level %d",
      target_user_id,
      reward_coins,
      reward_xp,
      profile.level
    )
  )

  return nk.json_encode({
    success = true,
    profile = profile
  })
end

nk.register_rpc(apply_match_rewards_rpc, "apply_match_rewards")
-- apply_match_rewards.lua
local nk = require("nakama")

-- ==============================
-- CORE SERVER REWARD LOGIC
-- ==============================
local function apply_rewards(user_id, rewards)
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

  -- Safety defaults
  profile.coins = profile.coins or 0
  profile.xp = profile.xp or 0
  profile.level = profile.level or 1
  profile.wins = profile.wins or 0
  profile.matches_played = profile.matches_played or 0

  -- Apply rewards
  profile.coins = profile.coins + (rewards.coins or 0)
  profile.xp = profile.xp + (rewards.xp or 0)
  profile.wins = profile.wins + 1
  profile.matches_played = profile.matches_played + 1

  -- Level formula
  profile.level = math.floor(profile.xp / 100) + 1

  -- Write back (SERVER AUTHORITATIVE)
  nk.storage_write({
    {
      collection = "profile",
      key = "player",
      user_id = user_id,
      value = profile,
      permission_read = 1,
      permission_write = 1 -- 🔒 WILL LOCK LATER
    }
  })

  nk.logger_info(
    string.format(
      "Rewards applied | user=%s | coins=%d | xp=%d | level=%d",
      user_id,
      profile.coins,
      profile.xp,
      profile.level
    )
  )

  return profile
end

-- ==============================
-- RPC (FOR TESTING ONLY)
-- ==============================
local function apply_match_rewards_rpc(context, payload)
  if not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local input = nk.json_decode(payload or "{}")

  if not input.user_id then
    return nk.json_encode({ error = "missing_user_id" }), 400
  end

  local profile = apply_rewards(input.user_id, {
    coins = input.coins or 0,
    xp = input.xp or 0
  })

  if not profile then
    return nk.json_encode({ error = "profile_not_found" }), 404
  end

  return nk.json_encode({
    success = true,
    profile = profile
  })
end

nk.register_rpc(apply_match_rewards_rpc, "apply_match_rewards")

-- EXPORT CORE FUNCTION FOR MATCH USE
return apply_rewards
