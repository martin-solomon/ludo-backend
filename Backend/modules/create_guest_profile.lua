local nk = require("nakama")

local function create_guest_profile(context, payload)
  if not context or not context.user_id then
    return nk.json_encode({ error = "no_session" }), 401
  end

  local input = {}
  if payload and payload ~= "" then
    local ok, decoded = pcall(nk.json_decode, payload)
    if ok and type(decoded) == "table" then
      input = decoded
    end
  end

  local user_id = context.user_id
  local username = input.username or "Guest"

  nk.logger_info("Creating guest profile for user: " .. user_id)

  local profile = {
    user_id = user_id,
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

  return nk.json_encode({
    success = true,
    user_id = user_id
  })
end

nk.register_rpc(create_guest_profile, "create_guest_profile")
