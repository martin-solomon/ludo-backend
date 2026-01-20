local nk = require("nakama")

local M = {}

--------------------------------------------------
-- HELPERS
--------------------------------------------------

local function get_expected_players(mode)
  if mode == "solo_1v1" then return 2 end
  if mode == "duo_3p" then return 3 end
  if mode == "solo_4p" then return 4 end
  if mode == "team_2v2" then return 4 end
  return 2
end

local SEAT_COLORS = {
  [1] = "RED",
  [2] = "BLUE",
  [3] = "GREEN",
  [4] = "YELLOW"
}


--------------------------------------------------
-- MATCH INIT
--------------------------------------------------
function M.match_init(context, params)
  local state = {
    match_id = context.match_id,
    mode = params.mode or "solo_1v1",

    players = {},     -- user_id -> player data
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

--------------------------------------------------
-- MATCH JOIN ATTEMPT
--------------------------------------------------
function M.match_join_attempt(context, dispatcher, tick, state, presence, metadata)
  if state.status ~= "WAITING" then
    return false, "MATCH_ALREADY_STARTED"
  end
  return true
end

--------------------------------------------------
-- MATCH JOIN
--------------------------------------------------
function M.match_join(context, dispatcher, tick, state, presences)
  -- Add players safely
  for _, p in ipairs(presences) do
    if not state.players[p.user_id] then
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
    else
      state.players[p.user_id].connected = true
    end
  end

  -- Count players
  local player_count = 0
  for _ in pairs(state.players) do
    player_count = player_count + 1
  end

  local expected_players = get_expected_players(state.mode)

  -- Start match if ready
  if state.status == "WAITING" and player_count == expected_players then
    local seat = 1
    for user_id, player in pairs(state.players) do
      player.seat = seat
      player.color = SEAT_COLORS[seat]
      state.seats[seat] = user_id
      seat = seat + 1
    end

    state.current_turn = 1
    state.turn_phase = "TURN_START"
    state.status = "RUNNING"
    state.consecutive_six = 0
    state.dice_value = nil

    dispatcher.broadcast_message(1, nk.json_encode({
      type = "GAME_START",
      state = state
    }))
  end

  return state
end

--------------------------------------------------
-- MATCH LEAVE
--------------------------------------------------
function M.match_leave(context, dispatcher, tick, state, presences)
  for _, p in ipairs(presences) do
    if state.players[p.user_id] then
      state.players[p.user_id].connected = false
    end
  end
  return state
end
--------------------------
-- match loop helper
--------------------------
local TURN_TIME_SECONDS = 12

local function start_turn(state, dispatcher)
  local current_seat = state.current_turn
  local current_user_id = state.seats[current_seat]

  state.turn_phase = "WAIT_DICE"
  state.turn_deadline = os.time() + TURN_TIME_SECONDS

  dispatcher.broadcast_message(1, nk.json_encode({
    type = "TURN_START",
    player_id = current_user_id,
    seat = current_seat,
    deadline = state.turn_deadline
  }))
end

--------------------------------------------------
-- MATCH LOOP (CORE ENGINE TICK)
--------------------------------------------------
function M.match_loop(context, dispatcher, tick, state, messages)
  if state.status ~= "RUNNING" then
    return state
  end

  -- STEP 3A: Start turn
  if state.turn_phase == "TURN_START" then
    start_turn(state, dispatcher)
    return state
  end

  -- STEP 3B: Waiting for dice roll
  if state.turn_phase == "WAIT_DICE" then
    if os.time() >= state.turn_deadline then
      dispatcher.broadcast_message(1, nk.json_encode({
        type = "TURN_TIMEOUT",
        player_id = state.seats[state.current_turn]
      }))

      -- For now: directly move to next turn
      state.turn_phase = "TURN_END"
    end
  end

  -- STEP 3C: End turn (temporary logic)
  if state.turn_phase == "TURN_END" then
    -- move to next player safely
    state.current_turn = state.current_turn + 1
    if state.current_turn > #state.seats then
      state.current_turn = 1
    end

    state.consecutive_six = 0
    state.dice_value = nil
    state.turn_phase = "TURN_START"
  end

  return state
end


--------------------------------------------------
-- MATCH SIGNAL (OPTIONAL)
--------------------------------------------------
function M.match_signal(context, dispatcher, tick, state, data)
  return state, data
end

--------------------------------------------------
-- MATCH TERMINATE
--------------------------------------------------
function M.match_terminate(context, dispatcher, tick, state, grace_seconds)
  return state
end

return M


