local nk = require("nakama")

local function rpc_match_action(context, payload)
  if not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local data = nk.json_decode(payload)
  local match_id = data.match_id
  local action = data.action

  if not match_id or not action then
    return nk.json_encode({ error = "missing fields" }), 400
  end

  -- ✅ SEND SIGNAL INTO MATCH (CORRECT API)
nk.match_send(
  match_id,
  1, -- opcode
  nk.json_encode({
    action = action
  }),
  context.user_id
)



  return nk.json_encode({ status = "sent" })
end

nk.register_rpc(rpc_match_action, "match.action")


