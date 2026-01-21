local nk = require("nakama")

local M = {}

--------------------------------------------------
-- CONFIGURATION & CONSTANTS
--------------------------------------------------

local FINAL_HOME_POS = 100
local TURN_TIME_SECONDS = 12       -- Time to roll dice
local PAWN_SELECT_SECONDS = 10     -- Time to move a piece

local SAFE_TILES = {
  [0]=true,[8]=true,[13]=true,[21]=true,
  [26]=true,[34]=true,[39]=true,[47]=true
}

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

local function is_safe_tile(pos)
  return SAFE_TILES[pos] == true
end

-- NEW: Helper to identify team partners
local function is_teammate(mode, seat1, seat2)
  if mode ~= "team_2v2" then return false end
  -- In Ludo, partners sit opposite (distance of 2). E.g., 1 & 3, or 2 & 4.
  return math.abs(seat1 - seat2) == 2
end

--------------------------------------------------
-- VALID MOVE LOGIC
--------------------------------------------------

local function can_leave_base(dice)
  return dice == 6
end

local function can_pawn_move(pos, dice)
  if pos == "HOME" then return false end
  if pos == -1 then return can_leave_base(dice) end
  if pos + dice > FINAL_HOME_POS then return false end
  return true
end

local function get_valid_moves(state)
  local pawns = state.pawns[state.current_turn]
  local dice = state.dice_value
  local valid = {}

  for i,pos in pairs(pawns) do
    if can_pawn_move(pos, dice) then
      table.insert(valid, i)
    end
  end
  return valid
end

--------------------------------------------------
-- MATCH END & WIN CONDITIONS (UPDATED)
--------------------------------------------------

local function check_player_finished(state, seat)
  if not state.pawns[seat] then return false end -- Safety check
  for _,pos in pairs(state.pawns[seat]) do
    if pos ~= "HOME" then return false end
  end
  return true
end

local function should_end_match(state)
  -- NEW: Team Up Win Condition (Both partners must finish)
  if state.mode == "team_2v2" then
    local teamA_finished = check_player_finished(state, 1) and check_player_finished(state, 3)
    local teamB_finished = check_player_finished(state, 2) and check_player_finished(state, 4)
    return teamA_finished or teamB_finished
  end

  -- Standard Logic (Solo/Clash)
  local total = get_expected_players(state.mode)
  return state.finished_count >= (total - 1)
end

local function end_match(state, dispatcher)
  if state.match_ended then return end
  state.match_ended = true

  -- Assign ranks to anyone left over
  for seat,_ in pairs(state.seats) do
    if not state.player_rank[seat] then
      state.finished_count = state.finished_count + 1
      state.player_rank[seat] = state.finished_count
    end
  end

  dispatcher.broadcast_message(1, nk.json_encode({
    type = "GAME_END",
    reason = "NORMAL_END",
    ranks = state.player_rank
  }))
end

--------------------------------------------------
-- GAMEPLAY: MOVE, KILL, EVENTS
--------------------------------------------------

local function compute_move_path(start_pos, dice)
  local path = {}
  if start_pos == -1 then
    table.insert(path, 0)
    return path
  end
  for i=1,dice do table.insert(path, start_pos+i) end
  return path
end

-- UPDATED: Added Teammate check to prevent Friendly Fire
local function find_opponent_pawns(state, seat, pos)
  local victims = {}
  for s,pawns in pairs(state.pawns) do
    -- Only check if NOT yourself AND NOT your teammate
    if s ~= seat and not is_teammate(state.mode, seat, s) then
      for i,p in pairs(pawns) do
        if p == pos then
          table.insert(victims, {seat=s, pawn=i})
        end
      end
    end
  end
  return victims
end

local function kill_pawn(state, dispatcher, v)
  state.pawns[v.seat][v.pawn] = -1
  dispatcher.broadcast_message(1, nk.json_encode({
    type="PAWN_KILLED", seat=v.seat, pawn=v.pawn
  }))
end

