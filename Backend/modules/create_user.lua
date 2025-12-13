local nk = require("nakama")

-- Helper: parse RPC payload which may be either a table or a quoted JSON string.
local function parse_rpc_payload(payload)
  if payload == nil then
    return {}
  end
  if type(payload) == "table" then
    return payload
  end
  if type(payload) == "string" then
    -- Try decode directly
    local ok, decoded = pcall(nk.json_decode, payload)
    if ok and type(decoded) == "table" then
      return decoded
    end
    -- payload might be a quoted JSON string: "\"{...}\""
    local inner = payload:match('^"(.*)"$')
    if inner then
      -- unescape quotes
      inner = inner:gsub('\\"', '"')
      local ok2, decoded2 = pcall(nk.json_decode, inner)
      if ok2 and type(decoded2) == "table" then
        return decoded2
      end
    end
  end
  return {}
end

local function create_user_rpc(context, payload)
  local input = parse_rpc_payload(payload)
  local username = input.username or ""
  local email = input.email or ""
  -- Basic validation
  if username == "" then
    return nk.json_encode({ error = "username_required" }), 400
  end

  -- Create account in Nakama (we expect the caller to be an authenticated session)
  -- If you want to create account server-side, you might use nk.account_create, but here
  -- we assume frontend already authenticated session and returned token.
  -- We'll create a storage record and return user_id.

  -- user_id: read from context if available, otherwise generate new? Prefer context.user_id.
  local user_id = nil
  if context and context.user_id then
    user_id = context.user_id
  else
    -- fallback: create a new account? For safety return error
    return nk.json_encode({ error = "no_session" }), 401
  end

  -- Build primary profile object keyed by user_id
  local profile_value = {
    username = username,
    email = email,
    guest = True,
    created_at = nk.time() * 1000
  }

  local profile_obj = {
    collection = "user_profiles",
    key = user_id,
    user_id = user_id,
    value = profile_value,
    permission_read = 2,  -- public read
    permission_write = 0  -- server-only writes
  }

  -- Write primary profile
  local ok, err = pcall(nk.storage_write, { profile_obj })
  if not ok then
    nk.logger_error("create_user: storage_write failed for user_id=%s err=%s", tostring(user_id), tostring(err))
    return nk.json_encode({ error = "storage_write_failed" }), 500
  end

  -- Write username index (lowercased) so Storage UI shows username
  if type(username) == "string" and username ~= "" then
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

    local ok2, err2 = pcall(nk.storage_write, { index_obj })
    if not ok2 then
      nk.logger_error("create_user: username index write failed key=%s err=%s", tostring(username_key), tostring(err2))
      -- not fatal; continue
    end
  end

  return nk.json_encode({ success = true, user_id = user_id })
end

nk.register_rpc(create_user_rpc, "create_user")

