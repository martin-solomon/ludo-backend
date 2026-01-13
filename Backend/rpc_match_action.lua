-- rpc_match_action.lua (TEST ONLY)
local nk = require("nakama")

local function rpc_match_action(context, payload)
  if not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local data = nk.json_decode(payload)
  if not data.match_id or not data.action then
    return nk.json_encode({ error = "missing fields" }), 400
  end

  -- send signal into authoritative match
  nk.match_signal(
    data.match_id,
    nk.json_encode({
      user_id = context.user_id,
      action = data.action
    })
  )

  return nk.json_encode({ status = "sent" })
end

nk.register_rpc(rpc_match_action, "match.action")




