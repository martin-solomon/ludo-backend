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

  return nk.json_encode(objects[1].value)
end

nk.register_rpc(rpc_get_profile, "get_profile")
