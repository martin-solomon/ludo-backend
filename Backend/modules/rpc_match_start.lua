-- rpc_match_start.lua
local nk = require("nakama")

local function match_start(context, payload)
  -- 1. Authentication check
  if not context.user_id then
    return nk.json_encode({ error = "not_authenticated" })
  end

  -- 2. Read matchmaking result from storage
  -- This must be written when match is created in main.lua
  local records = nk.storage_read({
    {
      collection = "matchmaking",
      key = "active_match",
      user_id = context.user_id
    }
  })

  -- 3. If no match yet → still waiting
  if not records or #records == 0 then
    return nk.json_encode({
      status = "waiting"
    })
  end

  local match_id = records[1].value.matchId
  if not match_id then
    return nk.json_encode({
      status = "waiting"
    })
  end

  -- 4. Verify match still exists (safety)
  local ok, match = pcall(nk.match_get, match_id)
  if not ok or not match then
    return nk.json_encode({
      status = "waiting"
    })
  end

  -- 5. Match is ready
  return nk.json_encode({
    status = "ready",
    matchId = match_id
  })
end

nk.register_rpc(match_start, "rpc_match_start")
