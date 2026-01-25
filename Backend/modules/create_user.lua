local nk = require("nakama")
local inventory = require("inventory_helper")
local daily_login_rewards = require("daily_login_rewards")
local avatar_catalog = require("avatar_catalog")

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
  if not context or not context.user_id then
    return nk.json_encode({ error = "no_session" }), 401
  end

  local input = parse_rpc_payload(payload)

  local username = input.username or ""
  local email = input.email or ""
  local password = input.password or ""

  --------------------------------------------------
  -- 🔐 REQUIRED VALIDATION
  --------------------------------------------------
  if username == "" then
    return nk.json_encode({ error = "username_required" }), 400
  end

  if email == "" or password == "" then
    return nk.json_encode({ error = "email_and_password_required" }), 400
  end

  --------------------------------------------------
  -- 🔑 CREATE REAL EMAIL + PASSWORD AUTH (CRITICAL)
  --------------------------------------------------
  nk.authenticate_email(email, password, true)

  local user_id = context.user_id

  --------------------------------------------------
  -- 1️⃣ Account name
  --------------------------------------------------
  nk.account_update_id(user_id, {
    username = username,
    display_name = username
  })

  --------------------------------------------------
  -- 2️⃣ Wallet init
  --------------------------------------------------
  nk.wallet_update(
    user_id,
    { coins = 1000 },
    { reason = "initial_balance" },
    true
  )

  --------------------------------------------------
  -- 3️⃣ Profile metadata
  --------------------------------------------------
  nk.storage_write({
    {
      collection = "user_profiles",
      key = user_id,
      user_id = user_id,
      value = {
        username = username,
        email = email,
        guest = false,
        xp = 0,
        level = 1,
        avatars = { avatar_catalog.DEFAULT.id },
        active_avatar = avatar_catalog.DEFAULT,
        created_at = nk.time() * 1000
      },
      permission_read = 2,
      permission_write = 0
    }
  })

  --------------------------------------------------
  -- 4️⃣ Inventory
  --------------------------------------------------
  inventory.ensure_inventory(user_id)

  --------------------------------------------------
  -- 5️⃣ Daily login state
  --------------------------------------------------
  daily_login_rewards.ensure(user_id)

  return nk.json_encode({ success = true, user_id = user_id })
end

nk.register_rpc(create_user_rpc, "create_user")
