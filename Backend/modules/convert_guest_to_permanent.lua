local nk = require("nakama")
local inventory = require("inventory_helper")

local function parse_rpc_payload(payload)
  if payload == nil then return {} end
  if type(payload) == "table" then return payload end
  if type(payload) == "string" then
    local ok, decoded = pcall(nk.json_decode, payload)
    if ok and type(decoded) == "table" then return decoded end
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
    { collection = "user_profiles", key = user_id, user_id = user_id }
  })

  local profile = objects[1] and objects[1].value or {}
  if profile.converted then
    return nk.json_encode({ error = "already_converted" }), 409
  end

  local users = nk.users_get_username({ username })
  if users and #users > 0 then
    return nk.json_encode({ error = "username_taken" }), 409
  end

  nk.account_update_id(user_id, {
    email = email,
    password = password,
    username = username
  })

  nk.storage_write({
    {
      collection = "user_profiles",
      key = user_id,
      user_id = user_id,
      value = {
        username = username,
        email = email,
        guest = false,
        converted = true,
        converted_at = nk.time() * 1000
      },
      permission_read = 2,
      permission_write = 0
    }
  })

  inventory.ensure_inventory(user_id)

  -- ✅ DAILY LOGIN REWARD (ONLY ADDITION)
  local daily_rewards = require("daily_rewards_logic")
  daily_rewards.on_login(user_id)

  return nk.json_encode({ success = true, user_id = user_id })
end

nk.register_rpc(convert_guest_to_permanent, "convert_guest_to_permanent")
