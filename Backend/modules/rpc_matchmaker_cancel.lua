local nk = require("nakama")

local function cancel(context, payload)
  -- 1. Security Check
  if not context.session_id then
    return nk.json_encode({ success = false, error = "no_session" })
  end

  -- 2. Remove from Matchmaker (Correct API)
  -- We use 'matchmaker_remove_session' which doesn't need a ticket
  local ok, err = pcall(nk.matchmaker_remove_session, context.session_id)

  if not ok then
    nk.logger_warn("Matchmaker remove failed: " .. tostring(err))
  end

  -- 3. Clean up Storage (Active Match)
  if context.user_id then
    nk.storage_delete({
      {
        collection = "matchmaking",
        key = "active_match",
        user_id = context.user_id
      }
    })
    nk.logger_info("Matchmaker Cancelled for user: " .. context.user_id)
  end

  return nk.json_encode({
    success = true,
    status = "cancelled"
  })
end

nk.register_rpc(cancel, "rpc_matchmaker_cancel")