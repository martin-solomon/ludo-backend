local nk = require("nakama")

math.randomseed(os.time())

-- 🔐 MUST MATCH .env / Flutter httpKey
local HTTP_KEY = "ksjdfbhsidjknasdjkdnksajdnskdjndkjsdnskjd"

-- --------------------------------------------------
-- OTP GENERATOR (6 digits)
-- --------------------------------------------------
local function generate_otp()
  return tostring(math.random(100000, 999999))
end

-- --------------------------------------------------
-- REQUEST PASSWORD RESET RPC
-- --------------------------------------------------
local function request_password_reset(ctx, payload)
  -- 🔍 DEBUG: log incoming headers (remove later if needed)
  nk.logger_info("request_password_reset headers: " .. nk.json_encode(ctx.http_headers))

  -- 🔐 CUSTOM HTTP KEY AUTH (HEADERS ARE LOWERCASE!)
  local key = ctx.http_headers["x-http-key"]
  if not key or key ~= HTTP_KEY then
    nk.logger_warn("Unauthorized password reset attempt")
    return nk.json_encode({
      success = false,
      error = "Unauthorized"
    }), 401
  end

  -- Parse payload
  local data = nk.json_decode(payload or "{}")
  local email = data.email

  -- 🛡️ Anti user-enumeration (always success)
  if not email or email == "" then
    return nk.json_encode({ success = true })
  end

  -- Generate OTP
  local otp = generate_otp()
  local expires_at = os.time() + (10 * 60) -- 10 minutes

  -- Store OTP securely
  nk.storage_write({
    {
      collection = "password_reset_otps",
      key = email,
      user_id = nil,
      value = {
        otp = otp,
        expires_at = expires_at,
        verified = false
      },
      permission_read = 0,
      permission_write = 0
    }
  })

  -- --------------------------------------------------
  -- SEND EMAIL (PROTECTED TO AVOID TIMEOUTS)
  -- --------------------------------------------------
  local ok, err = pcall(function()
    nk.http_request(
      "https://newcol-api.nlsn.in/send-email",
      "POST",
      {
        ["Content-Type"] = "application/json",
        ["X-API-Key"] = HTTP_KEY
      },
      nk.json_encode({
        recipient = email,
        subject = "Password Reset OTP",
        message = "Your OTP is: " .. otp .. "\nValid for 10 minutes."
      })
    )
  end)

  if not ok then
    -- ❗ DO NOT FAIL USER FLOW IF EMAIL FAILS
    nk.logger_error("Password reset email failed: " .. tostring(err))
  end

  -- ✅ ALWAYS return success
  return nk.json_encode({ success = true })
end

-- --------------------------------------------------
-- PUBLIC RPC (NO SESSION REQUIRED)
-- --------------------------------------------------
nk.register_rpc(request_password_reset, "request_password_reset", false)
