local nk = require("nakama")

local function rpc_match_join(context, payload)
  if not context.user_id then
    return nk.json_encode({ error = "NO_SESSION" })
  end

  local input = {}
  if payload and payload ~= "" then
    local ok, decoded = pcall(nk.json_decode, payload)
    if ok and type(decoded) == "table" then
      input = decoded
    end
  end

  if not input.match_id then
    return nk.json_encode({ error = "MATCH_ID_REQUIRED" })
  end

  nk.match_join(input.match_id, context.user_id, context.session_id)

  return nk.json_encode({
    status = "JOINED",
    match_id = input.match_id
  })
end

nk.register_rpc(rpc_match_join, "match_join")
