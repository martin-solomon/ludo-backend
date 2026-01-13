-- rpc_create_match.lua
-- Purpose: Create an authoritative Ludo match and return match_id

local nk = require("nakama")

local function rpc_create_match(context, payload)
  -- Ensure authenticated user
  if not context or not context.user_id then
    return nk.json_encode({
      error = "unauthorized"
    }), 401
  end

  -- Create authoritative match using ludo_match handler
  local match_id = nk.match_create("ludo_match", {
    creator = context.user_id
  })

  -- Return match_id to client
  return nk.json_encode({
    match_id = match_id
  })
end

-- Register RPC
nk.register_rpc(rpc_create_match, "rpc_create_match")
