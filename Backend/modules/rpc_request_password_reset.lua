local nk = require("nakama")

math.randomseed(os.time())

-- MUST MATCH ENV
local HTTP_KEY = "ksjdfbhsidjknasdjkdnksajdnskdjndkjsdnskjd"

local function generate_otp()
  return tostring(math.random(100000, 999999))
end

local function request_password_reset(ctx, payload)
  -- 🔐 CUSTOM HTTP KEY AUTH
  local key = ctx.http_headers["x-http-key"]
  if not key or key ~= HTTP_KEY then
    return nk.json_encode({
      success = false,
      error = "Unauthorized"
    }), 401
  end

  local data = nk.json_decode(payload or "{}")
  local email = data.email

  -- Anti user enumeration
  if not email or email == "" then
    return nk.json_encode({ success = true })
  end

  local otp = generate_otp()
  local expires_at = os.time() + (10 * 60)

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
      message = "Your OTP is: " .. otp
    })
  )

  return nk.json_encode({ success = true })
end

-- PUBLIC RPC (no session)
nk.register_rpc(request_password_reset, "request_password_reset", false)


