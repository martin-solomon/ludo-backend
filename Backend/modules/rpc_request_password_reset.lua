local nk = require("nakama")

math.randomseed(os.time())

local function generate_otp()
  return tostring(math.random(100000, 999999))
end

local function request_password_reset(ctx, payload)
  local data = nk.json_decode(payload or "{}")
  local email = data.email

  -- Security: never reveal if user exists
  if not email or email == "" then
    return nk.json_encode({
      success = true,
      message = "If this email exists, a reset code was sent"
    })
  end

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
        expires_at = expires_at
      },
      permission_read = 0,
      permission_write = 0
    }
  })

  -- Send email via client email service
  nk.http_request(
    "http://127.0.0.1:8000/send-email",
    "POST",
    {
      ["Content-Type"] = "application/json",
      ["X-API-Key"] = "ksjdfbhsidjknasdjkdnksajdnskdjndkjsdnskjd"
    },
    nk.json_encode({
      recipient = email,
      subject = "Password Reset",
      message = "OTP for resetting your password is " .. otp
    })
  )

  return nk.json_encode({
    success = true,
    message = "If this email exists, a reset code was sent"
  })
end

nk.register_rpc(request_password_reset, "request_password_reset")
