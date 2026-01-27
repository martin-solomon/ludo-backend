local nk = require("nakama")

math.randomseed(os.time())

local function generate_otp()
  return tostring(math.random(100000, 999999)) -- EXACTLY 6 digits
end

local function request_password_reset(ctx, payload)
  local data = nk.json_decode(payload or "{}")
  local email = data.email

  -- Always return success (anti user-enumeration)
  if not email or email == "" then
    return nk.json_encode({ success = true })
  end

  local otp = generate_otp()
  local expires_at = os.time() + (10 * 60) -- 10 minutes

  -- Store OTP
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

  -- Send email (SES / SMTP service)
  nk.http_request(
    "http://127.0.0.1:8000/send-email",
    "POST",
    {
      ["Content-Type"] = "application/json",
      ["X-API-Key"] = "ksjdfbhsidjknasdjkdnksajdnskjd"
    },
    nk.json_encode({
      recipient = email,
      subject = "Password Reset OTP",
      message = "Your OTP is: " .. otp .. "\nValid for 10 minutes."
    })
  )

  return nk.json_encode({ success = true })
end

-- PUBLIC RPC
nk.register_rpc(request_password_reset, "request_password_reset", false)
