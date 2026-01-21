local nk = require("nakama")

local function rpc_quick_join(context, payload)
  -- 1. Security Check
  if not context.user_id then
    return (nk.json_encode({ error = "unauthorized" }))
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
  local string_props = { mode = mode }
  local numeric_props = {} 

  -- 5. Add to Matchmaker (7-Argument Version)
  -- We REMOVED the number '1' (count_multiple). It does not exist in your Nakama version.
  local success, err = pcall(
    nk.matchmaker_add,
    context.user_id,      -- 1. User
    context.session_id,   -- 2. Session
    query,                -- 3. Query
    max_count,            -- 4. Min
    max_count,            -- 5. Max
    string_props,         -- 6. String Props (Table) -> CORRECT SLOT
    numeric_props         -- 7. Numeric Props (Table) -> CORRECT SLOT
  )

  if not success then
    nk.logger_error("Matchmaker Error: " .. tostring(err))
    -- Return error safely
    return (nk.json_encode({ error = tostring(err) }))
  end

  -- 6. Success Response
  return (nk.json_encode({
    status = "searching",
    mode = mode,
    ticket = err
  }))
end

nk.register_rpc(rpc_quick_join, "rpc_quick_join")
