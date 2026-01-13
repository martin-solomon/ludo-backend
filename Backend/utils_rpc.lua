-- utils_rpc.lua
local nk = require("nakama")

local M = {}

-- Parse RPC payload robustly.
-- RPC body may be:
--  - a Lua table (already decoded by runtime), or
--  - a JSON string (e.g. "\"{\\\"username\\\":...}\"" or "{...}" depending on client)
-- Returns: table (decoded payload) or nil + error message
function M.parse_rpc_payload(payload)
  -- already a table
  if type(payload) == "table" then
    return payload
  end

  -- nil or empty
  if payload == nil or payload == "" then
    return {}
  end

  -- payload may be a JSON string or a quoted JSON string.
  if type(payload) == "string" then
    -- try decode directly
    local ok, decoded = pcall(nk.json_decode, payload)
    if ok and type(decoded) == "table" then
      return decoded
    end

    -- if it is a quoted JSON string (e.g. "\"{...}\""), unquote and unescape
    local s = payload
    if #s >= 2 and s:sub(1,1) == '"' and s:sub(-1,-1) == '"' then
      -- remove outer quotes then replace \" with "
      s = s:sub(2, -2):gsub('\\"', '"')
      ok, decoded = pcall(nk.json_decode, s)
      if ok and type(decoded) == "table" then
        return decoded
      end
    end

    -- last attempt: try to treat string as JS-like object (rare). Fail gracefully.
    return nil, "invalid rpc payload (not JSON object)"
  end

  return nil, "unsupported rpc payload type: " .. type(payload)
end

return M
