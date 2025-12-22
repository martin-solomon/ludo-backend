local nk = require("nakama")

local M = {}

-- EMAIL VALIDATION
local function is_valid_email(email)
    if type(email) ~= "string" then return false end
    email = email:lower()
    return email:match("^[%w%.%-_]+@gmail%.com$") ~= nil
end

-- PASSWORD VALIDATION
local function is_valid_password(password)
    if type(password) ~= "string" then return false end
    if #password < 8 then return false end

    local has_upper = password:match("%u")
    local has_lower = password:match("%l")
    local has_digit = password:match("%d")
    local has_special = password:match("[%W_]")

    return has_upper and has_lower and has_digit and has_special
end

-- RPC HANDLER
local function validate_credentials_rpc(context, payload)
    local data = nk.json_decode(payload or "{}")

    local email = data.email
    local password = data.password

    if not is_valid_email(email) then
        return nk.json_encode({
            valid = false,
            error = "Email must end with @gmail.com"
        }), 400
    end

    if not is_valid_password(password) then
        return nk.json_encode({
            valid = false,
            error = "Password must contain uppercase, lowercase, number, special character, and be at least 8 characters"
        }), 400
    end

    return nk.json_encode({ valid = true }), 200
end

nk.register_rpc(validate_credentials_rpc, "validate.credentials")

return M
