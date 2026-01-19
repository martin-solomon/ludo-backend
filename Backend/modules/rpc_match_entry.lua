-- rpc_match_entry.lua
-- FINAL, SAFE, MANUAL MATCH ENTRY (NO MATCHMAKER, NO SIGNALS)

local nk = require("nakama")

local function rpc_match_entry(context, payload)
  -- 1. Validate session
  if not context or not context.user_id then
    return nk.json_encode({ error = "NO_SESSION" }), 401
  end

  -- 2. Parse payload
  local input = {}
  if payload and payload ~= "" then
    local ok, decoded = pcall(nk.json_decode, payload)
    if ok and type(decoded) == "table" then
      input = decoded
    end
  end

  local mode = input.mode
  if not mode then
    return nk.json_encode({ error = "MODE_REQUIRED" }), 400
  end

  -- 3. Try to find an open match
  local matches = nk.match_list(
    10,                 -- limit
    false,              -- authoritative
    nil,                -- label
    nil,                -- min_size (IMPORTANT: nil)
    nil                 -- max_size
  )

  for _, m in ipairs(matches) do
    if m.label == mode then
      -- Join existing match
      return nk.json_encode({
        action = "join",
        match_id = m.match_id
      }), 200
    end
  end

  -- 4. Create new match
  local match_id = nk.match_create("ludo_match", {
    mode = mode
  })

  return nk.json_encode({
    action = "create",
    match_id = match_id
  }), 200
end

nk.register_rpc(rpc_match_entry, "match_entry")
