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

local function convert_rpc(context, payload)
  local input = parse_rpc_payload(payload)
  local username = input.username or ""
  local email = input.email or ""

  if not context or not context.user_id then
    return nk.json_encode({ error = "no_session" }), 401
  end

  local user_id = context.user_id

  -- Update profile
  local profile_value = {
    username = username,
    email = email,
    guest = false,
    converted_at = nk.time() * 1000
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
    nk.logger_error("convert_guest_to_permanent failed user_id=%s err=%s", tostring(user_id), tostring(err))
    return nk.json_encode({ error = "storage_write_failed" }), 500
  end

  -- 🧳 ENSURE INVENTORY SURVIVES CONVERSION
  inventory.ensure_inventory(user_id) -- ✅ ADDED

  return nk.json_encode({ success = true, user_id = user_id })
end

nk.register_rpc(convert_rpc, "convert_guest_to_permanent")
