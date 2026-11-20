-- Mod shortcuts. Each has two slots, as in the game's own Key Bindings: a key and a spare. A slot
-- holds a chord (a key, with Ctrl, Shift and Alt as wanted; or Ctrl, Shift or Alt alone) or
-- 'Disabled'. A key that types a
-- character (a letter or a digit, without Ctrl or Alt) acts unless a text field has the keyboard
-- (in a menu too: the lobby's, where the game's own input sees no key). Keys come only while the
-- game's window is in front. A change of a chord is the event 'hotkeys'.
return function(R,controller,emit)
    local settings=R.settings('WitchItRuntime',{hotkeys={},spare={}})
    local bindings={}
    local capture
    function R.capture_hotkey(fn)
        capture=fn
        return function() if capture==fn then capture=nil end end
    end
    -- Key names (as chords spell them) -> virtual key codes, and codes -> the engine's key names.
    local names={SPACE=32,SPACEBAR=32,TAB=9,ENTER=13,ESCAPE=27,INSERT=45,DELETE=46,
        HOME=36,END=35,PAGEUP=33,PAGEDOWN=34,LEFTMOUSEBUTTON=1,RIGHTMOUSEBUTTON=2,MIDDLEMOUSEBUTTON=4,
        THUMBMOUSEBUTTON=5,THUMBMOUSEBUTTON2=6}
    local engine={[32]='SpaceBar',[9]='Tab',[13]='Enter',[27]='Escape',[45]='Insert',[46]='Delete',
        [36]='Home',[35]='End',[33]='PageUp',[34]='PageDown',[1]='LeftMouseButton',[2]='RightMouseButton',[4]='MiddleMouseButton',
        [5]='ThumbMouseButton',[6]='ThumbMouseButton2'}
    for name,code in pairs({BackSpace=8,Pause=19,CapsLock=20,Left=37,Up=38,Right=39,Down=40,
        LeftShift=160,RightShift=161,LeftControl=162,RightControl=163,LeftAlt=164,RightAlt=165,
        Semicolon=186,Equals=187,Comma=188,Hyphen=189,Period=190,Slash=191,Tilde=192,
        LeftBracket=219,Backslash=220,RightBracket=221,Apostrophe=222})do names[name:upper()]=code;engine[code]=name end
    for i,name in ipairs({'Zero','One','Two','Three','Four','Five','Six','Seven','Eight','Nine'})do
        names[name:upper()]=i+47;engine[i+47]=name
    end
    for i=48,90 do names[string.char(i)]=i end
    for i=65,90 do engine[i]=string.char(i) end
    for i=1,24 do names['F'..i]=111+i;engine[111+i]='F'..i end
    -- The modifiers: either side's key is the modifier (its generic code); its mask bit and name.
    local modifier={[16]=16,[160]=16,[161]=16,[17]=17,[162]=17,[163]=17,[18]=18,[164]=18,[165]=18}
    local MODIFIERS={{code=17,bit=2,name='Ctrl',keys={'LeftControl','RightControl'}},
        {code=16,bit=1,name='Shift',keys={'LeftShift','RightShift'}},{code=18,bit=4,name='Alt',keys={'LeftAlt','RightAlt'}}}
    local by_code={};for _,m in ipairs(MODIFIERS) do by_code[m.code]=m end
    -- The virtual key codes the mods read with R.native.key_down, named once (audit 11-20: the numbers
    -- were written in a dozen files).
    R.codes={LEFT_MOUSE=1,RIGHT_MOUSE=2,SHIFT=16,CTRL=17,ALT=18,ENTER=names.ENTER,ESCAPE=names.ESCAPE,DELETE=names.DELETE}
    local function parse(chord)
        if chord=='Disabled' then return nil end
        local code,mask=nil,0
        for part in chord:upper():gmatch('[^+]+') do
            if part=='CTRL' or part=='CONTROL' then mask=mask|2
            elseif part=='SHIFT' then mask=mask|1
            elseif part=='ALT' then mask=mask|4
            else code=names[part];if not code then return nil,nil,'Unknown key' end end
        end
        -- One modifier alone is its own key.
        if not code then for _,m in ipairs(MODIFIERS) do if mask==m.bit then code,mask=m.code,0 end end end
        if not code then return nil,nil,'Choose a key.' end
        return code,mask
    end
    -- F5 is the game's own key in every mode, bound where Key Bindings cannot see it: only the game's
    -- own action (a game key made rebindable, R.key about.game) may have it.
    local function owned(code,game) if code==116 and not game then return 'F5 belongs to the game.' end end
    -- The engine's names of a key (both sides of a modifier).
    local function engine_keys(code) return by_code[code] and by_code[code].keys or {engine[code]} end
    local function slot(chord,game)
        local code,mask,why=parse(chord);why=why or owned(code,game);assert(not why,why)
        return {chord=chord,code=code,mask=mask}
    end
    -- A chord's keys as the engine names them, in order (its modifiers, then its key), or nil for
    -- 'Disabled'.
    function R.chord_keys(chord)
        local code,mask=parse(chord)
        if not code then return nil end
        local keys={}
        for _,m in ipairs(MODIFIERS) do if mask&m.bit~=0 then keys[#keys+1]=m.keys[1] end end
        keys[#keys+1]=engine_keys(code)[1]
        return keys
    end
    -- The chord of a key press (a key code and its Ctrl/Shift/Alt mask), or nil for a key that
    -- has no name here. A modifier pressed alone is itself.
    function R.chord(code,mask)
        if modifier[code] then return by_code[modifier[code]].name end
        local name=code>=48 and code<=90 and string.char(code) or engine[code]
        if not name then return nil end
        return (mask&2~=0 and 'Ctrl+' or '')..(mask&1~=0 and 'Shift+' or '')..(mask&4~=0 and 'Alt+' or '')..name
    end
    -- A mod's shortcut: id, default chord, action, and what the Key Bindings list says about it
    -- (about={label=,context=,tip=,game=}; label: 2-4 words, tip: what it does in full; context: where
    -- it works, default Creative; game: the game's own
    -- key, made rebindable: on its default it shares the key with the game and with any shortcut),
    -- under the name of the mod that made it. The spare slot starts empty.
    function R.key(id,chord,fn,about)
        local current=settings.hotkeys[id] or chord
        settings.hotkeys[id]=current
        bindings[id]={id=id,mod=R.mod_name(R.owner()),label=about.label,tip=about.tip,context=about.context or 'Creative',
            default=chord,game=about.game==true,fn=fn,slots={slot(current,about.game),slot(settings.spare[id] or 'Disabled',about.game)}}
    end
    -- How texts show a shortcut's key: "[G]", "[-]" without one.
    function R.key_label(id)
        local b=bindings[id];local chord=b and b.slots[1].chord or 'Disabled'
        return '['..(chord=='Disabled' and '-' or chord)..']'
    end
    function R.hotkeys()
        local rows={}
        for _,b in pairs(bindings) do
            rows[#rows+1]={id=b.id,mod=b.mod,label=b.label,tip=b.tip,context=b.context,default=b.default,game=b.game,
                current=b.slots[1].chord,spare=b.slots[2].chord}
        end
        table.sort(rows,function(a,b) return a.id<b.id end);return rows
    end
    -- index: 1 the key (default), 2 the spare. A chord may be one other shortcuts use too: the
    -- player decides (R.hotkey_conflicts shows them).
    function R.set_hotkey(id,chord,index)
        index=index or 1
        local b=assert(bindings[id],'Unknown hotkey')
        local code,mask,why=parse(chord);why=why or owned(code,b.game);if why then return false,why end
        b.slots[index]={chord=chord,code=code,mask=mask}
        if index==1 then settings.hotkeys[id]=chord else settings.spare[id]=chord~='Disabled' and chord or nil end
        R.save_settings('WitchItRuntime');emit('hotkeys');return true
    end
    -- The slots whose chord another slot uses where both work (the same context): id -> {index=true}.
    -- (a game's own key on its default is shared by design)
    function R.hotkey_conflicts()
        local out={}
        local function shared(b,s) return b.game and s.chord==b.default end
        for id,b in pairs(bindings) do
            for i,s in ipairs(b.slots) do
                for other,row in pairs(bindings) do
                    for j,t in ipairs(row.slots) do
                        if (other~=id or j~=i) and s.code and row.context==b.context and t.code==s.code and t.mask==s.mask
                            and not shared(b,s) and not shared(row,t) then
                            out[id]=out[id] or {};out[id][i]=true
                        end
                    end
                end
            end
        end
        return out
    end
    -- Is a slot's chord held now (an action done while its key is held)? Read from the keyboard
    -- itself, as the presses are: in Creative the edit screen's widgets take keys before the
    -- player's input sees them.
    function R.key_held(id)
        for _,s in ipairs(bindings[id].slots) do
            if s.code and R.native.key_down(s.code) then
                local all=true
                for _,m in ipairs(MODIFIERS) do if s.mask&m.bit~=0 and not R.native.key_down(m.code) then all=false end end
                if all then return true end
            end
        end
        return false
    end
    local function types(code,mask) return mask&6==0 and (code>=48 and code<=57 or code>=65 and code<=90) end
    local function typing()
        for _,class in ipairs({'EditableTextBox','EditableText','MultiLineEditableTextBox','MultiLineEditableText'}) do
            for _,field in ipairs(FindAllOf(class) or {}) do if field:HasKeyboardFocus() then return true end end
        end
        return false
    end
    R.native.on_input(function(code,mask)
        if capture then capture(code,mask);return end
        local player=controller()
        if not player then return end
        -- A modifier key is its generic key, whatever its own bit in the mask.
        if modifier[code] then code,mask=modifier[code],0 end
        for _,binding in pairs(bindings) do
            for _,s in ipairs(binding.slots) do
                if code==s.code and mask==s.mask then
                    if not types(code,mask) or not typing() then R.call(binding.fn,s.chord) end
                    break
                end
            end
        end
    end)
end
