-- The game's facts this mode asks, each from one place (audit 11-20): replication indices, round, team, lives.
return function(S)
    local C=S.C
    -- S.REP: the replication indices of the fields this mode writes or watches (C.replicate marks a field dirty by
    -- its index), by the class that owns the field: a number means something only with its class (52 is a
    -- player's IsTeamInitialized and the state's FilledCauldronColors). Was hand-copied numbers.
    S.REP={
        player={TEAM=21,SELECTED_TEAM=22,IS_DEAD=24,VOTED_MAP_INDEX=37,LIVES=49,OBJECTIVE_TEAM=50,IS_TEAM_INITIALIZED=52},
        state={GAMEMODE_DISPLAY_NAME=19,MAPS_TO_VOTE=36,CAULDRON_TARGET=46,MAX_LIVES=47,CURRENT_ROUND=49,
            REQUIRED_PLAYERS_PER_TEAM=51,FILLED_CAULDRON_COLORS=52},
        cauldron={STACKS=10,FILLED=12,VISUAL_CIRCLE_FILL=15},   -- (written every tick)
    }
    -- The round, two facts (audit 11-20). S.round(): the match's real round - the match manager's on the machine that
    -- runs the match, the game state's replicated copy on a guest (who has no manager). S.shownRound(): the round
    -- the players' screens show, the game state's on every machine - it differs from the real one only after
    -- Single round ends the match (gameplay.lua sets it to 2 while the manager keeps 1).
    function S.round() return S.host() and S.manager().CurrentRound or C.session().gs.CurrentRound end
    -- The match's team A/B (1, 2; 0 unassigned) of a player, two facts (audit 11-20). S.team(ps): the player's own,
    -- 0 before the player picks and for a watcher kept out of the match (rejoin.lua's quarantine zeroes it).
    -- S.rosterTeam(mps): the match manager's roster record of that player (ObjectiveMatchPlayerState), which
    -- outlives the player's connection and is what a returning player is given back; A/B do not swap at
    -- halftime (the round decides which team is the witches), so a kept record's team stays true.
    function S.team(ps) return ps.ObjectiveTeam end
    function S.rosterTeam(mps) return mps.ObjectiveTeam end
    function S.shownRound() return C.session().gs.CurrentRound end
    -- Infinite lives, asked of the rule (rules: a read of S.rules(), or the rules now) - the one reader (audit 11-20).
    -- The game's own fields (the state's MaxLives 0, a witch's Lives 99) are what the mod writes to make the game
    -- behave so (gameplay.lua), not a second place to ask.
    function S.infinite(rules) return (rules or S.rules()).lives=='infinite' end
end
