local nk = require("nakama")

local function create_guest_profile_rpc(context, payload)
  -- Payload is ALWAYS a JSON string
  local input = {}
  if payload and payload ~= "" then
    input = nk.json_decode(payload)
  end

  local username = input.username or ""

  if not context or not context.user_id then
    return nk.json_encode({ error = "no_session" }), 401
  end

  local user_id = context.user_id

  local profile_value = {
    username = username,
    guest = true,
    coins = 100,
    xp = 0,
    level = 1,
    created_at = nk.time() * 1000
  }

  local profile_obj = {
    collection = "user_profiles",
    key = user_id,
    user_id = user_id,
    value = profile_value,
    permission_read = 2,
    permission_write = 0
  }

  nk.storage_write({ profile_obj })

  return nk.json_encode({
    success = true,
    user_id = user_id
  })
end

nk.register_rpc(create_guest_profile_rpc, "create_guest_profile")
