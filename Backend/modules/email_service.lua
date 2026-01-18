local aws_email = require "resty.aws.email"

local M = {}

function M.send_test_email(to, subject, body)
  local client = aws_email.new({
    aws_key = "YOUR_AWS_ACCESS_KEY",
    aws_secret = "YOUR_AWS_SECRET_KEY",
    region = "YOUR_AWS_REGION", -- e.g., "us-east-1"
    -- Alternatively, use SMTP credentials:
    -- smtp_host = "email-smtp.YOUR_AWS_REGION.amazonaws.com",
    -- smtp_port = 587,
    -- smtp_user = "YOUR_SMTP_USERNAME",
    -- smtp_pass = "YOUR_SMTP_PASSWORD"
  })

  local ok, err = client:send({
    from = "sender@yourverifieddomain.com",
    to = to,
    subject = subject,
    body = body
  })

  return ok, err
end

return M
