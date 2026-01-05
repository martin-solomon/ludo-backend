local nk = require("nakama")
local inventory = require("inventory_helper")

-- ---------------------------------------------------------
-- 🔧 Helper: Parse RPC Payload
-- ---------------------------------------------------------
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

-- ---------------------------------------------------------
-- 🔐 Convert Guest → Permanent Account
-- ---------------------------------------------------------
local function convert_guest_to_permanent(context, payload)
  -- 🔒 Session check
  if not context or not context.user_id then
    return nk.json_encode({ error = "no_session" }), 401
  end

  local user_id = context.user_id
  local input = parse_rpc_payload(payload)

  local email = input.email or ""
  local password = input.password or ""
  local username = input.username or ""

  -- 🔎 Validate input
  if email == "" or password == "" then
    return nk.json_encode({ error = "email_or_password_missing" }), 400
  end

  -- -----------------------------------------------------
  -- 🔑 LINK EMAIL + PASSWORD TO EXISTING USER (CRITICAL)
  -- -----------------------------------------------------
  local ok, err = pcall(nk.account_update_id, user_id, {
    email = email,
    password = password,
  })

  if not ok then
    nk.logger_error(
      "account_update_id failed user_id=%s err=%s",
      tostring(user_id),
      tostring(err)
    )
    return nk.json_encode({ error = "account_update_failed" }), 409
  end

  -- -----------------------------------------------------
  -- 📦 Update User Profile Storage
  -- -----------------------------------------------------
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
    permission_read = 2,  -- public read
    permission_write = 0  -- owner only
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

  -- -----------------------------------------------------
  -- 🧳 Ensure Inventory Survives Conversion
  -- -----------------------------------------------------
  inventory.ensure_inventory(user_id)

  -- -----------------------------------------------------
  -- ✅ SUCCESS
  -- -----------------------------------------------------
  return nk.json_encode({
    success = true,
    user_id = user_id
  })
end

-- ---------------------------------------------------------
-- 📌 Register RPC
-- ---------------------------------------------------------
nk.register_rpc(convert_guest_to_permanent, "convert_guest_to_permanent")
