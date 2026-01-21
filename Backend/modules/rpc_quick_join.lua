local nk = require("nakama")

local function rpc_quick_join(context, payload)
  -- 1. Security Check
  if not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  -- 2. Decode Payload
  local data = {}
  if payload and payload ~= "" then
    data = nk.json_decode(payload)
  end

  local mode = data.mode or "solo_1v1"
  nk.logger_info("RPC Quick Join: Mode is " .. mode)

  -- 3. Define Counts
  local max_count = 2
  if mode == "duo_3p" then max_count = 3 end
  if mode == "solo_4p" or mode == "team_2v2" then max_count = 4 end

  local query = "+properties.mode:" .. mode

  -- 4. Define Properties
  -- CRITICAL FIX: string_props MUST be passed to argument 7, NOT argument 8.
  local string_props = { mode = mode }
  local numeric_props = {} 

  -- 5. Add to Matchmaker (Wrapped in pcall for safety)
  local success, err = pcall(
    nk.matchmaker_add,
    context.user_id,      -- 1. User
    context.session_id,   -- 2. Session
    query,                -- 3. Query
    max_count,            -- 4. Min
    max_count,            -- 5. Max
    1,                    -- 6. Count Multiple
    string_props,         -- 7. String Props (TEXT GOES HERE)
    numeric_props         -- 8. Numeric Props (NUMBERS GO HERE)
  )

  if not success then
    nk.logger_error("Matchmaker Error: " .. tostring(err))
    -- FIX: Return error as single value
    return (nk.json_encode({ error = tostring(err) }))
  end

  -- 6. Success Response
  -- CRITICAL FIX: The ( ) around nk.json_encode discards the second return value.
  return (nk.json_encode({
    status = "searching",
    mode = mode,
    ticket = err
  }))
end

nk.register_rpc(rpc_quick_join, "rpc_quick_join")
