local nk = require("nakama")
local inventory = require("inventory_helper")
local daily_login_state = require("daily_login_rewards")

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

  if username == "" then
    return nk.json_encode({ error = "username_required" }), 400
  end

  local user_id = context.user_id

  -- 1️⃣ Account name
  nk.account_update_id(user_id, {
    username = username,
    display_name = username
  })

  -- 2️⃣ Wallet init (one-time via authoritative replace)
  nk.wallet_update(
    user_id,
    { coins = 1000 },
    { reason = "initial_balance" },
    true
  )

  -- 3️⃣ Profile metadata
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
        created_at = nk.time() * 1000
      },
      permission_read = 2,
      permission_write = 0
    }
  })

  -- 4️⃣ Inventory
  inventory.ensure_inventory(user_id)

  -- 5️⃣ ✅ DAILY LOGIN STATE (ENSURE ONLY, NEVER RESET)
  daily_login_state.ensure(user_id)

  return nk.json_encode({ success = true, user_id = user_id })
end

nk.register_rpc(create_user_rpc, "create_user")
