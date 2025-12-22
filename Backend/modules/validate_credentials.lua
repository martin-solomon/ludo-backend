local nk = require("nakama")

local function validate_credentials(context, payload)
    if not context or not context.user_id then
        return nk.json_encode({
            ok = false,
            error = "unauthorized"
        })
    end

    local data = nk.json_decode(payload or "{}")
    local email = data.email or ""
    local password = data.password or ""

    -- Email rule: must end with @gmail.com
    if not email:match("^[%w%.%-_]+@gmail%.com$") then
        return nk.json_encode({
            ok = false,
            error = "Invalid email format. Must end with @gmail.com"
        })
    end

    -- Password rules
    if #password < 8 then
        return nk.json_encode({
            ok = false,
            error = "Password must be at least 8 characters"
        })
    end

    if not password:match("%l") then
        return nk.json_encode({
            ok = false,
            error = "Password must contain a lowercase letter"
        })
    end

    if not password:match("%u") then
        return nk.json_encode({
            ok = false,
            error = "Password must contain an uppercase letter"
        })
    end

    if not password:match("%d") then
        return nk.json_encode({
            ok = false,
            error = "Password must contain a number"
        })
    end

    if not password:match("[%W_]") then
        return nk.json_encode({
            ok = false,
            error = "Password must contain a special character"
        })
    end

    -- All rules passed
    return nk.json_encode({
        ok = true
    })
end

nk.register_rpc(validate_credentials, "validate.credentials")
