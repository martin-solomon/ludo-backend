local nk = require("nakama")

-- Register hook SAFELY
nk.register_after_authenticate(function(ctx)
    -- Absolute safety checks
    if not ctx then
        return
    end

    if not ctx.user_id then
        return
    end

    -- vars may be nil
    if not ctx.vars then
        return
    end

    local username = ctx.vars["username"]

    if not username or username == "" then
        return
    end

    -- Update username ONCE
    local ok, err = pcall(nk.account_update_id, ctx.user_id, {
        username = tostring(username)
    })

    if not ok then
        nk.logger_warn(
            "after_authenticate username update failed: " .. tostring(err)
        )
    end
end)
