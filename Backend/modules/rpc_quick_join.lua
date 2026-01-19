local nk = require("nakama")

local function rpc_quick_join(context, payload)
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

  -- IMPORTANT:
  -- Do NOT join here
  -- Just return match_id

  return nk.json_encode({
    match_id = input.match_id,
    action = "JOIN_USING_REST"
  })
end

nk.register_rpc(rpc_quick_join, "match_quick_join")
