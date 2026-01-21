local nk = require("nakama")

-- ✅ Standalone function (NOT inside table)
local function rpc_quick_join(context, payload)
  if not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local data = {}
  if payload and payload ~= "" then
    local ok, decoded = pcall(nk.json_decode, payload)
    if ok and type(decoded) == "table" then
      data = decoded
    end
  end

  local mode = data.mode or "solo_1v1"

  local max_count = ({
    solo_1v1 = 2,
    duo_3p   = 3,
    solo_4p  = 4,
    team_2v2 = 4
  })[mode] or 2

  nk.matchmaker_add(
    context.user_id,
    context.session_id,
    { mode = mode },
    max_count,
    max_count,
    1
  )

  return nk.json_encode({
    status = "searching",
    mode = mode
  })
end

-- ✅ Register the FUNCTION itself
nk.register_rpc(rpc_quick_join, "rpc_quick_join")
