local nk = require("nakama")

-- [[
-- RPC: admin_delete_account
-- Called by the external Python script (S2S) to delete a user.
-- CRITICAL: This must only be callable via Server-to-Server authentication.
-- ]]
local function admin_delete_account(context, payload)
  -- SECURITY CHECK:
  -- If context.user_id exists, it means a regular user is calling this.
  -- We MUST reject the call. S2S calls have no user_id in the context.
  if context.user_id then
    nk.logger_warn("SECURITY ALERT: User " .. context.user_id .. " attempted to call admin_delete_account RPC.")
    return nk.json_encode({ success = false, error = "Unauthorized" })
  end

  local input = nk.json_decode(payload)
  local user_id_to_delete = input.user_id

  if not user_id_to_delete or user_id_to_delete == "" then
    return nk.json_encode({ success = false, error = "user_id is required in payload" })
  end

  nk.logger_info("Admin RPC initiated deletion for user: " .. user_id_to_delete)

  -- Perform the deletion safely.
  local ok, err = pcall(nk.account_delete, user_id_to_delete, true) -- true = record analytics event
  if not ok then
    nk.logger_error("Failed to delete account " .. user_id_to_delete .. ": " .. tostring(err))
    return nk.json_encode({ success = false, error = tostring(err) })
  end

  -- The user's storage is automatically deleted with the account.
  return nk.json_encode({ success = true, user_id = user_id_to_delete })
end

-- Register as a S2S RPC.
nk.register_rpc(admin_delete_account, "admin_delete_account")