local nk = require("nakama")
local M = {}

function M.after_authenticate(context, account)
  -- HARD GUARDS (MANDATORY)
  if not context or not account then return end
  if not account.user_id then return end

  -- Only set username if missing (guest users)
  if not account.username or account.username == "" then
    local new_username = "guest_" .. string.sub(account.user_id, 1, 8)

    pcall(nk.account_update_id, account.user_id, {
      username = new_username
    })
  end

  -- NEVER return anything from this hook
end

return M
