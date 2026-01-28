local nk = require("nakama")

local M = {}

------------------------------------------------------------------------
-- PART 1: CONFIGURATION & CONSTANTS
-- Defines board size, timers, and safe zones.
------------------------------------------------------------------------

local FINAL_HOME_POS = 100
local TURN_TIME_SECONDS = 15       -- Increased slightly for better UX
local PAWN_SELECT_SECONDS = 12     

-- Safe tiles (Star tiles) where you cannot be killed
local SAFE_TILES = {
  [0]=true, [8]=true, [13]=true, [21]=true,
  [26]=true, [34]=true, [39]=true, [47]=true
}

------------------------------------------------------------------------
-- PART 2: HELPERS (MODES & TEAMS)
-- Handles player counts and team identification.
------------------------------------------------------------------------

-- Maps your specific game modes to player counts
local function get_expected_players(mode)
  if mode == "solo"  then return 2 end -- 1vs1
  if mode == "clash" then return 3 end -- 1vs2
  if mode == "rush"  then return 4 end -- 1vs3
  if mode == "team"  then return 4 end -- 2vs2
  return 2 -- Default fallback
end

local function is_safe_tile(pos)
  return SAFE_TILES[pos] == true
end

-- In 2v2, Seat 1 & 3 are partners (Red/Green)
-- Seat 2 & 4 are partners (Blue/Yellow)
local function is_teammate(mode, seat1, seat2)
  if mode ~= "team" then return false end
  return math.abs(seat1 - seat2) == 2
end

-- Fisher-Yates Shuffle: Randomizes the order of players
local function shuffle_table(t)
  for i = #t, 2, -1 do
    local j = math.random(i)
    t[i], t[j] = t[j], t[i]
  end
end

------------------------------------------------------------------------
-- PART 3: GAME RULES (MOVEMENT)
-- Logic for leaving base and moving on the board.
------------------------------------------------------------------------

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

  for i, pos in pairs(pawns) do
    if can_pawn_move(pos, dice) then
      table.insert(valid, i)
    end
  end
  return valid
end

------------------------------------------------------------------------
-- PART 4: WIN CONDITIONS
-- Logic to check if a player or team has won.
------------------------------------------------------------------------

local function check_player_finished(state, seat)
  if not state.pawns[seat] then return false end 
  for _, pos in pairs(state.pawns[seat]) do
    if pos ~= "HOME" then return false end
  end
  return true
end

local function should_end_match(state)
  -- 2v2 Team Win Logic
  if state.mode == "team" then
    local teamA_finished = check_player_finished(state, 1) and check_player_finished(state, 3)
    local teamB_finished = check_player_finished(state, 2) and check_player_finished(state, 4)
    return teamA_finished or teamB_finished
  end

  -- Standard Win Logic (End when 1 player is left)
  local total = get_expected_players(state.mode)
  return state.finished_count >= (total - 1)
end

-- Helper to payout rewards
local function distribute_rewards(state, dispatcher)
  local total_pot = get_expected_players(state.mode) * 50 -- e.g., 4 * 50 = 200 coins
  local winners = {}

  -- LOGIC 1: TEAM MODE (2v2) - Winners split 100%
  if state.mode == "team" then
    -- Check which team finished (Team A: 1&3, Team B: 2&4)
    local teamA_finished = check_player_finished(state, 1) and check_player_finished(state, 3)
    
    local winning_seats = {}
    if teamA_finished then 
        winning_seats = {1, 3} -- Team A Wins
    else 
        winning_seats = {2, 4} -- Team B Wins
    end
    
    local payout_per_player = total_pot / 2 -- e.g., 200 / 2 = 100 coins each
    
    for _, seat in ipairs(winning_seats) do
        local uid = state.seat_owners[seat]
        if uid then
            nk.wallet_update(uid, { coins = payout_per_player }, nil, { reason = "match_win_team" })
            table.insert(winners, { seat = seat, amount = payout_per_player })
        end
    end

  -- LOGIC 2: SOLO / CLASH / RUSH (Rank based split)
  else
    -- Sort seats by Rank (1st, 2nd, 3rd...)
    local ranked_uids = {}
    for seat, rank in pairs(state.player_rank) do
        ranked_uids[rank] = state.seat_owners[seat]
    end

    -- Define Percentages based on Game Mode
    local percentages = {}
    if state.mode == "solo" then        percentages = {1.0}           end -- 1st: 100%
    if state.mode == "clash" then       percentages = {0.6, 0.4}      end -- 1st: 60%, 2nd: 40%
    if state.mode == "rush" then        percentages = {0.6, 0.3, 0.1} end -- 1st: 60%, 2nd: 30%, 3rd: 10%

    -- Distribute
    for rank, pct in ipairs(percentages) do
        local uid = ranked_uids[rank]
        if uid then
            local reward = math.floor(total_pot * pct)
            nk.wallet_update(uid, { coins = reward }, nil, { reason = "match_win_rank_"..rank })
            table.insert(winners, { rank = rank, amount = reward })
        end
    end
  end
  
  return winners
