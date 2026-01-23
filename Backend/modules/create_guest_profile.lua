-- create_guest_profile.lua (PRODUCTION SAFE)
local nk = require("nakama")
local daily_login_rewards = require("daily_login_rewards") -- ✅ SAME FILE
local avatar_catalog = require("avatar_catalog")
local STARTING_COINS = 1000

local function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function create_guest_profile(context, payload)
  if not context or not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local data = {}
  if payload and payload ~= "" then
    local ok, decoded = pcall(nk.json_decode, payload)
    if ok and type(decoded) == "table" then
      data = decoded
    end
  end

  local username = trim(data.username or "")
  if username == "" then
    return nk.json_encode({ error = "username_required" }), 400
  end

  local user_id = context.user_id

  --------------------------------------------------
  -- 1️⃣ Update Nakama account (UNCHANGED)
  --------------------------------------------------
  nk.account_update_id(user_id, {
    username = username,
    display_name = username
  })

  --------------------------------------------------
  -- 2️⃣ One-time wallet init (UNCHANGED)
  --------------------------------------------------
  local init_flag = nk.storage_read({
    {
      collection = "user_init",
      key = "state",
      user_id = user_id
    }
  })

  local already_initialized = init_flag and #init_flag > 0

  if not already_initialized then
    nk.wallet_update(
      user_id,
      { coins = STARTING_COINS },
      { reason = "initial_grant" },
      true
    )

    nk.storage_write({
      {
        collection = "user_init",
        key = "state",
        user_id = user_id,
        value = {
          initialized = true,
          at = os.time()
        },
        permission_read = 0,
        permission_write = 0
      }
    })
  end

  --------------------------------------------------
  -- 3️⃣ Profile storage (UNCHANGED)
  --------------------------------------------------
  nk.storage_write({
    {
      collection = "user_profiles",
      key = "profile",
      user_id = user_id,
      value = {
        username = username,
        display_name = username,
        guest = true,
        avatars = { avatar_catalog.DEFAULT.id },
        active_avatar = avatar_catalog.DEFAULT,
        created_at = os.time()
      },
      permission_read = 2,
      permission_write = 0
    }
  })

  --------------------------------------------------
  -- 4️⃣ ✅ DAILY LOGIN STATE (ENSURE ONLY)
  --------------------------------------------------
  daily_login_rewards.ensure(user_id)

  return nk.json_encode({
    success = true,
    user_id = user_id,
    username = username
  })
end

nk.register_rpc(create_guest_profile, "create_guest_profile")

