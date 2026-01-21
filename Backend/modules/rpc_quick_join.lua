local nk = require("nakama")

local function rpc_quick_join(context, payload)
  -- 1. Security & Payload Check
  if not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local data = {}
  if payload and payload ~= "" then
    data = nk.json_decode(payload)
  end

  local mode = data.mode or "solo_1v1"
  nk.logger_info("RPC Quick Join: Mode is " .. mode)

  -- 2. Define Counts
  local max_count = ({
    solo_1v1 = 2,
    duo_3p   = 3,
    solo_4p  = 4,
    team_2v2 = 4
  })[mode] or 2

  local query = "+properties.mode:" .. mode

  -- 3. Define Properties
  local count_multiple = 1
  
  -- THIS IS THE FIX:
  -- We prepare the String Table (for text) and Numeric Table (for numbers)
  local string_props = { mode = mode }
  local numeric_props = {} 

  -- 4. Add to Matchmaker
  -- NOTICE THE ORDER: string_props (7), THEN numeric_props (8)
  nk.matchmaker_add(
    context.user_id,      -- 1
    context.session_id,   -- 2
    query,                -- 3
    max_count,            -- 4
    max_count,            -- 5
    count_multiple,       -- 6
    string_props,         -- 7 (Text goes here!)
    numeric_props         -- 8 (Numbers go here!)
  )

  return nk.json_encode({
    status = "searching",
    mode = mode,
    query = query
  })
end

nk.register_rpc(rpc_quick_join, "rpc_quick_join")