end

local function end_match(state, dispatcher)
  if state.match_ended then return end
  state.match_ended = true

  -- Assign remaining ranks for anyone who didn't finish
  for seat, _ in pairs(state.seats) do
    if not state.player_rank[seat] then
      state.finished_count = state.finished_count + 1
      state.player_rank[seat] = state.finished_count
    end
  end

  -- 💰 PAYOUT REWARDS
  local payouts = distribute_rewards(state, dispatcher)

  dispatcher.broadcast_message(1, nk.json_encode({
    type = "GAME_END",
    reason = "NORMAL_END",
    ranks = state.player_rank,
    payouts = payouts
  }))
end

------------------------------------------------------------------------
-- PART 5: KILL LOGIC & MOVEMENT EXECUTION
-- Handles calculating paths, finding victims, and killing pawns.
------------------------------------------------------------------------

local function compute_move_path(start_pos, dice)
  local path = {}
  if start_pos == -1 then
    table.insert(path, 0)
    return path
  end
  for i=1, dice do table.insert(path, start_pos+i) end
  return path
end

local function find_opponent_pawns(state, seat, pos)
  local victims = {}
  for s, pawns in pairs(state.pawns) do
    -- Rule: You cannot kill yourself AND you cannot kill your teammate
    if s ~= seat and not is_teammate(state.mode, seat, s) then
      for i, p in pairs(pawns) do
        if p == pos then
          table.insert(victims, {seat=s, pawn=i})
        end
      end
    end
  end
  return victims
end

