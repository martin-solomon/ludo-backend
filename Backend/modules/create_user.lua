local nk = require("nakama")
local inventory = require("inventory_helper") -- ✅ ADD THIS

local function parse_rpc_payload(payload)
  if payload == nil then return {} end
  if type(payload) == "table" then return payload end
  if type(payload) == "string" then
    local ok, decoded = pcall(nk.json_decode, payload)
    if ok and type(decoded) == "table" then return decoded end
    local inner = payload:match('^"(.*)"$')
    if inner then
      inner = inner:gsub('\\"', '"')
      local ok2, decoded2 = pcall(nk.json_decode, inner)
      if ok2 and type(decoded2) == "table" then return decoded2 end
    end
  end
  return {}
end

local function create_user_rpc(context, payload)
  local input = parse_rpc_payload(payload)
  local username = input.username or ""
  local email = input.email or ""

  if username == "" then
    return nk.json_encode({ error = "username_required" }), 400
  end

  if not context or not context.user_id then
    return nk.json_encode({ error = "no_session" }), 401
  end

  local user_id = context.user_id

  -- 🔐 ENSURE INVENTORY EXISTS (EMAIL / GOOGLE USERS)
  inventory.create_inventory_if_missing(user_id) -- ✅ ADD THIS

  -- 🔹 PROFILE INITIALIZATION (UNCHANGED)
  local profile_value = {
    username = username,
    email = email,
    guest = false,

    coins = 1000,
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

  local ok, err = pcall(nk.storage_write, { profile_obj })
  if not ok then
    nk.logger_error(
      "create_user: storage_write failed user_id=%s err=%s",
      tostring(user_id),
      tostring(err)
    )
    return nk.json_encode({ error = "storage_write_failed" }), 500
  end

  -- Username index (UNCHANGED)
  local username_key = string.lower(username)
  local index_obj = {
    collection = "user_profiles",
    key = username_key,
    user_id = user_id,
    value = {
      username = username,
      user_id = user_id,
      guest = false
    },
    permission_read = 2,
    permission_write = 0
  }

  pcall(nk.storage_write, { index_obj })

  return nk.json_encode({ success = true, user_id = user_id })
end

nk.register_rpc(create_user_rpc, "create_user")
