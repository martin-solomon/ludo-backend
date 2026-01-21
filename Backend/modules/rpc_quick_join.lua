local nk = require("nakama")

local function rpc_quick_join(context, payload)
  -- STEP 1: STRICT SECURITY CHECK
  -- The Matchmaker REQUIRED a Session ID. If this is nil, it crashes with "non-function object".
  if not context.user_id then
    return nk.json_encode({ error = "Missing User ID" }), 401
  end
  if not context.session_id then
    -- This is likely the cause of your 500 error!
    return nk.json_encode({ error = "Missing Session ID. Are you using a User Token?" }), 400
  end

  -- STEP 2: PREPARE DATA
  local data = {}
  if payload and payload ~= "" then
    data = nk.json_decode(payload)
  end
  local mode = data.mode or "solo_1v1"
  
  -- Define Player Counts
  local max_count = 2
  if mode == "duo_3p" then max_count = 3 end
  if mode == "solo_4p" or mode == "team_2v2" then max_count = 4 end

  local query = "+properties.mode:" .. mode
  local string_props = { mode = mode }
  local numeric_props = {}

  nk.logger_info("Attempting to join match: " .. mode .. " | Query: " .. query)

  -- STEP 3: THE SAFETY NET (PCALL)
  -- We wrap the matchmaker call. If it crashes, 'success' will be false and 'err' will tell us why.
  local success, err = pcall(
    nk.matchmaker_add,
    context.user_id,      -- Arg 1: String
    context.session_id,   -- Arg 2: String
    query,                -- Arg 3: String
    max_count,            -- Arg 4: Number
    max_count,            -- Arg 5: Number
    1,                    -- Arg 6: Number (Count Multiple)
    string_props,         -- Arg 7: Table (String Props)
    numeric_props         -- Arg 8: Table (Numeric Props)
  )

  -- STEP 4: HANDLE RESULT
  if not success then
    nk.logger_error("Matchmaker CRASHED: " .. tostring(err))
    return nk.json_encode({ 
      error = "Internal Matchmaker Error", 
      message = tostring(err),
      debug_session = context.session_id
    }), 500
  end

  return nk.json_encode({
    status = "searching",
    mode = mode,
    ticket = err -- When successful, 'err' contains the ticket ID
  })
end

nk.register_rpc(rpc_quick_join, "rpc_quick_join")