local function kill_pawn(state, dispatcher, v)
  state.pawns[v.seat][v.pawn] = -1 -- Send back to base
  dispatcher.broadcast_message(1, nk.json_encode({
    type = "PAWN_KILLED", 
    seat = v.seat, 
    pawn = v.pawn
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
    state.extra_turn = true -- Bonus turn for finishing
  end

  state.pawns[seat][pawn] = final

  dispatcher.broadcast_message(1, nk.json_encode({
    type = "PAWN_MOVING", 
    seat = seat, 
    pawn = pawn, 
    path = path, 
    final = final
  }))

  -- Check for Kill
  if final ~= "HOME" and not is_safe_tile(final) then
    local victims = find_opponent_pawns(state, seat, final)
    if #victims > 0 then
      kill_pawn(state, dispatcher, victims[1])
      state.extra_turn = true -- Bonus turn for killing
    end
  end

  -- Check for Win
  if final == "HOME" and check_player_finished(state, seat) then
    state.finished_count = state.finished_count + 1
    state.player_rank[seat] = state.finished_count

    dispatcher.broadcast_message(1, nk.json_encode({
      type = "PLAYER_FINISHED", 
      seat = seat, 
      rank = state.player_rank[seat]
    }))

    if should_end_match(state) then
      end_match(state, dispatcher)
      return
    end
  end

  state.turn_phase = "TURN_END"
end

------------------------------------------------------------------------
-- PART 6: DICE LOGIC
-- Handles rolling 6, 3x six rule, and turn validation.
------------------------------------------------------------------------

local function roll_dice(state, dispatcher, reason)
  local dice = math.random(1,6)
  state.dice_value = dice
  
  -- Logic: If 6, increment counter. If not 6, reset counter.
  state.consecutive_six = (dice == 6) and state.consecutive_six + 1 or 0

  dispatcher.broadcast_message(1, nk.json_encode({
    type = "DICE_ROLLED", 
    value = dice, 
    seat = state.current_turn, 
    reason = reason
  }))

  -- Rule: Three 6s in a row cancels the turn
  if state.consecutive_six >= 3 then
    dispatcher.broadcast_message(1, nk.json_encode({
      type = "THREE_SIX_RULE", 
      seat = state.current_turn
    }))
    state.consecutive_six = 0
    state.turn_phase = "TURN_END"
    return
  end

  local valid = get_valid_moves(state)
  
  -- No moves possible
  if #valid == 0 then 
    state.turn_phase = "TURN_END"
    return 
  end
  
  -- Only 1 move possible (Auto-move)
  if #valid == 1 then 
    move_pawn(state, dispatcher, valid[1])
    return 
  end

  -- Multiple moves: Wait for player selection
  dispatcher.broadcast_message(1, nk.json_encode({
    type = "SELECT_PAWN", 
    seat = state.current_turn, 
    pawns = valid
  }))
  
  state.turn_phase = "WAIT_PAWN_SELECT"
  state.turn_deadline = os.time() + PAWN_SELECT_SECONDS
end

------------------------------------------------------------------------
-- PART 7: MATCH INITIALIZATION
-- Sets up the empty state tables.
------------------------------------------------------------------------

function M.match_init(context, params)
  return {
    match_id = context.match_id,
    mode = params.mode or "solo",
    
    players = {},         -- Map: user_id -> true
    player_skins = {},    -- Map: user_id -> skin_id (Avatar)
    
    seats = {},           -- Map: seat_index -> true (Active seats)
    seat_owners = {},     -- Map: seat_index -> user_id (Who owns Red, Blue, etc)
    pawns = {},           -- Map: seat_index -> [pos1, pos2, pos3, pos4]
    
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
  }, 1, "ludo_match"
end

------------------------------------------------------------------------
-- PART 8: MATCH JOIN & START LOGIC (CRITICAL UPGRADE)
-- Handles random colors, skin syncing, and game start.
------------------------------------------------------------------------

function M.match_join_attempt(_, _, _, state)
  return state.status == "WAITING"
end

function M.match_join(_, dispatcher, _, state, presences)
  
  -- 1. Register new players and FETCH SKINS
  for _, p in ipairs(presences) do
    if not state.players[p.user_id] then
      state.players[p.user_id] = true
      
      -- Fetch Profile from Storage to get 'active_avatar'
      local objects = nk.storage_read({
        { collection = "user_profiles", key = p.user_id, user_id = p.user_id }
      })
      
      -- Default skin if none found
      local skin_id = "avatar_1" 
      if objects and objects[1] and objects[1].value and objects[1].value.active_avatar then
        skin_id = objects[1].value.active_avatar.id or "avatar_1"
      end
      
      state.player_skins[p.user_id] = skin_id
    end
  end

  -- 2. Count players
  local count = 0
  for _ in pairs(state.players) do count = count + 1 end
  local required = get_expected_players(state.mode)
  
  -- 3. Broadcast Waiting Status (Queue Update)
  if state.status == "WAITING" then
    if count < required then
        -- Tell clients: "Waiting for X more players..."
        dispatcher.broadcast_message(1, nk.json_encode({
            type = "WAITING_UPDATE",
            current = count,
            needed = required
        }))
    else
        -- 4. START GAME LOGIC
        state.status = "RUNNING"
        
        -- A. Create list of User IDs
        local user_list = {}
        for uid, _ in pairs(state.players) do
            table.insert(user_list, uid)
        end
        
        -- B. Shuffle the list (RANDOM COLORS)
        shuffle_table(user_list)
        
        -- C. Assign Seats (1=Red, 2=Green, 3=Blue, 4=Yellow)
        -- NOTE: Logic matches standard Ludo board layout
        for i, uid in ipairs(user_list) do
            state.seats[i] = true
            state.seat_owners[i] = uid
            state.pawns[i] = {-1, -1, -1, -1} -- All 4 pawns at base
        end
        
        -- D. Broadcast Start with Metadata (Colors + Skins)
        state.turn_phase = "TURN_START"
        dispatcher.broadcast_message(1, nk.json_encode({
            type = "GAME_START",
            mode = state.mode,
            seat_map = state.seat_owners,  -- { "1": "user_abc", "2": "user_xyz" }
            skins = state.player_skins     -- { "user_abc": "avatar_knight" }
        }))
    end
  end
  
  return state
end

-- Handles players disconnecting mid-game
function M.match_leave(_, dispatcher, _, state, presences)
  if state.match_ended then return state end

  for _, p in ipairs(presences) do
    -- Find which seat this player owned
    for seat, uid in pairs(state.seat_owners) do
      if uid == p.user_id then
        -- Only mark as "left" if they haven't already finished/won
        if not state.player_rank[seat] then
          state.finished_count = state.finished_count + 1
          state.player_rank[seat] = state.finished_count
          
          -- Notify others
          dispatcher.broadcast_message(1, nk.json_encode({
            type = "PLAYER_LEFT", 
            seat = seat,
            userId = uid
          }))
        end
      end
    end
  end

  -- If too many people left, end the match
  if should_end_match(state) then
    end_match(state, dispatcher)
  end

  return state
end

------------------------------------------------------------------------
-- PART 9: MAIN GAME LOOP & SIGNALS
-- Handles the flow of turns, timers, and client inputs.
------------------------------------------------------------------------

function M.match_loop(_, dispatcher, _, state)
  if state.status ~= "RUNNING" or state.match_ended then return state end

  local now = os.time()

  -- Loop through phases
  if state.turn_phase == "TURN_START" then
    
    -- Skip player if they already finished
    if check_player_finished(state, state.current_turn) then
       state.turn_phase = "TURN_END"
       return state
    end

    state.turn_phase = "WAIT_DICE"
    state.turn_deadline = now + TURN_TIME_SECONDS
    
    dispatcher.broadcast_message(1, nk.json_encode({
      type = "TURN_START", 
      seat = state.current_turn, 
      deadline = state.turn_deadline
    }))

  elseif state.turn_phase == "WAIT_DICE" and now >= state.turn_deadline then
    -- Timer expired: Auto-roll dice
    roll_dice(state, dispatcher, "AUTO")

  elseif state.turn_phase == "WAIT_PAWN_SELECT" and now >= state.turn_deadline then
    -- Timer expired: Auto-move first available pawn
    local valid = get_valid_moves(state)
    if #valid > 0 then
      move_pawn(state, dispatcher, valid[1])
    else
      state.turn_phase = "TURN_END"
    end

  elseif state.turn_phase == "TURN_END" then
    if state.extra_turn then
      state.extra_turn = false
      state.turn_phase = "TURN_START"
    else
      -- Pass turn to next seat (Circle 1->2->3->4->1)
      local total_seats = get_expected_players(state.mode)
      state.current_turn = (state.current_turn % total_seats) + 1
      state.turn_phase = "TURN_START"
    end
  end

  return state
end

-- Handles inputs from Clients (Roll Dice, Move Pawn)
function M.match_signal(_, dispatcher, _, state, data)
  local msg = {}
  -- Safe decode
  local status, res = pcall(nk.json_decode, data)
  if status then msg = res end

  -- Security: You can add a check here to ensure context.user_id matches the current seat owner
  
  if msg.type == "ROLL_DICE" and state.turn_phase == "WAIT_DICE" then
    roll_dice(state, dispatcher, "MANUAL")
  
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
