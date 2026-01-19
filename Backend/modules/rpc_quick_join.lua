local nk = require("nakama")

local function rpc_quick_join(context, payload)
  if not context.user_id then
    return nk.json_encode({ error = "NO_SESSION" }), 401
  end

  local input = {}
  if payload and payload ~= "" then
    local ok, decoded = pcall(nk.json_decode, payload)
    if ok and type(decoded) == "table" then
      input = decoded
    end
  end

  if not input.match_id then
    return nk.json_encode({ error = "MATCH_ID_REQUIRED" }), 400
  end

  -- IMPORTANT:
  -- DO NOT join match here
  -- Just return match_id
  return nk.json_encode({
    match_id = input.match_id
  }), 200
end

nk.register_rpc(rpc_quick_join, "match_quick_join")
