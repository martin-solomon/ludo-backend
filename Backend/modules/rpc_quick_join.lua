local nk = require("nakama")

local function rpc_quick_join(context, payload)
  -- 1. Security Check
  if not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  -- 2. Parse Payload
  local data = {}
  if payload and payload ~= "" then
    data = nk.json_decode(payload)
  end

  local mode = data.mode or "solo_1v1"

  -- 3. Define Player Counts
  local max_count = ({
    solo_1v1 = 2,
    duo_3p   = 3,
    solo_4p  = 4,
    team_2v2 = 4
  })[mode] or 2

  -- 4. Create the Search Query
  -- This tells Nakama: "Only match me with people who have property 'mode' equal to my mode"
  local query = "+properties.mode:" .. mode

  -- 5. Add to Matchmaker (Corrected Arguments)
  nk.matchmaker_add(
    context.user_id,        -- 1. User ID
    context.session_id,     -- 2. Session ID
    query,                  -- 3. Query (MUST BE STRING)
    max_count,              -- 4. Min Count
    max_count,              -- 5. Max Count
    1,                      -- 6. Count Multiple (default 1)
    {},                     -- 7. Numeric Properties (empty)
    { mode = mode }         -- 8. String Properties (THIS is where your table goes)
  )

  return nk.json_encode({
    status = "searching",
    mode = mode,
    query = query
  })
end

nk.register_rpc(rpc_quick_join, "rpc_quick_join")
