-- rpc_debug_rewards.lua
local nk = require("nakama")

local function rpc_debug_rewards(context, payload)
  if not context.user_id then
    return nk.json_encode({ error = "unauthorized" }), 401
  end

  local data = nk.json_decode(payload or "{}")

  local coins = tonumber(data.coins) or 0
  local xp = tonumber(data.xp) or 0

  if coins <= 0 and xp <= 0 then
    return nk.json_encode({ error = "invalid_reward" }), 400
  end

  if coins > 0 then
    nk.wallet_update(context.user_id, { coins = coins }, {}, false)
  end

  return nk.json_encode({
    status = "ok",
    coins_added = coins,
    xp_added = xp
  })
end

nk.register_rpc(rpc_debug_rewards, "debug.rewards")
