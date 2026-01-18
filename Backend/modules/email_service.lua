local aws_email = require "resty.aws.email" -- For lua-resty-aws-email

-- Your SES Configuration
local config = {
    aws_key = "YOUR_AWS_ACCESS_KEY",
    aws_secret = "YOUR_AWS_SECRET_KEY",
    region = "YOUR_AWS_REGION", -- e.g., "us-east-1"
    -- Alternatively, use SMTP credentials:
    -- smtp_host = "email-smtp.YOUR_AWS_REGION.amazonaws.com",
    -- smtp_port = 587,
    -- smtp_user = "YOUR_SMTP_USERNAME",
    -- smtp_pass = "YOUR_SMTP_PASSWORD"
}

local email_config = {
    from = "sender@yourverifieddomain.com",
    to = "recipient@example.com",
    subject = "Hello from Lua & SES",
    body = "This is the body of the email sent via AWS SES."
}

local client = aws_email.new(config)
local success, err = client:send(email_config)

if success then
    print("Email sent successfully!")
else
    print("Error sending email:", err)
ends