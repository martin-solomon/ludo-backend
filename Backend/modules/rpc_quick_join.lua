local nk = require("nakama")

--[[
  MANUAL MATCHMAKING (RPC + STORAGE)
  - Replaces broken nk.matchmaker_add
  - Uses Storage as a "Waiting Room"
  - Handles Race Conditions with Retry Loop
  - Handles Entry Fee (50 Coins)
]]

local ENTRY_FEE = 50 -- Cost to play

local function rpc_quick_join(context, payload)
  -- 1. Parse Payload
  local data = {}
  if payload and payload ~= "" then
    local status, res = pcall(nk.json_decode, payload)
    if status then data = res end
  end

  local mode = data.mode or "solo" -- Default to solo

  -- ====================================================
  -- 💰 STEP 1: WALLET CHECK & DEDUCTION
  -- ====================================================
  local user_id = context.user_id
  local account = nk.account_get_id(user_id)
  local wallet = account.wallet or {}
  local coins = wallet.coins or 0

  if coins < ENTRY_FEE then
    return nk.json_encode({ 
      error = "insufficient_funds", 
      message = "You need " .. ENTRY_FEE .. " coins to play!" 
    })
  end

  -- Deduct the Entry Fee
  local status, err = pcall(nk.wallet_update, user_id, { coins = -ENTRY_FEE }, nil, { reason = "match_entry_fee" })
  if not status then
    nk.logger_error("Wallet update failed: " .. tostring(err))
    return nk.json_encode({ error = "wallet_error" })
  end
  -- ====================================================

  -- 2. Determine Requirements
  local needed_players = 2
  
  if mode == "clash" then needed_players = 3 end
  if mode == "rush"  then needed_players = 4 end
  if mode == "team"  then needed_players = 4 end

  -- 3. Define Storage Key
  -- Separate keys ensure Solo players don't join Team matches
  local storage_key = "waiting_room_" .. mode
  local collection = "matchmaking_manual"

  -- 4. THE RETRY LOOP (Safety against 1000 players)
  -- If a seat is stolen while we try to write, we loop back and try again.
  for attempt = 1, 5 do
    
    -- A. READ STORAGE
    local objects = nk.storage_read({
      { collection = collection, key = storage_key }
    })
    
    local room = nil
    local version = nil
    
    if objects and #objects > 0 then
      room = objects[1].value
      version = objects[1].version
    end

    -------------------------------------------------
    -- SCENARIO 1: ROOM EXISTS (Try to Join)
    -------------------------------------------------
    if room then
      -- Safety Check: Is room already full? (Should have been deleted, but just in case)
      if room.count >= needed_players then
        -- Force delete and retry loop to create new one
        pcall(nk.storage_delete, {{ collection = collection, key = storage_key, version = version }})
      
      else
        -- Join logic
        local new_count = room.count + 1
        local is_full = (new_count >= needed_players)
        
        if is_full then
          -- ROOM FULL: Delete the key so no one else joins
          local del_ops = {{ collection = collection, key = storage_key, version = version }}
          local ok, err = pcall(nk.storage_delete, del_ops)
          
          if ok then
            nk.logger_info("Match Full ("..mode.."): " .. room.match_id)
            return nk.json_encode({ status = "matched", match_id = room.match_id, mode = mode })
          else
             -- Delete failed (someone else updated it?). Retry.
             nk.logger_warn("Race condition on DELETE. Retrying...")
          end
          
        else
          -- ROOM OPEN: Increment count
          local write_ops = {{
            collection = collection, key = storage_key, version = version,
            value = { match_id = room.match_id, count = new_count, host_id = room.host_id },
            permission_read = 1, permission_write = 0
          }}
          local ok, err = pcall(nk.storage_write, write_ops)
          
          if ok then
            return nk.json_encode({ status = "matched", match_id = room.match_id, mode = mode })
          else
            -- Write failed (someone stole the seat). Retry.
            nk.logger_warn("Race condition on UPDATE. Retrying...")
          end
        end
      end

    -------------------------------------------------
    -- SCENARIO 2: NO ROOM (Create New)
    -------------------------------------------------
    else
      -- Create real match
      local match_id = nk.match_create("ludo_match", { mode = mode })
      
      -- Write to Storage (Queue Open)
      -- We use version="*" to fail if someone created a room 1ms ago
      local write_ops = {{
        collection = collection, key = storage_key, 
        value = { match_id = match_id, count = 1, host_id = context.user_id },
        permission_read = 1, permission_write = 0,
        version = "*" 
      }}
      
      local ok, err = pcall(nk.storage_write, write_ops)
      
      if ok then
        nk.logger_info("New Room Created ("..mode.."): " .. match_id)
        return nk.json_encode({ status = "created", match_id = match_id, mode = mode })
      else
        -- Write failed (someone just created a room). Retry to join theirs.
        nk.logger_warn("Race condition on CREATE. Retrying...")
      end
    end
    
    -- Small delay to let database settle before retry
    nk.run_jobs({ 
      function() return end 
    })
  end

  -- ====================================================
  -- 💰 SAFETY: REFUND IF SERVER FAILS
  -- If we reach here, we took money but failed to find a match. Refund it!
  -- ====================================================
  nk.wallet_update(user_id, { coins = ENTRY_FEE }, nil, { reason = "match_entry_refund" })
  return nk.json_encode({ error = "server_busy", message = "High traffic, please try again." }), 503
end

nk.register_rpc(rpc_quick_join, "rpc_quick_join")
