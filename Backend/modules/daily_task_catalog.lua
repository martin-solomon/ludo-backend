-- daily_task_catalog.lua
-- Static catalog of all possible daily tasks (175 total)

local CATALOG = {

-- =====================================================
-- 🎲 DICE TASKS (1–25)
-- =====================================================
{ id="dice_roll_5", event="dice_roll", goal=5, reward=5, tier=1, description="Roll the dice 5 times" },
{ id="dice_roll_10", event="dice_roll", goal=10, reward=10, tier=2, description="Roll the dice 10 times" },
{ id="dice_roll_20", event="dice_roll", goal=20, reward=15, tier=3, description="Roll the dice 20 times" },
{ id="dice_six_1", event="dice_six", goal=1, reward=10, tier=2, description="Roll a six once" },
{ id="dice_six_2", event="dice_six", goal=2, reward=15, tier=3, description="Roll a six twice" },
{ id="dice_six_3", event="dice_six", goal=3, reward=20, tier=4, description="Roll a six three times" },
{ id="dice_even_5", event="dice_even", goal=5, reward=10, tier=2, description="Roll even numbers 5 times" },
{ id="dice_odd_5", event="dice_odd", goal=5, reward=10, tier=2, description="Roll odd numbers 5 times" },
{ id="dice_consecutive", event="dice_consecutive", goal=1, reward=20, tier=4, description="Roll consecutive numbers" },
{ id="dice_first_turn", event="dice_first_turn", goal=1, reward=15, tier=3, description="Roll a six in first turn" },

-- =====================================================
-- ♟ PAWN MOVEMENT TASKS (26–50)
-- =====================================================
{ id="pawn_move_10", event="pawn_move", goal=10, reward=10, tier=2, description="Move any pawn 10 steps" },
{ id="pawn_move_20", event="pawn_move", goal=20, reward=15, tier=3, description="Move any pawn 20 steps" },
{ id="pawn_move_50", event="pawn_move", goal=50, reward=25, tier=5, description="Move any pawn 50 steps" },
{ id="pawn_from_base", event="pawn_base", goal=1, reward=15, tier=3, description="Move a pawn from base" },
{ id="pawn_to_home", event="pawn_home", goal=1, reward=25, tier=5, description="Move a pawn to home" },
{ id="pawn_safe_zone", event="pawn_safe", goal=1, reward=20, tier=4, description="Move pawn into safe zone" },
{ id="pawn_same_10", event="pawn_same", goal=10, reward=15, tier=3, description="Move same pawn 10 times" },
{ id="pawn_all_once", event="pawn_all", goal=4, reward=20, tier=4, description="Move all pawns once" },

-- =====================================================
-- 🏁 MATCH PLAY TASKS (51–75)
-- =====================================================
{ id="match_play_1", event="match_played", goal=1, reward=5, tier=1, description="Play 1 match" },
{ id="match_play_2", event="match_played", goal=2, reward=10, tier=2, description="Play 2 matches" },
{ id="match_play_3", event="match_played", goal=3, reward=15, tier=3, description="Play 3 matches" },
{ id="match_play_5", event="match_played", goal=5, reward=20, tier=4, description="Play 5 matches" },
{ id="match_full", event="match_complete", goal=1, reward=10, tier=2, description="Finish a full match" },
{ id="match_no_quit", event="match_no_quit", goal=1, reward=15, tier=3, description="Play match without quitting" },

-- =====================================================
-- 🏆 WIN TASKS (76–100)
-- =====================================================
{ id="win_1", event="match_win", goal=1, reward=15, tier=3, description="Win 1 match" },
{ id="win_2", event="match_win", goal=2, reward=20, tier=4, description="Win 2 matches" },
{ id="win_3", event="match_win", goal=3, reward=25, tier=5, description="Win 3 matches" },
{ id="win_clean", event="win_clean", goal=1, reward=25, tier=5, description="Win without losing a pawn" },
{ id="win_fast", event="win_fast", goal=1, reward=20, tier=4, description="Win a fast match" },

-- =====================================================
-- 🎯 CAPTURE TASKS (101–125)
-- =====================================================
{ id="capture_1", event="pawn_capture", goal=1, reward=10, tier=2, description="Capture 1 pawn" },
{ id="capture_2", event="pawn_capture", goal=2, reward=15, tier=3, description="Capture 2 pawns" },
{ id="capture_3", event="pawn_capture", goal=3, reward=20, tier=4, description="Capture 3 pawns" },
{ id="capture_safe", event="pawn_capture_safe", goal=1, reward=25, tier=5, description="Capture pawn safely" },

-- =====================================================
-- ⏱ ENDURANCE / CONSISTENCY TASKS (126–175)
-- =====================================================
{ id="play_5_min", event="play_time", goal=5, reward=5, tier=1, description="Play for 5 minutes" },
{ id="play_10_min", event="play_time", goal=10, reward=10, tier=2, description="Play for 10 minutes" },
{ id="play_15_min", event="play_time", goal=15, reward=15, tier=3, description="Play for 15 minutes" },
{ id="no_disconnect", event="no_disconnect", goal=1, reward=15, tier=3, description="Finish match without disconnect" },
{ id="no_timeout", event="no_timeout", goal=1, reward=10, tier=2, description="Finish match without timeout" },

}

return CATALOG
