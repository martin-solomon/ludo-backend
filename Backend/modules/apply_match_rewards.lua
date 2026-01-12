local nk = require("nakama")
local rate_limit = require("utils_rate_limit")

--------------------------------------------------
-- DUPLICATE REWARD PROTECTION
-- Prevents double rewards for same match
--------------------------------------------------
local function reward_already_given(user_id, match_id)
    local result = nk.storage_read({
        {
            collection = "match_rewards",
            key = match_id,
            user_id = user_id
        }
    })
    return result and #result > 0
end

local function mark_reward_given(user_id, match_id)
    nk.storage_write({
        {
            collection = "match_rewards",
            key = match_id,
            user_id = user_id,
            value = { given_at = os.time() },
            permission_read = 0,
            permission_write = 0
        }
    })
end

--------------------------------------------------
-- CORE REWARD APPLICATION (ONLINE MATCH ONLY)
--------------------------------------------------
local function apply_rewards(user_id, rewards, match_id)
    if not user_id or not match_id then
        nk.logger_error("apply_rewards blocked: missing user_id or match_id")
        return nil
    end

    -- Duplicate protection
    if reward_already_given(user_id, match_id) then
        nk.logger_warn("Duplicate reward blocked | user=" .. user_id)
        return nil
    end

    --------------------------------------------------
    -- LOAD PROFILE
    --------------------------------------------------
    local objects = nk.storage_read({
        {
            collection = "profile",
            key = "player",
            user_id = user_id
        }
    })

    if not objects or #objects == 0 then
        nk.logger_error("Profile missing for user " .. user_id)
        return nil
    end

    local profile = objects[1].value or {}

    --------------------------------------------------
    -- APPLY GAME REWARDS
    --------------------------------------------------
    local coins_delta = rewards.coins or 0
    local xp_delta    = rewards.xp or 0

    profile.coins = math.max(0, (profile.coins or 0) + coins_delta)
    profile.xp = (profile.xp or 0) + xp_delta
    profile.wins = (profile.wins or 0) + 1
    profile.matches_played = (profile.matches_played or 0) + 1

    -- Level calculation (simple, safe)
    profile.level = math.floor(profile.xp / 100) + 1

    --------------------------------------------------
    -- SAVE PROFILE
    --------------------------------------------------
    nk.storage_write({
        {
            collection = "profile",
            key = "player",
            user_id = user_id,
            value = profile,
            permission_read = 1,
            permission_write = 0
        }
    })

    mark_reward_given(user_id, match_id)

    --------------------------------------------------
    -- LEADERBOARD UPDATE
    -- Priority:
    --   1) Higher LEVEL
    --   2) Higher WINS
    --
    -- Composite score approach (safe & fast)
    --------------------------------------------------
    local level = profile.level or 1
    local wins  = profile.wins or 0

    -- Level dominates wins completely
    local leaderboard_score = (level * 1_000_000) + wins

    -- Never crash match flow due to leaderboard
    pcall(function()
        nk.leaderboard_record_write(
            "global_wins",
            user_id,
            profile.username or user_id,
            leaderboard_score,
            {
                level = level,
                wins = wins,
                avatar_id = profile.avatar_id or "default"
            }
        )
    end)

    --------------------------------------------------
    -- ECONOMY AUDIT LOG (OPTIONAL, BUT RECOMMENDED)
    --------------------------------------------------
    nk.storage_write({
        {
            collection = "economy_log",
            key = nk.uuid_v4(),
            user_id = user_id,
            value = {
                source = "online_match_reward",
                match_id = match_id,
                coins_delta = coins_delta,
                xp_delta = xp_delta,
                level = profile.level,
                timestamp = os.time()
            },
            permission_read = 0,
            permission_write = 0
        }
    })

    return profile
end

--------------------------------------------------
-- TEST / ADMIN RPC (OPTIONAL – KEEP FOR NOW)
-- Can be removed after full match flow is live
--------------------------------------------------
local function apply_match_rewards_rpc(context, payload)
    if not context.user_id then
        return nk.json_encode({ error = "unauthorized" }), 401
    end

    local ok, reason = rate_limit.check(context, "apply_match_rewards", 2)
    if not ok then
        return nk.json_encode({ error = reason }), 429
    end

    local input = nk.json_decode(payload or "{}")

    if not input.user_id or not input.match_id then
        return nk.json_encode({ error = "missing_params" }), 400
    end

    local profile = apply_rewards(
        input.user_id,
        {
            coins = input.coins or 0,
            xp = input.xp or 0
        },
        input.match_id
    )

    if not profile then
        return nk.json_encode({ success = false })
    end

    return nk.json_encode({
        success = true,
        profile = profile
    })
end

nk.register_rpc(apply_match_rewards_rpc, "apply_match_rewards")

--------------------------------------------------
-- EXPORT FOR MATCH HANDLER USE
--------------------------------------------------
return apply_rewards
