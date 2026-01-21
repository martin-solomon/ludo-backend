local nk = require("nakama")

local function rpc_quick_join(context, payload)
  -- LOGGING START
  nk.logger_info("RPC Quick Join: Started by user " .. (context.user_id or "unknown"))

  if not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local data = {}
  if payload and payload ~= "" then
    data = nk.json_decode(payload)
  end

  local mode = data.mode or "solo_1v1"
  nk.logger_info("RPC Quick Join: Mode selected is " .. mode)

  local max_count = ({
    solo_1v1 = 2,
    duo_3p   = 3,
    solo_4p  = 4,
    team_2v2 = 4
  })[mode] or 2

  local query = "+properties.mode:" .. mode
  
  -- DEFINE PROPERTIES EXPLICITLY
  local count_multiple = 1        -- Arg 6: Must be Number
  local numeric_props = {}        -- Arg 7: Must be Table (Empty is fine)
  local string_props = {          -- Arg 8: Must be Table (Your Data)
    mode = mode
  }

  nk.logger_info("RPC Quick Join: Adding to matchmaker with query: " .. query)

  -- THE FIX: PASS ALL 8 ARGUMENTS EXPLICITLY
  nk.matchmaker_add(
    context.user_id,      -- 1. User
    context.session_id,   -- 2. Session
    query,                -- 3. Query String
    max_count,            -- 4. Min Players
    max_count,            -- 5. Max Players
    count_multiple,       -- 6. Count Multiple (NUMBER) -> CRITICAL FIX
    numeric_props,        -- 7. Numeric Props (TABLE)
    string_props          -- 8. String Props (TABLE) -> YOUR DATA GOES HERE
  )

  nk.logger_info("RPC Quick Join: Success!")

  return nk.json_encode({
    status = "searching",
    mode = mode,
    query = query
  })
end

nk.register_rpc(rpc_quick_join, "rpc_quick_join")
