local nk = require("nakama")

local function rpc_quick_join(context, payload)
  nk.logger_warn("--- 🔍 DIAGNOSTIC START: INSPECTING 'nk' VARIABLE ---")

  -- 1. Check if nk itself is broken
  if type(nk) ~= "table" then
    nk.logger_error("❌ CRITICAL: 'nk' is NOT a table. It is: " .. type(nk))
    return nk.json_encode({ status = "debug", message = "nk is broken" })
  end

  -- 2. Print every single key found in nk
  local found_keys = {}
  for key, value in pairs(nk) do
    table.insert(found_keys, key)
  end
  table.sort(found_keys) -- Sort alphabetically for easier reading

  nk.logger_info("ℹ️ Found " .. #found_keys .. " keys in 'nk' object:")
  for _, key in ipairs(found_keys) do
    nk.logger_info("   👉 " .. key)
  end

  -- 3. Specifically check for matchmaker_add
  if nk.matchmaker_add then
    nk.logger_info("✅ SUCCESS: nk.matchmaker_add EXISTS!")
  else
    nk.logger_error("❌ FAILURE: nk.matchmaker_add is MISSING!")
  end

  nk.logger_warn("--- 🔍 DIAGNOSTIC END ---")

  -- Return dummy response so app doesn't freeze
  return nk.json_encode({
    status = "debug_mode",
    message = "Check server logs for diagnostic output"
  })
end

nk.register_rpc(rpc_quick_join, "rpc_quick_join")
