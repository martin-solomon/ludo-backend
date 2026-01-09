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
