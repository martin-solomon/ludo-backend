local nk = require("nakama")

local function rpc_quick_join(context, payload)
  -- 1. Authentication check (HTTP-safe)
  if not context.user_id then
    return nk.json_encode({
      error = "unauthorized",
      message = "User authentication required"
    })
  end

  -- 2. Decode payload
  local data = {}
  if payload and payload ~= "" then
    data = nk.json_decode(payload)
  end

  local mode = data.mode or "solo_1v1"
  nk.logger_info("RPC Quick Join: " .. context.user_id .. " → " .. mode)

  -- 3. Player count
  local max_count = 2
  if mode == "duo_3p" then max_count = 3 end
  if mode == "solo_4p" or mode == "team_2v2" then max_count = 4 end

  -- 4. Matchmaker query (CORRECT)
  local query = "+properties.mode:" .. mode
  local string_props = { mode = mode }

  -- 5. Call matchmaker (DO NOT RETURN ITS RESULT)
  local ok, err = pcall(
    nk.matchmaker_add,
    context.user_id,
    context.session_id,
    query,
    max_count,
    max_count,
    string_props,
    nil
  )

  if not ok then
    nk.logger_error("Matchmaker failed: " .. tostring(err))
    return nk.json_encode({
      error = "matchmaker_failed",
      message = "Unable to join matchmaking"
    })
  end

  -- 6. ✅ VALID RPC RETURN (STRING ONLY)
  return nk.json_encode({
    status = "searching",
    mode = mode
  })
end

nk.register_rpc(rpc_quick_join, "rpc_quick_join")
