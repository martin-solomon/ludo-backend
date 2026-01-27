local nk = require("nakama")

math.randomseed(os.time())

-- Must match Email Service API key
local EMAIL_API_KEY = "ksjdfbhsidjknasdjkdnksajdnskdjndkjsdnskjd"

local function generate_otp()
  return tostring(math.random(100000, 999999))
end

local function request_password_reset(ctx, payload)
  local data = nk.json_decode(payload or "{}")
  local email = data.email

  -- Anti user-enumeration
  if not email or email == "" then
    return nk.json_encode({ success = true })
  end

  local otp = generate_otp()
  local expires_at = os.time() + (10 * 60)

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

  -- 🔥 CALL EMAIL SERVICE (this matches curl exactly)
  nk.http_request(
    "https://newcol-http.nlsn.in/send-email",
    "POST",
    {
      ["Content-Type"] = "application/json",
      ["X-API-Key"] = EMAIL_API_KEY
    },
    nk.json_encode({
      recipient = email,
      subject = "Password Reset",
      message = "OTP for resetting your password is " .. otp
    })
  )

  return nk.json_encode({ success = true })
end

nk.register_rpc(request_password_reset, "request_password_reset", false)


