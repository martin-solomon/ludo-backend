local nk = require("nakama")
local inventory = require("inventory_helper")
local avatar_catalog = require("avatar_catalog")


local function parse_rpc_payload(payload)
  if payload == nil then return {} end
  if type(payload) == "table" then return payload end
  if type(payload) == "string" then
    local ok, decoded = pcall(nk.json_decode, payload)
    if ok and type(decoded) == "table" then
      return decoded
    end
  end
  return {}
end

local function convert_guest_to_permanent(context, payload)
  if not context or not context.user_id then
    return nk.json_encode({ error = "no_session" }), 401
  end

  local user_id = context.user_id
  local input = parse_rpc_payload(payload)

  local email = input.email or ""
  local password = input.password or ""
  local username = input.username or ""

  if email == "" or password == "" or username == "" then
    return nk.json_encode({ error = "missing_params" }), 400
  end

  local objects = nk.storage_read({
    {
      collection = "user_profiles",
      key = user_id,
      user_id = user_id
    }
  })

  local existing_profile = objects[1] and objects[1].value or {}

  if existing_profile.converted == true then
    return nk.json_encode({ error = "already_converted" }), 409
  end
--------------------------------------------------------
  -- avatart change
  -- Ensure avatar ownership exists
--------------------------------------------------------
existing_profile.avatars = existing_profile.avatars or {
  avatar_catalog.DEFAULT.id
}

-- Ensure active avatar exists
existing_profile.active_avatar =
  existing_profile.active_avatar
  or avatar_catalog.DEFAULT
--------------------------------------------------------
  local users = nk.users_get_username({ username })
  if users and #users > 0 then
    return nk.json_encode({ error = "username_taken" }), 409
  end

  local ok, err = pcall(nk.account_update_id, user_id, {
    email = email,
    password = password,
    username = username
  })

  if not ok then
    nk.logger_error(
      "account_update_id failed user_id=%s err=%s",
      tostring(user_id),
      tostring(err)
    )
    return nk.json_encode({ error = "account_update_failed" }), 409
  end

  --------------------------------------------------------
  -- ✅ FIX: MERGE INTO EXISTING PROFILE (NOT OVERWRITE)
  --------------------------------------------------------
  existing_profile.username = username
  existing_profile.email = email
  existing_profile.guest = false
  existing_profile.converted = true
  existing_profile.converted_at = nk.time() * 1000
  --------------------------------------------------------

  local profile_obj = {
    collection = "user_profiles",
    key = user_id,
    user_id = user_id,
    value = profile_value,
    permission_read = 2,
    permission_write = 0
  }

  local write_ok, write_err = pcall(nk.storage_write, { profile_obj })
  if not write_ok then
    nk.logger_error(
      "storage_write failed user_id=%s err=%s",
      tostring(user_id),
      tostring(write_err)
    )
    return nk.json_encode({ error = "storage_write_failed" }), 500
  end

  inventory.ensure_inventory(user_id)

  return nk.json_encode({
    success = true,
    user_id = user_id
  })
end

nk.register_rpc(convert_guest_to_permanent, "convert_guest_to_permanent")


