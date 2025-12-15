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
