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
local function rpc_get_user_profile(context, payload)

    if not context or not context.user_id then
        return nk.json_encode({ error = "unauthorized" })
    end

    local data = nk.json_decode(payload or "{}")
    local target_user_id = data.user_id or context.user_id

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
        profile = {
            display_name = "Player",
            avatar_id = "default",
            level = 1,
            stats = { matches = 0, wins = 0 }
        }
    end

    return nk.json_encode({
        display_name = profile.display_name or "Player",
        avatar_id   = profile.avatar_id   or "default",
        level       = profile.level       or 1,
        stats       = profile.stats       or { matches = 0, wins = 0 }
    })
end

nk.register_rpc(rpc_get_user_profile, "rpc_get_user_profile")


-- =========================================================
-- STEP-3 : UPDATE OWN PUBLIC PROFILE
-- =========================================================
local function rpc_update_profile(context, payload)

    if not context or not context.user_id then
        return nk.json_encode({ error = "unauthorized" })
    end

    local user_id = context.user_id
    local data = nk.json_decode(payload or "{}")

    if data.display_name then
        if type(data.display_name) ~= "string" or #data.display_name < 3 or #data.display_name > 20 then
            return nk.json_encode({ error = "invalid_display_name" })
        end
    end

    if data.avatar_id then
        if type(data.avatar_id) ~= "string" or #data.avatar_id == 0 then
            return nk.json_encode({ error = "invalid_avatar_id" })
        end
    end

    local objects = nk.storage_read({
        { collection = "user_profiles", key = user_id, user_id = user_id }
    })

    local profile = {}
    if objects and #objects > 0 then
        profile = objects[1].value or {}
    end

    if data.display_name then profile.display_name = data.display_name end
    if data.avatar_id then profile.avatar_id = data.avatar_id end

    profile.level = profile.level or 1
    profile.stats = profile.stats or { matches = 0, wins = 0 }

    nk.storage_write({
        {
            collection = "user_profiles",
            key = user_id,
            user_id = user_id,
            value = profile,
            permission_read = 2,
            permission_write = 1
        }
    })

    return nk.json_encode({ success = true })
end

nk.register_rpc(rpc_update_profile, "rpc_update_profile")


-- =========================================================
-- HELPER : ENSURE WALLET INITIALIZED (1000 COINS ONCE)
-- =========================================================
local function ensure_wallet_initialized(user_id)

    local account = nk.account_get_id(user_id)
    local wallet = account.wallet or {}

    -- If coins already exist, DO NOTHING
    if wallet.coins ~= nil then
        return
    end

    -- Give default starting coins (ONE TIME ONLY)
    nk.wallet_update(
        user_id,
        { coins = 1000 },
        { reason = "initial_wallet_balance" }
    )
end


-- =========================================================
-- PHASE-2 : WALLET FETCH (COINS ONLY)
-- =========================================================
local function rpc_get_wallet(context, payload)

    if not context or not context.user_id then
        return nk.json_encode({ error = "unauthorized" })
    end

    local user_id = context.user_id

    -- 🔥 AUTO-INIT WALLET IF NEEDED
    ensure_wallet_initialized(user_id)

    local account = nk.account_get_id(user_id)
    local wallet = account.wallet or {}

    return nk.json_encode({
        coins = wallet.coins or 0
    })
end

nk.register_rpc(rpc_get_wallet, "rpc_get_wallet")


-- =========================================================
-- PHASE-2 : SPEND COINS (SHOP / ASSET PURCHASE)
-- =========================================================
local function rpc_spend_coins(context, payload)

    if not context or not context.user_id then
        return nk.json_encode({ error = "unauthorized" })
    end

    local data = nk.json_decode(payload or "{}")
    local cost = tonumber(data.cost)

    if not cost or cost <= 0 then
        return nk.json_encode({ error = "invalid_cost" })
    end

    local account = nk.account_get_id(context.user_id)
    local wallet = account.wallet or {}
    local current_coins = wallet.coins or 0

    if current_coins < cost then
        return nk.json_encode({
            error = "insufficient_coins",
            coins = current_coins
        })
    end

    nk.wallet_update(
        context.user_id,
        { coins = -cost },
        { reason = "shop_purchase" }
    )

    local updated_wallet = nk.account_get_id(context.user_id).wallet

    return nk.json_encode({
        success = true,
        coins = updated_wallet.coins or 0
    })
end

nk.register_rpc(rpc_spend_coins, "rpc_spend_coins")


-- =========================================================
-- PHASE-2 : ADD COINS (MATCH REWARD / BONUS)
-- =========================================================
local function rpc_add_coins(context, payload)

    if not context or not context.user_id then
        return nk.json_encode({ error = "unauthorized" })
    end

    local data = nk.json_decode(payload or "{}")
    local amount
