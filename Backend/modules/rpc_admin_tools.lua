-- rpc_admin_tools.lua
local nk = require("nakama")

-- 🔒 ADMIN USER IDS (FILL THIS)
local ADMIN_USERS = {
  -- ["user_id_here"] = true,
}

local function is_admin(context)
  return context and context.user_id and ADMIN_USERS[context.user_id] == true
end

------------------------------------------------
-- 🔴 RESET PLAYER PROFILE
------------------------------------------------
local function admin_reset_profile(context, payload)
  if not is_admin(context) then
    return nk.json_encode({ error = "forbidden" }), 403
  end

  local input = nk.json_decode(payload or "{}")
  local user_id = input.user_id
  if not user_id then
    return nk.json_encode({ error = "user_id_required" }), 400
  end

  local profile = {
    coins = 0,
    xp = 0,
    wins = 0,
    matches_played = 0,
    level = 1
  }

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

  return nk.json_encode({ success = true, action = "profile_reset" })
end

------------------------------------------------
-- 🔴 CLEAR MATCH REWARD LOCK
------------------------------------------------
local function admin_clear_match_reward(context, payload)
  if not is_admin(context) then
    return nk.json_encode({ error = "forbidden" }), 403
  end

  local input = nk.json_decode(payload or "{}")
  local user_id = input.user_id
  local match_id = input.match_id

  if not user_id or not match_id then
    return nk.json_encode({ error = "missing_params" }), 400
  end

  nk.storage_delete({
    {
      collection = "match_rewards",
      key = match_id,
      user_id = user_id
    }
  })

  return nk.json_encode({
    success = true,
    action = "reward_lock_cleared",
    match_id = match_id
  })
end

------------------------------------------------
-- 🟡 FORCE FINISH MATCH (SIGNAL ONLY)
------------------------------------------------
local function admin_force_finish_match(context, payload)
  if not is_admin(context) then
    return nk.json_encode({ error = "forbidden" }), 403
  end

  local input = nk.json_decode(payload or "{}")
  local match_id = input.match_id
  if not match_id then
    return nk.json_encode({ error = "match_id_required" }), 400
  end

  -- This does not kill match process,
  -- but allows you to track forced finishes externally
  nk.logger_warn("ADMIN force finish requested for match_id=" .. match_id)

  return nk.json_encode({
    success = true,
    action = "force_finish_requested",
    match_id = match_id
  })
end

------------------------------------------------
-- REGISTER RPCs
------------------------------------------------
nk.register_rpc(admin_reset_profile, "admin.reset_profile")
nk.register_rpc(admin_clear_match_reward, "admin.clear_match_reward")
nk.register_rpc(admin_force_finish_match, "admin.force_finish_match")
