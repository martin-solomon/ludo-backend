local nk = require("nakama")

local M = {}

function M.after_authenticate(context, session, source)
  -- Defensive coding ONLY
  if not session or not session.user_id then
    return
  end

  -- OPTIONAL: log once for debug
  nk.logger_info(
    string.format(
      "after_authenticate: user_id=%s source=%s",
      session.user_id,
      tostring(source)
    )
  )

  -- DO NOT write storage here yet
  -- DO NOT call other modules yet
end

return M
