local nk = require("nakama")
local inventory = require("inventory_helper")
local daily_login_rewards = require("daily_login_rewards")
local avatar_catalog = require("avatar_catalog")
local utils = require("utils_rpc") -- ✅ USE SHARED SAFE PARSER

--------------------------------------------------
-- CREATE USER RPC
--------------------------------------------------

local function create_user_rpc(context, payload)
  -- 0️⃣ Session validation
  if not context or not context.user_id then
    return nk.json_encode({ error = "no_session" }), 401
  end

  -- 1️⃣ SAFE payload parsing (🔥 FIX)
  local input, err = utils.parse_rpc_payload(payload)
  if not input then
    return nk.json_encode({
      error = "invalid_payload",
      message = err or "Payload must be a JSON object"
    }), 400
  end

  local username = input.username or ""
  local email = input.email or ""

  if username == "" then
    return nk.json_encode({ error = "username_required" }), 400
  end

  local user_id = context.user_id

  --------------------------------------------------
  -- 2️⃣ Account update
  --------------------------------------------------
  nk.account_update_id(user_id, {
    username = username,
    display_name = username
  })

  --------------------------------------------------
  -- 3️⃣ Wallet initialization (ONE TIME)
  --------------------------------------------------
  nk.wallet_update(
    user_id,
    { coins = 1000 },
    { reason = "initial_balance" },
    true -- authoritative
  )

  --------------------------------------------------
  -- 4️⃣ Profile metadata
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
      permission_read = 2,  -- public read
      permission_write = 0  -- server only
    }
  })

  --------------------------------------------------
  -- 5️⃣ Inventory initialization
  --------------------------------------------------
  inventory.ensure_inventory(user_id)

  --------------------------------------------------
  -- 6️⃣ Daily login state
  --------------------------------------------------
  daily_login_rewards.ensure(user_id)

  --------------------------------------------------
  -- 7️⃣ Success response
  --------------------------------------------------
  return nk.json_encode({
    success = true,
    user_id = user_id
  })
end

--------------------------------------------------
-- RPC REGISTRATION
--------------------------------------------------
nk.register_rpc(create_user_rpc, "create_user")
