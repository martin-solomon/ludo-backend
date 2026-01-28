local nk = require("nakama")

math.randomseed(os.time())

local function request_password_reset(context, payload)
  local data = nk.json_decode(payload or "{}")
  local email = data.email
  if not email then error("Email required") end

  -- generate OTP (6 digits)
  local otp = tostring(math.random(100000, 999999))
  local expiry = os.time() + 300 -- 5 minutes

  -- store OTP (NO user_id because user is not logged in)
  nk.storage_write({
    {
      collection = "password_reset",
      key = email,
      user_id = nil,
      value = {
        otp = otp,
        expiry = expiry
      },
      permission_read = 0,
      permission_write = 0
    }
  })

  -- call FastAPI email service
  local body = nk.json_encode({
    recipient = email,
    subject = "Password Reset",
    message = "Your OTP is " .. otp
  })

  local headers = {
    ["Content-Type"] = "application/json",
    ["X-API-Key"] = "ksjdfbhsidjknasdjkdnksajdnskdjndkjsdnskjd"
  }

  local res = nk.http_request(
    "http://host.docker.internal:8000/send-email",
    "POST",
    headers,
    body
  )

  if res.code ~= 200 then
    nk.logger_error("Email send failed: " .. res.body)
    error("Failed to send email")
  end

  return nk.json_encode({ status = "OTP_SENT" })
end

nk.register_rpc(request_password_reset, "request_password_reset", false)
