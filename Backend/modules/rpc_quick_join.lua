local nk = require("nakama")

local function rpc_quick_join(context, payload)
  -- 1. Authentication check
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
  nk.logger_info("RPC Quick Join: " .. context.user_id .. " -> " .. mode)

  -- 3. Player count
  local max_count = 2
  if mode == "duo_3p" then max_count = 3 end
  if mode == "solo_4p" or mode == "team_2v2" then max_count = 4 end

  -- 4. Matchmaker query
  local query = "+properties.mode:" .. mode
  local string_props = { mode = mode }
  local numeric_props = {} 

  -- 5. Call matchmaker (With Version Fallback)
  local ok, err

  -- CHECK: Does the standard function exist?
  if nk.matchmaker_add then
    -- ✅ Use standard Nakama 3.x function
    ok, err = pcall(
      nk.matchmaker_add,
      context.user_id,
      query,
      max_count,
      max_count,
      string_props,
      numeric_props
    )
  else
    -- ⚠️ FALLBACK: Try older Nakama function name
    nk.logger_warn("nk.matchmaker_add missing. Trying nk.matchmaker_add_join...")
    if nk.matchmaker_add_join then
        ok, err = pcall(
          nk.matchmaker_add_join, -- Older function name
          context.user_id,
          query,
          max_count,
          max_count,
          string_props,
          numeric_props
        )
    else
        ok = false
        err = "CRITICAL: No matchmaker function found on this server version."
    end
  end

  if not ok then
    nk.logger_error("Matchmaker CRASHED: " .. tostring(err))
    return nk.json_encode({
      error = "matchmaker_failed",
      message = "Unable to join matchmaking"
    })
  end

  -- 6. Success
  return nk.json_encode({
    status = "searching",
    mode = mode
  })
end

nk.register_rpc(rpc_quick_join, "rpc_quick_join")
