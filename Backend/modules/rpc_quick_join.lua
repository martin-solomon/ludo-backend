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

  -- 4. Create the Search Query
  local query = "+properties.mode:" .. mode

  -- 5. Add to Matchmaker (The SAFE Version)
  -- We removed the '1' (count_multiple) and 'nil' (numeric_props) to prevent the crash.
  nk.matchmaker_add(
    context.user_id,        -- 1. User ID
    context.session_id,     -- 2. Session ID
    query,                  -- 3. Query
    max_count,              -- 4. Min Count
    max_count,              -- 5. Max Count
    { mode = mode }         -- 6. String Properties (This contains your mode!)
  )

  return nk.json_encode({
    status = "searching",
    mode = mode,
    query = query
  })
end

nk.register_rpc(rpc_quick_join, "rpc_quick_join")
