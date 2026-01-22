local nk = require("nakama")

-- 🚑 SELF-HEALING HELPER
-- If the server broke matchmaker_add, this function forces a fresh reload to fix it.
local function get_safe_matchmaker()
    -- 1. If it exists, return it immediately (Fast Path)
    if nk.matchmaker_add then 
        return nk.matchmaker_add 
    end

    -- 2. If missing, attempt emergency repair
    nk.logger_warn("⚠️ EMERGENCY: nk.matchmaker_add is missing. Attempting Hot-Fix...")

    -- Force clear the cached module
    package.loaded["nakama"] = nil 
    
    -- Require it again to get a fresh, clean copy
    local fresh_nk = require("nakama")

    if fresh_nk and fresh_nk.matchmaker_add then
        -- Repair the global reference for this file
        nk = fresh_nk 
        nk.logger_info("✅ SUCCESS: nk.matchmaker_add restored via Hot-Fix!")
        return fresh_nk.matchmaker_add
    else
        nk.logger_error("❌ CRITICAL: Hot-Fix failed. matchmaker_add is seemingly gone from the server binary.")
        return nil
    end
end

local function rpc_quick_join(context, payload)
  -- 1. Get the Matchmaker Function (Healing if necessary)
  local matchmaker_add_fn = get_safe_matchmaker()
  
  if not matchmaker_add_fn then
      return nk.json_encode({
          error = "server_error",
          message = "Matchmaking service unavailable"
      })
  end

  -- 2. Authentication check
  if not context.user_id then
    return nk.json_encode({
      error = "unauthorized",
      message = "User authentication required"
    })
  end

  -- 3. Decode payload
  local data = {}
  if payload and payload ~= "" then
    data = nk.json_decode(payload)
  end

  local mode = data.mode or "solo_1v1"
  nk.logger_info("RPC Quick Join: " .. context.user_id .. " -> " .. mode)

  -- 4. Player count logic
  local max_count = 2
  if mode == "duo_3p" then max_count = 3 end
  if mode == "solo_4p" or mode == "team_2v2" then max_count = 4 end

  -- 5. Matchmaker query
  local query = "+properties.mode:" .. mode
  local string_props = { mode = mode }
  local numeric_props = {} 

  -- 6. Call matchmaker (Using the safe function)
  local ok, err = pcall(
    matchmaker_add_fn, -- ✅ Using our repaired function variable
    context.user_id,
    query,
    max_count,
    max_count,
    string_props,
    numeric_props
  )

  if not ok then
    nk.logger_error("Matchmaker CRASHED: " .. tostring(err))
    return nk.json_encode({
      error = "matchmaker_failed",
      message = "Unable to join matchmaking"
    })
  end

  -- 7. Success Return
  return nk.json_encode({
    status = "searching",
    mode = mode
  })
end

nk.register_rpc(rpc_quick_join, "rpc_quick_join")
