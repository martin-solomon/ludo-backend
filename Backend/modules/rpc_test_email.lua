local nk = require("nakama")
local email_service = require("email_service")

local function test_email_rpc(ctx, payload)
  if not ctx.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local data = nk.json_decode(payload)

  local ok, err = email_service.send_test_email(
    data.to,
    data.subject,
    data.body
  )

  if not ok then
    return nk.json_encode({ success = false, error = err }), 500
  end

  return nk.json_encode({ success = true })
end

nk.register_rpc(test_email_rpc, "test_email")
