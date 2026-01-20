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
-- STEP 5: VALID MOVE HELPERS
--------------------------------------------------

local FINAL_HOME_POS = 100

local function can_leave_base(dice)
  return dice == 6
end

local function can_pawn_move(pos, dice)
  if pos == -1 then
    return can_leave_base(dice)
  end
  if pos + dice > FINAL_HOME_POS then
    return false
  end
  return true
end

local function get_valid_moves(state)
  local seat = state.current_turn
  local dice = state.dice_value
  local pawns = state.pawns[seat]

  local valid = {}
  for pawn_index, pos in pairs(pawns) do
    if can_pawn_move(pos, dice) then
      table.insert(valid, pawn_index)
    end
  end
  return valid
end

--------------------------------------------------
-- STEP 6: PAWN MOVEMENT
--------------------------------------------------

local function compute_move_path(start_pos, dice)
  local path = {}

  if start_pos == -1 then
    table.insert(path, 0)
    return path
  end

  for i = 1, dice do
    table.insert(path, start_pos + i)
  end
  return path
end

local function move_pawn(state, dispatcher, pawn_index)
  local seat = state.current_turn
  local start_pos = state.pawns[seat][pawn_index]
  local dice = state.dice_value

  local path = compute_move_path(start_pos, dice)
  local final_pos = path[#path]

  state.turn_phase = "MOVING"
  state.pawns[seat][pawn_index] = final_pos

  dispatcher.broadcast_message(1, nk.json_encode({
    type = "PAWN_MOVING",
    seat = seat,
    pawn = pawn_index,
    path = path
  }))

  -- End turn (kill/safe logic comes next step)
  state.turn_phase = "TURN_END"
end

--------------------------------------------------
-- STEP 4: DICE
--------------------------------------------------

local function roll_dice(state, dispatcher, reason)
  local dice = math.random(1, 6)
  state.dice_value = dice

  if dice == 6 then
    state.consecutive_six = state.consecutive_six + 1
  else
    state.consecutive_six = 0
  end

  dispatcher.broadcast_message(1, nk.json_encode({
    type = "DICE_ROLLED",
    value = dice,
    seat = state.current_turn,
    reason = reason or "MANUAL"
  }))

  -- 3 consecutive six rule
  if state.consecutive_six >= 3 then
    dispatcher.broadcast_message(1, nk.json_encode({
      type = "THREE_SIX_RULE",
      seat = state.current_turn
    }))
    state.consecutive_six = 0
    state.turn_phase = "TURN_END"
    return
  end

  -- STEP 5: VALID MOVE CALCULATION
  local valid_moves = get_valid_moves(state)

  if #valid_moves == 0 then
    dispatcher.broadcast_message(1, nk.json_encode({
      type = "NO_VALID_MOVE",
      seat = state.current_turn
    }))
    state.turn_phase = "TURN_END"
    return
  end

  if #valid_moves == 1 then
    dispatcher.broadcast_message(1, nk.json_encode({
      type = "AUTO_SELECT_PAWN",
      seat = state.current_turn,
      pawn = valid_moves[1]
    }))
    move_pawn(state, dispatcher, valid_moves[1])
    return
  end

  dispatcher.broadcast_message(1, nk.json_encode({
    type = "SELECT_PAWN",
    seat = state.current_turn,
    pawns = valid_moves
  }))
  state.turn_phase = "WAIT_PAWN_SELECT"
end

--------------------------------------------------
-- MATCH INIT
--------------------------------------------------
function M.match_init(context, params)
  local state = {
    match_id = context.match_id,
    mode = params.mode or "solo_1v1",

    players = {},
    seats = {},
    pawns = {},

    current_turn = 1,
    turn_phase = "INIT",

    consecutive_six = 0,
    dice_value = nil,
    turn_deadline = 0,

    status = "WAITING"
  }
  return state, 1, "ludo_match"
end

--------------------------------------------------
-- MATCH JOIN ATTEMPT
--------------------------------------------------
function M.match_join_attempt(context, dispatcher, tick, state)
  if state.status ~= "WAITING" then
    return false, "MATCH_ALREADY_STARTED"
  end
  return true
end

--------------------------------------------------
-- MATCH JOIN
--------------------------------------------------
function M.match_join(context, dispatcher, tick, state, presences)
  for _, p in ipairs(presences) do
    if not state.players[p.user_id] then
      state.players[p.user_id] = {
        user_id = p.user_id,
        username = p.username,
        seat = nil,
        color = nil,
        connected = true
      }
    end
  end

  local count = 0
  for _ in pairs(state.players) do count = count + 1 end
  local expected = get_expected_players(state.mode)

  if state.status == "WAITING" and count == expected then
    local seat = 1
    for _, player in pairs(state.players) do
      player.seat = seat
      player.color = SEAT_COLORS[seat]
      state.seats[seat] = player.user_id
      state.pawns[seat] = { -1, -1, -1, -1 }
      seat = seat + 1
    end

    state.status = "RUNNING"
    state.turn_phase = "TURN_START"

    dispatcher.broadcast_message(1, nk.json_encode({
      type = "GAME_START",
      state = state
    }))
  end
  return state
end

--------------------------------------------------
-- TURN TIMER
--------------------------------------------------
local TURN_TIME_SECONDS = 12

local function start_turn(state, dispatcher)
  local seat = state.current_turn
  state.turn_phase = "WAIT_DICE"
  state.turn_deadline = os.time() + TURN_TIME_SECONDS

  dispatcher.broadcast_message(1, nk.json_encode({
    type = "TURN_START",
    seat = seat,
    player_id = state.seats[seat],
    deadline = state.turn_deadline
  }))
end

--------------------------------------------------
-- MATCH LOOP
--------------------------------------------------
function M.match_loop(context, dispatcher, tick, state)
  if state.status ~= "RUNNING" then return state end

  if state.turn_phase == "TURN_START" then
    start_turn(state, dispatcher)
  elseif state.turn_phase == "WAIT_DICE" and os.time() >= state.turn_deadline then
    roll_dice(state, dispatcher, "AUTO")
  elseif state.turn_phase == "TURN_END" then
    state.current_turn = state.current_turn % #state.seats + 1
    state.turn_phase = "TURN_START"
  end

  return state
end

--------------------------------------------------
-- CLIENT INPUT
--------------------------------------------------
function M.match_signal(context, dispatcher, tick, state, data)
  local msg = nk.json_decode(data)
  local user = context.user_id
  local current = state.seats[state.current_turn]

  if msg.type == "ROLL_DICE" and user == current and state.turn_phase == "WAIT_DICE" then
    roll_dice(state, dispatcher, "MANUAL")
  elseif msg.type == "SELECT_PAWN" and user == current and state.turn_phase == "WAIT_PAWN_SELECT" then
    move_pawn(state, dispatcher, msg.pawn)
  end

  return state
end

--------------------------------------------------
-- MATCH TERMINATE
--------------------------------------------------
function M.match_terminate(context, dispatcher, tick, state)
  return state
end

return M
