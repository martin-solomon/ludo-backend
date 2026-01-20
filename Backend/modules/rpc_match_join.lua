local nk = require("nakama")

local function rpc_match_join(context, payload)
  if not context.user_id then
    return nk.json_encode({ error = "NO_SESSION" })
  end

  local input = {}
  if payload and payload ~= "" then
    local ok, decoded = pcall(nk.json_decode, payload)
    if ok and decoded then
      input = decoded
    end
  end

  if not input.match_id then
    return nk.json_encode({ error = "MATCH_ID_REQUIRED" })
  end

  -- Just validate match exists
  local matches = nk.match_list(1, true, nil, nil, nil, { match_id = input.match_id })
  if not matches or #matches == 0 then
    return nk.json_encode({ error = "MATCH_NOT_FOUND" })
  end

  -- DO NOT JOIN HERE
  return nk.json_encode({
    status = "OK",
    match_id = input.match_id
  })
end

nk.register_rpc(rpc_match_join, "match_join")
