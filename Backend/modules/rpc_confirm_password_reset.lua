local nk = require("nakama")

local function confirm_password_reset(context, payload)
  local data = nk.json_decode(payload or "{}")
  local email = data.email
  local otp = data.otp
  local new_password = data.new_password

  if not email or not otp or not new_password then
    error("Missing fields")
  end

  -- read OTP record
  local records = nk.storage_read({
    {
      collection = "password_reset",
      key = email,
      user_id = nil
    }
  })

  if #records == 0 then error("OTP not found") end

  local data_rec = records[1].value

  if data_rec.otp ~= otp then error("Invalid OTP") end
  if os.time() > data_rec.expiry then error("OTP expired") end

  -- find user by email (correct Nakama API)
  local users = nk.users_get({
    email = email,
    limit = 1
  })

  if not users or #users == 0 then
    error("User not found")
  end

  local user_id = users[1].id

  -- update password (CORRECT way)
  nk.account_update_id(user_id, {
    password = new_password
  })

  -- cleanup OTP
  nk.storage_delete({
    {
      collection = "password_reset",
      key = email,
      user_id = nil
    }
  })

  return nk.json_encode({ status = "PASSWORD_UPDATED" })
end

nk.register_rpc(confirm_password_reset, "confirm_password_reset", false)
