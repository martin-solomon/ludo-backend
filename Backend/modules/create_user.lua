local nk = require("nakama")
local inventory = require("inventory_helper") -- ✅ ADDED

local function parse_rpc_payload(payload)
  if payload == nil then return {} end
  if type(payload) == "table" then return payload end
  if type(payload) == "string" then
    local ok, decoded = pcall(nk.json_decode, payload)
    if ok and type(decoded) == "table" then return decoded end
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

  -- 🔹 PROFILE INITIALIZATION
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
    nk.logger_error("create_user: storage_write failed user_id=%s err=%s", tostring(user_id), tostring(err))
    return nk.json_encode({ error = "storage_write_failed" }), 500
  end

  -- 🧳 INVENTORY INIT (NEW USERS WITHOUT GUEST)
  inventory.ensure_inventory(user_id) -- ✅ ADDED

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

  -- ✅ DAILY LOGIN TASK PROGRESS (ADDED)
  local daily_progress = require("daily_task_progress")
  daily_progress.increment(user_id, "login", 1)

  return nk.json_encode({ success = true, user_id = user_id })
end

nk.register_rpc(create_user_rpc, "create_user")
