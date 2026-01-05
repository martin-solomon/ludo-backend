local nk = require("nakama")

local function rpc_get_profile(context, payload)
  if not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local objects = nk.storage_read({
    {
      collection = "profile",
      key = "player",
      user_id = context.user_id
    }
  })

  if not objects or #objects == 0 then
    return nk.json_encode({ error = "profile_not_found" }), 404
  end

  local p = objects[1].value

  return nk.json_encode({
    username = p.username,
    level = p.level,
    xp = p.xp,
    coins = p.coins,
    wins = p.wins,
    losses = p.losses
  })
end

nk.register_rpc(rpc_get_profile, "get_profile")
