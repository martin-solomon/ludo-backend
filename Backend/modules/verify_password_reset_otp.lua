local nk = require("nakama")

local function verify_password_reset_otp(ctx, payload)
  local data = nk.json_decode(payload or "{}")
  local email = data.email
  local otp = data.otp

  if not email or not otp then
    return nk.json_encode({ success = false, error = "invalid_request" })
  end

  local records = nk.storage_read({
    {
      collection = "password_reset_otps",
      key = email,
      user_id = nil
    }
  })

  if #records == 0 then
    return nk.json_encode({ success = false, error = "invalid_or_expired_otp" })
  end

  local stored = records[1].value

  if stored.otp ~= otp or stored.expires_at < os.time() then
    return nk.json_encode({ success = false, error = "invalid_or_expired_otp" })
  end

  -- Mark OTP as verified
  stored.verified = true

  nk.storage_write({
    {
      collection = "password_reset_otps",
      key = email,
      user_id = nil,
      value = stored,
      permission_read = 0,
      permission_write = 0
    }
  })

  return nk.json_encode({ success = true })
end

-- PUBLIC RPC
nk.register_rpc(verify_password_reset_otp, "verify_password_reset_otp", false)
