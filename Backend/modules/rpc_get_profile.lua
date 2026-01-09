local nk = require("nakama")

-- =========================================================
-- PHASE-1 : USER PROFILE (PUBLIC + SELF UPDATE)
-- =========================================================
-- Covers:
--   STEP-1 : Public profile schema (locked)
--   STEP-2 : Public profile fetch (self + opponent)
--   STEP-3 : Self profile update (name + avatar)
--
-- IMPORTANT RULES:
--   - Session (context.user_id) is source of truth
--   - payload.user_id is OPTIONAL (only for opponent fetch)
--   - Wallet / coins / xp are NOT part of profile
-- =========================================================


-- =========================================================
-- STEP-2 : PUBLIC PROFILE FETCH
-- =========================================================
-- Supports:
--   - Self profile        → frontend sends NO payload
--   - Opponent profile    → payload.user_id provided
-- =========================================================
local function rpc_get_user_profile(context, payload)

    -- 1. AUTH CHECK
    if not context or not context.user_id then
        return nk.json_encode({ error = "unauthorized" })
    end

    -- 2. PAYLOAD DECODE (OPTIONAL)
    local data = nk.json_decode(payload or "{}")

    -- 3. RESOLVE TARGET USER
    --    If user_id provided → opponent
    --    Else → self (session)
    local target_user_id = data.user_id or context.user_id

    -- 4. READ PROFILE STORAGE
    local objects = nk.storage_read({
        {
            collection = "user_profiles",
            key = target_user_id,
            user_id = target_user_id
        }
    })

    local profile = {}

    if objects and #objects > 0 then
        profile = objects[1].value or {}
    else
        -- SAFE DEFAULT PROFILE (NEW USERS)
        profile = {
            display_name = "Player",
            avatar_id = "default",
            level = 1,
            stats = {
                matches = 0,
                wins = 0
            }
        }
    end

    -- 5. RETURN PUBLIC-SAFE RESPONSE ONLY
    return nk.json_encode({
        display_name = profile.display_name or "Player",
        avatar_id   = profile.avatar_id   or "default",
        level       = profile.level       or 1,
        stats       = profile.stats       or {
            matches = 0,
            wins = 0
        }
    })
end

nk.register_rpc(rpc_get_user_profile, "rpc_get_user_profile")


-- =========================================================
-- STEP-3 : UPDATE OWN PUBLIC PROFILE
-- =========================================================
-- Allowed updates:
--   - display_name
--   - avatar_id
--
-- Forbidden:
--   - user_id
--   - coins / xp
--   - level / stats
-- =========================================================
local function rpc_update_profile(context, payload)

    -- 1. AUTH CHECK
    if not context or not context.user_id then
        return nk.json_encode({ error = "unauthorized" })
    end

    local user_id = context.user_id
    local data = nk.json_decode(payload or "{}")

    local new_display_name = data.display_name
    local new_avatar_id = data.avatar_id

    -- 2. VALIDATION
    if new_display_name ~= nil then
        if type(new_display_name) ~= "string" or #new_display_name < 3 or #new_display_name > 20 then
            return nk.json_encode({ error = "invalid_display_name" })
        end
    end

    if new_avatar_id ~= nil then
        if type(new_avatar_id) ~= "string" or #new_avatar_id == 0 then
            return nk.json_encode({ error = "invalid_avatar_id" })
        end
    end

    -- 3. READ EXISTING PROFILE
    local objects = nk.storage_read({
        {
            collection = "user_profiles",
            key = user_id,
            user_id = user_id
        }
    })

    local profile = {}

    if objects and #objects > 0 then
        profile = objects[1].value or {}
    end

    -- 4. APPLY ALLOWED UPDATES ONLY
    if new_display_name ~= nil then
        profile.display_name = new_display_name
    end

    if new_avatar_id ~= nil then
        profile.avatar_id = new_avatar_id
    end

    -- ENSURE REQUIRED FIELDS EXIST
    profile.level = profile.level or 1
    profile.stats = profile.stats or { matches = 0, wins = 0 }

    -- 5. WRITE BACK TO STORAGE
    nk.storage_write({
        {
            collection = "user_profiles",
            key = user_id,
            user_id = user_id,
            value = profile,
            permission_read = 2,   -- public read
            permission_write = 1   -- owner write
        }
    })

    return nk.json_encode({ success = true })
end

nk.register_rpc(rpc_update_profile, "rpc_update_profile")


-- =========================================================
-- PHASE-2 (START) : WALLET FETCH (COINS ONLY)
-- =========================================================
-- Purpose:
--   Fetch user's wallet coins
-- Used by:
--   - Profile UI
--   - Shop
--   - Asset purchase
--
-- IMPORTANT:
--   - Read-only
--   - Session-based (self only)
-- =========================================================
local function rpc_get_wallet(context, payload)

    -- 1. AUTH CHECK
    if not context or not context.user_id then
        return nk.json_encode({ error = "unauthorized" })
    end

    local user_id = context.user_id

    -- 2. FETCH WALLET
    local wallet = nk.wallet_get(user_id)

    -- 3. SAFE RESPONSE
    return nk.json_encode({
        coins = wallet.coins or 0
    })
end

nk.register_rpc(rpc_get_wallet, "rpc_get_wallet")
