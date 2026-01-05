local M = {}

function M.after_authenticate(ctx)
    if not ctx or not ctx.user_id then return end
    if not ctx.vars then return end

    local username = ctx.vars["username"]
    if not username or username == "" then return end

    local nk = require("nakama")

    local ok, err = pcall(nk.account_update_id, ctx.user_id, {
        username = tostring(username)
    })

    if not ok then
        nk.logger_warn("after_authenticate failed: " .. tostring(err))
    end
end

return M
