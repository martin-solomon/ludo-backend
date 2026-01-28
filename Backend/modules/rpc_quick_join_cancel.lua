local nk = require("nakama")

local function rpc_quick_join_cancel(context, payload)
  if not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local data = {}
  if payload and payload ~= "" then
     pcall(function() data = nk.json_decode(payload) end)
  end

  local mode = data.mode or "solo"
  local storage_key = "waiting_room_" .. mode
  local collection = "matchmaking_manual"

  -- 1. Read the waiting room
  local objects = nk.storage_read({
    { collection = collection, key = storage_key }
  })

  if not objects or #objects == 0 then
    return nk.json_encode({ status = "already_gone" })
  end

  local room = objects[1].value
  local version = objects[1].version

  -- 2. SECURITY CHECK
  -- Only the Host (Creator) should be able to delete the room via RPC.
  -- If I am just a joiner, I just disconnect from socket (handled by match_leave).
  if room.host_id == context.user_id then
    
    -- Delete the key
    local ok, err = pcall(nk.storage_delete, {{ 
      collection = collection, key = storage_key, version = version 
    }})
    
    if ok then
      nk.logger_info("Queue Cancelled by Host: " .. context.user_id)
      return nk.json_encode({ status = "cancelled" })
    end
  end

  return nk.json_encode({ status = "ignored" })
end

nk.register_rpc(rpc_quick_join_cancel, "rpc_quick_join_cancel")