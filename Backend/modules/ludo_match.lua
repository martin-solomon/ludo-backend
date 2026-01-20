local nk = require("nakama")

local M = {}

-- --------------------------------------------------
-- MATCH INIT
-- --------------------------------------------------
function M.match_init(context, params)
  local state = {
    match_id = context.match_id,
    mode = params.mode or "solo_1v1",

    players = {},     -- user_id -> { user_id, seat, color, skin_id, connected }
    seats = {},       -- seat_index -> user_id

    current_turn = 1,
    turn_phase = "INIT",

    consecutive_six = 0,
    dice_value = nil,
    turn_deadline = 0,

    status = "WAITING"
  }

  -- tick_rate = 1 (1 loop per second)
  return state, 1, "ludo_match"
end

-- --------------------------------------------------
-- MATCH JOIN ATTEMPT
-- --------------------------------------------------
function M.match_join_attempt(context, dispatcher, tick, state, presence, metadata)
  if state.status ~= "WAITING" then
    return false, "MATCH_ALREADY_STARTED"
  end
  return true
end

-- --------------------------------------------------
-- MATCH JOIN
-- --------------------------------------------------
function M.match_join(context, dispatcher, tick, state, presences)
  for _, p in ipairs(presences) do
    state.players[p.user_id] = {
      user_id = p.user_id,
      username = p.username,
      session_id = p.session_id,
      seat = nil,
      color = nil,
      skin_id = p.metadata and p.metadata.skin_id or "default",
      connected = true,
      finished = false
    }
  end

  return state
end

-- --------------------------------------------------
-- MATCH LEAVE
-- --------------------------------------------------
function M.match_leave(context, dispatcher, tick, state, presences)
  for _, p in ipairs(presences) do
    if state.players[p.user_id] then
      state.players[p.user_id].connected = false
    end
  end
  return state
end

-- --------------------------------------------------
-- MATCH LOOP (CORE ENGINE TICK)
-- --------------------------------------------------
function M.match_loop(context, dispatcher, tick, state, messages)
  -- We do NOTHING here yet.
  -- Next steps will add:
  -- - turn start
  -- - timers
  -- - dice
  -- - moves
  return state
end

-- --------------------------------------------------
-- MATCH SIGNAL (OPTIONAL)
-- --------------------------------------------------
function M.match_signal(context, dispatcher, tick, state, data)
  return state, data
end

-- --------------------------------------------------
-- MATCH TERMINATE
-- --------------------------------------------------
function M.match_terminate(context, dispatcher, tick, state, grace_seconds)
  return state
end

return M
