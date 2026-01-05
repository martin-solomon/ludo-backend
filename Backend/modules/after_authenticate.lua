local nk = require("nakama")

-- Runs immediately AFTER any authentication (device, email, Google, etc.)
nk.register_after_authenticate(function(ctx)
    -- We only care about guest/device auth
    if not ctx or not ctx.user_id then
        return
    end

    -- Username sent from frontend during auth
    local username =
        ctx.vars and ctx.vars.username and tostring(ctx.vars.username) or nil

    if not username or username == "" then
        return
    end

    -- Try to set username ONCE, safely
    local ok, err = pcall(nk.account_update_id, ctx.user_id, {
        username = username
    })

    if not ok then
        nk.logger_warn(
            "Username update failed during after_authenticate: " .. tostring(err)
        )
    else
        nk.logger_info(
            "Username set during auth | user_id=" .. ctx.user_id .. " | username=" .. username
        )
    end
end)
