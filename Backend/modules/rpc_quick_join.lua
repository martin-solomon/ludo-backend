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

  -- 3. Get Player Counts
  local max_count = ({
    solo_1v1 = 2,
    duo_3p   = 3,
    solo_4p  = 4,
    team_2v2 = 4
  })[mode] or 2

  -- 4. Create the Search Query (This MUST be a String)
  -- We search for matches that have the same 'mode' property
  local query = "+properties.mode:" .. mode

  -- 5. Add to Matchmaker
  nk.matchmaker_add(
    context.user_id,        -- 1. Who (User ID)
    context.session_id,     -- 2. Session
    query,                  -- 3. Query (FIXED: Now it is a String!)
    max_count,              -- 4. Min Players
    max_count,              -- 5. Max Players
    1,                      -- 6. Count Multiple
    nil,                    -- 7. Numeric Properties (None)
    { mode = mode }         -- 8. String Properties (FIXED: Table goes here!)
  )

  return nk.json_encode({
    status = "searching",
    mode = mode,
    query = query
  })
end

nk.register_rpc(rpc_quick_join, "rpc_quick_join")
