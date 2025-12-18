local nk = require("nakama")

-- Helper to trim whitespace
local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- Username format validation
local function is_valid_username(username)
    -- Only letters, numbers, underscore | length 3–16
    if not username:match("^[a-zA-Z0-9_]+$") then
        return false
    end
    if #username < 3 or #username > 16 then
        return false
    end
    return true
end

-- Reserved usernames
local RESERVED_USERNAMES = {
    admin = true,
    support = true,
    moderator = true,
    system = true
}

local function create_guest_profile(context, payload)
    -- 🔐 AUTH CHECK
    if not context or not context.user_id then
        return nk.json_encode({ error = "unauthorized" }), 401
    end

    -- 📥 PAYLOAD (unwrap=true → raw string)
    local username = trim(payload or "")

    if username == "" then
        return nk.json_encode({ error = "username is required" }), 400
    end

    -- 🚫 RESERVED NAMES CHECK
    if RESERVED_USERNAMES[string.lower(username)] then
        return nk.json_encode({ error = "username not allowed" }), 400
    end

    -- 🧹 FORMAT VALIDATION
    if not is_valid_username(username) then
        return nk.json_encode({
            error = "invalid username (3–16 chars, letters/numbers/_ only)"
        }), 400
    end

    nk.logger_info("Creating guest profile for user_id: " .. context.user_id .. " username: " .. username)

    -- 🧑 ACCOUNT UPDATE (PHASE 1)
    local ok, err = pcall(nk.account_update_id, context.user_id, {
        username = username
    })

    if not ok then
        nk.logger_warn("Username update failed: " .. tostring(err))
        return nk.json_encode({ error = "username already taken" }), 409
    end

    -- 📦 STORAGE WRITE (PHASE 2)
    local write_ok, write_err = pcall(nk.storage_write, {
        {
            collection = "user_profiles",
            key = "profile",
            user_id = context.user_id,
            value = {
                username = username,
                guest = true,
                coins = 1000,
                level = 1,
                xp = 0,
                wins = 0,
                losses = 0,
                created_at = os.time()
            },
            permission_read = 2,  -- public read
            permission_write = 0  -- owner only
        }
    })

    if not write_ok then
        nk.logger_error("Storage write failed: " .. tostring(write_err))
        return nk.json_encode({ error = "storage failed" }), 500
    end

    -- ✅ SUCCESS RESPONSE
    return nk.json_encode({
        success = true,
        user_id = context.user_id,
        username = username,
        guest = true
    })
end

nk.register_rpc(create_guest_profile, "create_guest_profile")
