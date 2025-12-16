local nk = require("nakama")

local function create_guest_profile_rpc(context, payload)
  nk.logger_info("create_guest_profile payload: %s", payload)

  local input = {}
  if payload and payload ~= "" then
    input = nk.json_decode(payload)
  end

  if not context or not context.user_id then
    return nk.json_encode({ error = "no_session" }), 401
  end

  local user_id = context.user_id
  local username = input.username or ""

  local profile = {
    username = username,
    guest = true,
    coins = 100,
    xp = 0,
    level = 1,
    created_at = nk.time() * 1000
  }

  nk.storage_write({
    {
      collection = "user_profiles",
      key = user_id,
      user_id = user_id,
      value = profile,
      permission_read = 2,
      permission_write = 0
    }
  })

  return nk.json_encode({ success = true, user_id = user_id }), 200
end

nk.register_rpc(create_guest_profile_rpc, "create_guest_profile")
