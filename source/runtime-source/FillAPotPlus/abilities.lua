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
        C.abilities.allow('FillAPotPlus', (S.editing() or S.rules().extras) and lists or nil)
    end
    -- (outside Fill a Pot+ nothing stays unlocked)
    C.on_session(function() if not S.active() then C.abilities.allow('FillAPotPlus', nil) end end)
end
