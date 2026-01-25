local nk = require("nakama")
local inventory = require("inventory_helper")
local daily_login_rewards = require("daily_login_rewards") -- ✅ USE SAME FILE NAME
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

-------------------------------------------
--new for resetpassword
-------------------------------------------
local password = input.password or ""

if email == "" or password == "" then
  return nk.json_encode({ error = "email_and_password_required" }), 400
end

-- 🔑 THIS CREATES REAL EMAIL AUTH
nk.authenticate_email(email, password, true)
---------------------------------------------------
local function create_user_rpc(context, payload)
  if not context or not context.user_id then
    return nk.json_encode({ error = "no_session" }), 401
  end

  local input = parse_rpc_payload(payload)
  local username = input.username or ""
  local email = input.email or ""

  if username == "" then
    return nk.json_encode({ error = "username_required" }), 400
  end

  local user_id = context.user_id

  --------------------------------------------------
  -- 1️⃣ Account name (UNCHANGED)
  --------------------------------------------------
  nk.account_update_id(user_id, {
    username = username,
    display_name = username
  })

  --------------------------------------------------
  -- 2️⃣ Wallet init (UNCHANGED, working)
  --------------------------------------------------
  nk.wallet_update(
    user_id,
    { coins = 1000 },
    { reason = "initial_balance" },
    true
  )

  --------------------------------------------------
  -- 3️⃣ Profile metadata (UNCHANGED)
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
  -- 4️⃣ Inventory (UNCHANGED)
  --------------------------------------------------
  inventory.ensure_inventory(user_id)

  --------------------------------------------------
  -- 5️⃣ ✅ DAILY LOGIN STATE (ENSURE ONLY, NEVER RESET)
  --------------------------------------------------
  daily_login_rewards.ensure(user_id)

  return nk.json_encode({ success = true, user_id = user_id })
end

nk.register_rpc(create_user_rpc, "create_user")