local function move_pawn(state, dispatcher, pawn)
  local seat = state.current_turn
  local start = state.pawns[seat][pawn]
  local dice = state.dice_value

  local path = compute_move_path(start, dice)
  local final = path[#path]

  if final == FINAL_HOME_POS then
    final = "HOME"
    state.extra_turn = true
  end

  state.pawns[seat][pawn] = final

  dispatcher.broadcast_message(1, nk.json_encode({
    type="PAWN_MOVING", seat=seat, pawn=pawn, path=path, final=final
  }))

  -- Check for Kills
  if final ~= "HOME" and not is_safe_tile(final) then
    local victims = find_opponent_pawns(state, seat, final)
    if #victims > 0 then
      -- Kill the first victim found (standard Ludo rules usually kill one)
      kill_pawn(state, dispatcher, victims[1])
      state.extra_turn = true
    end
  end

  -- Check for Player Finish
  if final == "HOME" and check_player_finished(state, seat) then
    state.finished_count = state.finished_count + 1
    state.player_rank[seat] = state.finished_count

    dispatcher.broadcast_message(1, nk.json_encode({
      type="PLAYER_FINISHED", seat=seat, rank=state.player_rank[seat]
    }))

    if should_end_match(state) then
      end_match(state, dispatcher)
      return
    end
    
    -- In Team Up, if I finish, my turn is skipped in future, but game goes on.
    -- (Basic implementation: pass turn. Advanced: roll for partner.)
  end

  state.turn_phase = "TURN_END"
end

--------------------------------------------------
-- DICE LOGIC
--------------------------------------------------

local function roll_dice(state, dispatcher, reason)
  local dice = math.random(1,6)
  state.dice_value = dice
  state.consecutive_six = (dice==6) and state.consecutive_six+1 or 0

  dispatcher.broadcast_message(1, nk.json_encode({
    type="DICE_ROLLED", value=dice, seat=state.current_turn, reason=reason
  }))

  -- Rule: 3 Sixes in a row = turn forfeit
  if state.consecutive_six >= 3 then
    dispatcher.broadcast_message(1, nk.json_encode({
      type="THREE_SIX_RULE", seat=state.current_turn
    }))
    state.consecutive_six = 0
    state.turn_phase = "TURN_END"
    return
  end

  local valid = get_valid_moves(state)
  
  -- No moves possible? End turn.
  if #valid == 0 then 
    state.turn_phase="TURN_END"
    return 
  end
  
  -- Only one move possible? Auto-move it immediately.
  if #valid == 1 then 
    move_pawn(state, dispatcher, valid[1])
    return 
  end

  -- Multiple moves? Wait for player selection.
  dispatcher.broadcast_message(1, nk.json_encode({
    type="SELECT_PAWN", seat=state.current_turn, pawns=valid
  }))
  
  state.turn_phase = "WAIT_PAWN_SELECT"
  -- NEW: Set a deadline so the game doesn't hang if they don't pick
  state.turn_deadline = os.time() + PAWN_SELECT_SECONDS
end

--------------------------------------------------
-- MATCH INIT
--------------------------------------------------

function M.match_init(context, params)
  return {
    match_id = context.match_id,
    mode = params.mode or "solo_1v1",

    players = {},
    seats = {},
    seat_owners = {}, -- ✅ NEW: Map to track UserID -> Seat Number
    pawns = {},

    current_turn = 1,
    turn_phase = "INIT",

    dice_value = nil,
    consecutive_six = 0,
    turn_deadline = 0,

    extra_turn = false,
    finished_count = 0,
    player_rank = {},
    match_ended = false,

    status = "WAITING"
  }, 1, "ludo_match" -- Tick rate of 1 per second is fine for Ludo
end

--------------------------------------------------
-- JOIN / LOOP / SIGNAL
--------------------------------------------------

function M.match_join_attempt(_,_,_,state)
  return state.status == "WAITING"
end

function M.match_join(_,dispatcher,_,state,presences)
  for _,p in ipairs(presences) do
    state.players[p.user_id] = true
  end

  -- Check if room is full
  local count = 0
  for _ in pairs(state.players) do count = count + 1 end
  
  if state.status == "WAITING" and count == get_expected_players(state.mode) then
    local s = 1
    -- ✅ UPDATED LOOP: Iterate over keys to capture User ID
    for user_id, _ in pairs(state.players) do
      state.seats[s] = true
      state.seat_owners[s] = user_id -- ✅ Store the User ID for this seat
      state.pawns[s] = {-1,-1,-1,-1} -- -1 means in Base
      s = s + 1
    end
    state.status = "RUNNING"
    state.turn_phase = "TURN_START"
    dispatcher.broadcast_message(1, nk.json_encode({type="GAME_START"}))
  end
  return state
end

function M.match_loop(_, dispatcher, _, state)
  if state.status ~= "RUNNING" or state.match_ended then return state end

  local now = os.time()

  -- PHASE 1: Start Turn
  if state.turn_phase == "TURN_START" then
    -- Skip players who have already finished
    if check_player_finished(state, state.current_turn) then
       state.turn_phase = "TURN_END"
       return state
    end

    state.turn_phase = "WAIT_DICE"
    state.turn_deadline = now + TURN_TIME_SECONDS
    
    -- Notify client it's their turn
    dispatcher.broadcast_message(1, nk.json_encode({
      type="TURN_START", seat=state.current_turn, deadline=state.turn_deadline
    }))

  -- PHASE 2: Wait for Dice Roll
  elseif state.turn_phase == "WAIT_DICE" and now >= state.turn_deadline then
    roll_dice(state, dispatcher, "AUTO") -- Auto-roll if time runs out

  -- PHASE 3: Wait for Pawn Selection
  elseif state.turn_phase == "WAIT_PAWN_SELECT" and now >= state.turn_deadline then
    -- Auto-move logic: Pick the first valid pawn
    local valid = get_valid_moves(state)
    if #valid > 0 then
      move_pawn(state, dispatcher, valid[1])
    else
      state.turn_phase = "TURN_END"
    end

  -- PHASE 4: End Turn & Rotate Player
  elseif state.turn_phase == "TURN_END" then
    if state.extra_turn then
      state.extra_turn = false
      state.turn_phase = "TURN_START"
    else
      -- Count seats safely to handle rotation
      local total_seats = 0
      for _ in pairs(state.seats) do total_seats = total_seats + 1 end
      
      state.current_turn = (state.current_turn % total_seats) + 1
      state.turn_phase = "TURN_START"
    end
  end

  return state
end

function M.match_signal(_, dispatcher, _, state, data)
  local msg = nk.json_decode(data)

  -- Handle Manual Dice Roll
  if msg.type == "ROLL_DICE" and state.turn_phase == "WAIT_DICE" then
    roll_dice(state, dispatcher, "MANUAL")

  -- Handle Manual Pawn Selection
  elseif msg.type == "SELECT_PAWN" and state.turn_phase == "WAIT_PAWN_SELECT" then
    local valid = get_valid_moves(state)
    local is_valid = false
    for _, v in ipairs(valid) do
      if v == msg.pawn then is_valid = true break end
    end

    if is_valid then
      move_pawn(state, dispatcher, msg.pawn)
    end
  end
  
  return state
end

function M.match_terminate() end

return M
