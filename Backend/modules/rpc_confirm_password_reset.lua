local nk = require("nakama")

-- Admin credential provided by client
local ADMIN_BASIC_AUTH = "ksjdfbhsidjknasdjkdnksajdnskdjndkjsdnskjd"

local function confirm_password_reset(ctx, payload)
  local data = nk.json_decode(payload or "{}")

  local email = data.email
  local otp = data.otp
  local new_password = data.new_password

  if not email or not otp or not new_password then
    return nk.json_encode({
      success = false,
      error = "invalid_request"
    }), 400
  end

  -- Load OTP
  local records = nk.storage_read({
    {
      collection = "password_reset_otps",
      key = email,
      user_id = nil
    }
  })

  if #records == 0 then
    return nk.json_encode({
      success = false,
      error = "invalid_or_expired_otp"
    }), 400
  end

  local stored = records[1].value
  if stored.otp ~= otp or stored.expires_at < os.time() then
    return nk.json_encode({
      success = false,
      error = "invalid_or_expired_otp"
    }), 400
  end

  -- Get user ID
  local users = nk.users_get_id({ email = email })
  if #users == 0 then
    return nk.json_encode({
      success = false,
      error = "user_not_found"
    }), 400
  end

  local user_id = users[1]

  -- 🔐 Change password using Nakama Admin API
  local res = nk.http_request(
    "https://newcol-console.nlsn.in/v2/console/account/" .. user_id .. "/password",
    "POST",
    {
      ["Authorization"] = ADMIN_BASIC_AUTH,
      ["Content-Type"] = "application/json"
    },
    nk.json_encode({
      password = new_password
    })
  )

  if res.code ~= 200 then
    nk.logger_error("Admin password reset failed: " .. res.body)
    return nk.json_encode({
      success = false,
      error = "password_update_failed"
    }), 500
  end

  -- Cleanup OTP
  nk.storage_delete({
    {
      collection = "password_reset_otps",
      key = email,
      user_id = nil
    }
  })

  return nk.json_encode({ success = true })
end

nk.register_rpc(confirm_password_reset, "confirm_password_reset")
