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
  local max_count = ({
    solo_1v1 = 2,
    duo_3p   = 3,
    solo_4p  = 4,
    team_2v2 = 4
  })[mode] or 2

  local query = "+properties.mode:" .. mode

  -- 4. Define Properties
  -- Note: We REMOVED 'count_multiple'. It is not needed here.
  local string_props = { mode = mode }
  local numeric_props = {} 

  -- 5. Add to Matchmaker (The "7-Slot" Version)
  nk.matchmaker_add(
    context.user_id,      -- 1. User
    context.session_id,   -- 2. Session
    query,                -- 3. Query
    max_count,            -- 4. Min
    max_count,            -- 5. Max
    string_props,         -- 6. String Props (Table) -> CORRECT SLOT
    numeric_props         -- 7. Numeric Props (Table) -> CORRECT SLOT
  )

  return nk.json_encode({
    status = "searching",
    mode = mode,
    query = query
  })
end

nk.register_rpc(rpc_quick_join, "rpc_quick_join")
