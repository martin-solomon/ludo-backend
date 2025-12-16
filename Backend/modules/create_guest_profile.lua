local nk = require("nakama")

local function create_guest_profile_rpc(context, payload)
  if not context or not context.user_id then
    return nk.json_encode({ error = "no_session" }), 401
  end

  -- HTTP RPC payload is ALWAYS a string
  local input = {}
  if payload ~= nil and payload ~= "" then
    local ok, decoded = pcall(nk.json_decode, payload)
    if ok and type(decoded) == "table" then
      input = decoded
    end
  end

  local username = input.username or ""
  local email = input.email or ""
  local user_id = context.user_id

  local profile = {
    username = username,
    email = email,
    guest = true,
    coins = 100,
    xp = 0,
    level = 1,
    created_at = nk.time() * 1000
  }

  local obj = {
    collection = "user_profiles",
    key = user_id,
    user_id = user_id,
    value = profile,
    permission_read = 2,
    permission_write = 0
  }

  local ok, err = pcall(nk.storage_write, { obj })
  if not ok then
    nk.logger_error("create_guest_profile storage failed: %s", err)
    return nk.json_encode({ error = "storage_write_failed" }), 500
  end

  return nk.json_encode({
    success = true,
    user_id = user_id
  })
end

nk.register_rpc(create_guest_profile_rpc, "create_guest_profile")
