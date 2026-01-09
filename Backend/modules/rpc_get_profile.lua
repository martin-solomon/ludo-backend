local nk = require("nakama")

-- =========================================================
-- PHASE-1 : PUBLIC USER PROFILE FETCH
-- =========================================================
-- This RPC returns ONLY public-safe profile data.
-- It is used by:
--   - Lobby UI
--   - Match UI
--   - Opponent info
--   - Leaderboard
--
-- Visibility:
--   - Self profile
--   - Opponent profiles
--
-- Forbidden data (INTENTIONALLY EXCLUDED):
--   - coins (wallet)
--   - xp (progress internals)
--   - username / email / password
-- =========================================================

local function rpc_get_user_profile(context, payload)

    -- 1. AUTH CHECK
    if not context or not context.user_id then
        return nk.json_encode({ error = "unauthorized" })
    end

    -- 2. PAYLOAD DECODE
    local data = nk.json_decode(payload or "{}")
    local target_user_id = data.user_id

    if not target_user_id then
        return nk.json_encode({ error = "user_id_required" })
    end

    -- 3. STORAGE READ (PUBLIC PROFILE)
    local objects = nk.storage_read({
        {
            collection = "user_profiles",
            key = target_user_id,
            user_id = target_user_id
        }
    })

    -- 4. SAFE DEFAULT PROFILE
    -- Returned if profile is missing (new user / edge case)
    if not objects or #objects == 0 then
        return nk.json_encode({
            display_name = "Player",
            avatar_id = "default",
            level = 1,
            stats = {
                matches = 0,
                wins = 0
            }
        })
    end

    -- 5. SANITIZED RESPONSE (PUBLIC FIELDS ONLY)
    local profile = objects[1].value or {}

    return nk.json_encode({
        display_name = profile.display_name or "Player",
        avatar_id = profile.avatar_id or "default",
        level = profile.level or 1,
        stats = profile.stats or {
            matches = 0,
            wins = 0
        }
    })
end

-- RPC REGISTRATION
nk.register_rpc(rpc_get_user_profile, "rpc_get_user_profile")
-- =========================================================
-- PHASE-1 : UPDATE OWN PUBLIC PROFILE
-- =========================================================
-- Allowed updates:
--   - display_name
--   - avatar_id
--
-- Forbidden:
--   - username, email, password
--   - coins, xp, level, stats
-- =========================================================

local function rpc_update_profile(context, payload)

    -- 1. AUTH CHECK
    if not context or not context.user_id then
        return nk.json_encode({ error = "unauthorized" })
    end

    -- 2. DECODE PAYLOAD
    local data = nk.json_decode(payload or "{}")

    local new_display_name = data.display_name
    local new_avatar_id = data.avatar_id

    -- 3. VALIDATION
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

    -- 4. READ EXISTING PROFILE
    local objects = nk.storage_read({
        {
            collection = "user_profiles",
            key = context.user_id,
            user_id = context.user_id
        }
    })

    local profile = {}

    if objects and #objects > 0 then
        profile = objects[1].value or {}
    end

    -- 5. APPLY ALLOWED UPDATES ONLY
    if new_display_name ~= nil then
        profile.display_name = new_display_name
    end

    if new_avatar_id ~= nil then
        profile.avatar_id = new_avatar_id
    end

    -- Ensure required fields always exist
    profile.level = profile.level or 1
    profile.stats = profile.stats or { matches = 0, wins = 0 }

    -- 6. WRITE BACK TO STORAGE
    nk.storage_write({
        {
            collection = "user_profiles",
            key = context.user_id,
            user_id = context.user_id,
            value = profile,
            permission_read = 2,   -- public read
            permission_write = 1   -- owner write
        }
    })

    -- 7. SUCCESS RESPONSE
    return nk.json_encode({ success = true })
end

-- REGISTER RPC
nk.register_rpc(rpc_update_profile, "rpc_update_profile")


