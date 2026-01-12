-- daily_task_catalog.lua
-- Static daily task definitions (SERVER AUTHORITY)

local DAILY_TASKS = {

  -- ======================
  -- PLAY MATCH TASKS
  -- ======================
  {
    id = "play_1_match",
    title = "Play 1 Match",
    type = "play_match",
    target = 1,
    reward = { coins = 50 }
  },
  {
    id = "play_3_matches",
    title = "Play 3 Matches",
    type = "play_match",
    target = 3,
    reward = { coins = 120 }
  },
  {
    id = "play_5_matches",
    title = "Play 5 Matches",
    type = "play_match",
    target = 5,
    reward = { coins = 200 }
  },
  {
    id = "play_10_matches",
    title = "Play 10 Matches",
    type = "play_match",
    target = 10,
    reward = { coins = 400 }
  },

  -- ======================
  -- WIN MATCH TASKS
  -- ======================
  {
    id = "win_1_match",
    title = "Win 1 Match",
    type = "win_match",
    target = 1,
    reward = { coins = 100 }
  },
  {
    id = "win_3_matches",
    title = "Win 3 Matches",
    type = "win_match",
    target = 3,
    reward = { coins = 250 }
  },
  {
    id = "win_5_matches",
    title = "Win 5 Matches",
    type = "win_match",
    target = 5,
    reward = { coins = 450 }
  },

  -- ======================
  -- DICE TASKS
  -- ======================
  {
    id = "roll_dice_3",
    title = "Roll Dice 3 Times",
    type = "dice_roll",
    target = 3,
    reward = { coins = 75 }
  },
  {
    id = "roll_dice_10",
    title = "Roll Dice 10 Times",
    type = "dice_roll",
    target = 10,
    reward = { coins = 150 }
  },
  {
    id = "roll_six_3",
    title = "Roll a Six 3 Times",
    type = "roll_six",
    target = 3,
    reward = { coins = 200 }
  },

  -- ======================
  -- MODE-SPECIFIC TASKS
  -- ======================
  {
    id = "play_solo_match",
    title = "Play 1 Solo Match",
    type = "play_solo",
    target = 1,
    reward = { coins = 80 }
  },
  {
    id = "play_duo_match",
    title = "Play 1 Duo Match",
    type = "play_duo",
    target = 1,
    reward = { coins = 100 }
  },
  {
    id = "play_squad_match",
    title = "Play 1 Squad Match",
    type = "play_squad",
    target = 1,
    reward = { coins = 120 }
  },

  -- ======================
  -- TURN / MOVE TASKS
  -- ======================
  {
    id = "move_10_times",
    title = "Make 10 Moves",
    type = "move_pawn",
    target = 10,
    reward = { coins = 60 }
  },
  {
    id = "capture_3_pawns",
    title = "Capture 3 Pawns",
    type = "capture_pawn",
    target = 3,
    reward = { coins = 150 }
  },

  -- ======================
  -- SOCIAL / EXTRA TASKS
  -- ======================
  {
    id = "send_5_gifts",
    title = "Send 5 Gifts",
    type = "send_gift",
    target = 5,
    reward = { coins = 100 }
  },
  {
    id = "send_10_gifts",
    title = "Send 10 Gifts",
    type = "send_gift",
    target = 10,
    reward = { coins = 200 }
  },

  -- ======================
  -- SESSION / ACTIVITY TASKS
  -- ======================
  {
    id = "complete_1_game_session",
    title = "Complete 1 Game Session",
    type = "complete_game",
    target = 1,
    reward = { coins = 70 }
  },
  {
    id = "play_30_minutes",
    title = "Play for 30 Minutes",
    type = "play_time",
    target = 30,
    reward = { coins = 150 }
  },

  -- ======================
  -- SKILL / ADVANCED TASKS
  -- ======================
  {
    id = "win_without_capture",
    title = "Win a Match Without Capturing",
    type = "win_clean",
    target = 1,
    reward = { coins = 300 }
  },
  {
    id = "finish_with_all_pawns",
    title = "Finish with All Pawns",
    type = "finish_all_pawns",
    target = 1,
    reward = { coins = 250 }
  },
  {
    id = "consecutive_wins_2",
    title = "Win 2 Matches in a Row",
    type = "win_streak",
    target = 2,
    reward = { coins = 220 }
  },
  {
    id = "consecutive_wins_3",
    title = "Win 3 Matches in a Row",
    type = "win_streak",
    target = 3,
    reward = { coins = 350 }
  }
}

return DAILY_TASKS
