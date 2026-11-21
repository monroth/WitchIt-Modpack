return function(S)
    local R,C=S.R,S.C
    -- Every ability and power-up of the game (each class at its usual path in the game's folders).
    local function skills(team,names)
        local out={}
        for name in names:gmatch('%w+') do out[#out+1]=C.skill_class(team,name) end
        return out
    end
    local function pickups(team,names)
        local out={}
        for name in names:gmatch('%w+') do out[#out+1]=C.pickup_class(team,name) end
        return out
    end
    local lists={
        AllowedHunterSkills=skills('Hunter','Cannonball Chicken Garlic Hook Trap PowerBall Train'),
        AllowedWitchSkills=skills('Witch','Decoy Elixir Fly JumpScare Possess FlyingEye'),
        AllowedWitchPickups=pickups('Witch','ConfusionWave BuffInvisible BuffManaBoost Heal'),
        AllowedHunterPickups=pickups('Hunter','Detection BuffSpeedboost BuffRapidFire BuffCooldownReduction'),
    }
    -- With the Unlock abilities and power-ups rule the host allows every ability and power-up in the
    -- match (Core's allowed lists, sent to all players): the skill choice then offers them too, the
    -- Train (unlisted by the game) and Possess included.
    function S.allowSkills()
        local on = S.editing() or S.rules().extras
        C.state('FillAPotPlus', 'Unlocked abilities and power-ups', on and 'on' or 'off - the rule is off (and not in the editor)')
        C.abilities.allow('FillAPotPlus', on and lists or nil)
    end
    -- (on every machine: the rule is the one source, each game makes its own lists from it - a guest's too, which
    -- had only the game's; as the rules change and as a session begins)
    C.rules.on_change(function(pkg) if pkg == 'FillAPotPlus' and S.active() then S.allowSkills() end end)
    S.onMatch.session(function() S.allowSkills() end)
    -- (outside Fill a Pot+ nothing stays unlocked)
    C.on_session(function() if not S.active() then C.abilities.allow('FillAPotPlus', nil) end end)
end
