local nk = require("nakama")

-- Admin auth (provided by client)
local ADMIN_BASIC_AUTH = "ksjdfbhsidjknasdjkdnksajdnskjd"

local function confirm_password_reset(ctx, payload)
  local data = nk.json_decode(payload or "{}")
  local email = data.email
  local new_password = data.new_password

  if not email or not new_password then
    return nk.json_encode({ success = false, error = "invalid_request" })
  end

  local records = nk.storage_read({
    {
      collection = "password_reset_otps",
      key = email,
      user_id = nil
    }
  })

  if #records == 0 or records[1].value.verified ~= true then
    return nk.json_encode({ success = false, error = "otp_not_verified" })
  end

  -- Find user by email
  local users = nk.users_get_id({ email = email })
  if #users == 0 then
    return nk.json_encode({ success = false, error = "user_not_found" })
  end

  local user_id = users[1]

  -- Update password via Nakama Admin API
  local res = nk.http_request(
    "https://newcol-console.nlsn.in/v2/console/account/" .. user_id .. "/password",
    "POST",
    {
      ["Authorization"] = ADMIN_BASIC_AUTH,
      ["Content-Type"] = "application/json"
    },
    nk.json_encode({ password = new_password })
  )

  if res.code ~= 200 then
    nk.logger_error("Password update failed: " .. res.body)
    return nk.json_encode({ success = false, error = "password_update_failed" })
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

-- PUBLIC RPC
nk.register_rpc(confirm_password_reset, "confirm_password_reset", false)
