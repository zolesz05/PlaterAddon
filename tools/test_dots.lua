-- Plain-Lua tests for MotevePlates/Dots.lua (Lua 5.1 or later), run from the repository root:
--   lua tools/test_dots.lua
-- Dots.lua is loaded against a stub `ns`; WoW globals are stubbed per case. Exits non-zero on any failure.
local root=(arg and arg[0] or ""):match("^(.-)[/\\]?tools[/\\][^/\\]+$") or "."
if root=="" then root="." end
local unpack=unpack or table.unpack
local SECRET=setmetatable({},{__tostring=function() return "<secret>" end})
local failures,count=0,0

local function NewNS()
    local ns={active={},errors={},handlers={}}
    function ns:On(event,fn)
        self.handlers[event]=self.handlers[event] or {}
        table.insert(self.handlers[event],fn)
    end
    function ns:Fire(event,...)
        for _,fn in ipairs(self.handlers[event] or {}) do fn(event,...) end
    end
    function ns.Safe(where,fn,...)
        local ok,err=pcall(fn,...)
        if not ok then ns.errors[#ns.errors+1]=where..": "..tostring(err) end
        return ok
    end
    function ns.Secret(v) return v==SECRET end
    function ns.Number(v)
        if v==SECRET or type(v)~="number" or v~=v or v==math.huge or v==-math.huge then return nil end
        return v
    end
    function ns.Bool(v) if v~=SECRET and type(v)=="boolean" then return v end end
    function ns.API(fn,...)
        if type(fn)~="function" then return nil end
        local results={pcall(fn,...)}
        if not results[1] then return nil end
        return unpack(results,2,#results)
    end
    return ns
end
local function Load(db,ns)
    ns=ns or NewNS()
    ns.db=db or {enabled=true,showDotPrediction=true,dotTicks={}}
    assert(loadfile(root.."/MotevePlates/Dots.lua"))("MotevePlates",ns)
    ns.Dots.InitLearned()
    return ns.Dots,ns
end
-- A stand-in for frames and textures: unknown methods are recorded no-ops.
local function Obj(fields)
    local o=fields or {}
    o.calls,o.shown=o.calls or {},o.shown or false
    return setmetatable(o,{__index=function(t,key)
        return function(self,...)
            t.calls[#t.calls+1]={key,...}
            if key=="Hide" then t.shown=false elseif key=="Show" then t.shown=true end
        end
    end})
end
local function Bar()
    local bar={shown=false,reverseFill=true}
    function bar:SetMinMaxValues(lo,hi)
        if self.failMinMax then error("blocked") end
        self.min,self.max=lo,hi
    end
    function bar:SetValue(v) self.value=v end
    function bar:Show() self.shown=true end
    function bar:Hide() self.shown=false end
    return bar
end
local function test(name,fn)
    count=count+1
    local ok,err=pcall(fn)
    if ok then print("ok   "..name) else failures=failures+1;print("FAIL "..name..": "..tostring(err)) end
end
local function eq(actual,expected,what)
    if actual~=expected then error((what or "value")..": expected "..tostring(expected)..", got "..tostring(actual),2) end
end
local function near(actual,expected,what)
    if type(actual)~="number" or math.abs(actual-expected)>0.001 then
        error((what or "value")..": expected "..tostring(expected)..", got "..tostring(actual),2)
    end
end

local SHADOW,FIRE,NATURE,PHYSICAL=32,4,8,1
local CORRUPTION,AGONY,SIPHON,SWP,RUPTURE,RIP,REND=25311,11713,18881,10894,11275,9896,11574
-- Forever's enUS tooltips (max ranks) and huHU wording for the same spells.
local EN={
    Corruption="Corrupts the target, causing 438 Shadow damage over 18 sec.",
    ["Shadow Word: Pain"]="A word of darkness that causes 762 Shadow damage over 18 sec.",
    Moonfire="Burns the enemy for 124 to 146 Arcane damage and then an additional 240 Arcane damage over 12 sec.",
    Garrote="Garrote the enemy, causing 552 damage over 18 sec, increased by your Attack Power. Must be stealthed and behind the target. Awards 1 combo points.",
    ["Serpent Sting"]="Stings the target, causing 555 Nature damage over 15 sec. Only one Sting per Hunter can be active on any one target.\n\nRequires Ranged Weapon",
    Fireball="Hurls a fiery ball that causes 425 to 541 Fire damage and an additional 60 Fire damage over 8 sec.",
    ["Flame Shock"]="Instantly sears the target with fire, causing 166 Fire damage immediately and 176 Fire damage over 12 sec.",
    Rend="Wounds the target causing them to bleed for 147 damage over 21 sec.\n\nRequires Melee Weapon",
    ["Siphon Life"]="Transfers 41 health from the target to the caster every 3 sec. Lasts 30 sec.",
    ["Bane of Agony"]="Afflicts the target with agony, causing 552 Shadow damage over 24 sec. This damage is dealt slowly at first, and builds up as the Bane reaches its full duration.",
    Rupture="Finishing move that causes damage over time, increased by your Attack Power. Lasts longer per combo point:\n1 point : 159 damage over 8 secs\n2 points: 222 damage over 10 secs\n3 points: 295 damage over 12 secs\n4 points: 377 damage over 14 secs\n5 points: 469 damage over 16 secs\n\nRequires Melee Weapon",
    Rip="Finishing move that causes damage over time. Damage increases per combo point and by your Attack Power:\n1 point : 243 damage over 12 sec.\n2 points: 396 damage over 12 sec.\n3 points: 549 damage over 12 sec.\n4 points: 702 damage over 12 sec.\n5 points: 855 damage over 12 sec.",
}
local HU={
    Corruption="Megrontja a célpontot, ami 18 mp alatt 438 árnyéksebzést okoz.",
    ["Shadow Word: Pain"]="A sötétség szava, ami 18 mp alatt 762 árnyéksebzést okoz.",
    Moonfire="124–146 arkán sebzéssel égeti meg az ellenséget, majd további 240 arkán sebzést okoz 12 mp alatt.",
    Garrote="Megfojtja az ellenfelet, ami 18 mp alatt 552 sebzést okoz, a támadóerővel növelve. Csak lopakodva, a célpont mögül használható. 1 kombópontot ad.",
    ["Serpent Sting"]="Megcsípi a célpontot, ami 15 mp alatt 555 természetsebzést okoz. Vadászonként egyszerre csak egy csípés lehet aktív egy célponton.",
    Fireball="Tűzgolyót hajít, ami 425–541 tűzsebzést okoz, valamint további 60 tűzsebzést 8 mp alatt.",
    ["Flame Shock"]="Azonnal tűzzel égeti a célpontot: 166 tűzsebzést okoz azonnal, majd 12 mp alatt további 176 tűzsebzést.",
    Rend="Megsebzi a célpontot, ami vérezni kezd, és 21 mp alatt 147 sebzést szenved el.",
    ["Siphon Life"]="3 mp-enként 41 életerőt szív el a célponttól, és átadja a varázslónak. Időtartam: 30 mp.",
    Rupture="Befejező mozdulat, amely időben elnyújtott sebzést okoz, a támadóerővel növelve. Kombópontonként tovább tart:\n1 pont: 159 sebzés 8 mp alatt\n2 pont: 222 sebzés 10 mp alatt\n3 pont: 295 sebzés 12 mp alatt\n4 pont: 377 sebzés 14 mp alatt\n5 pont: 469 sebzés 16 mp alatt",
    Rip="Befejező mozdulat, amely időben elnyújtott sebzést okoz. A sebzés kombópontonként és a támadóerővel nő:\n1 pont: 243 sebzés 12 mp alatt.\n2 pont: 396 sebzés 12 mp alatt.\n3 pont: 549 sebzés 12 mp alatt.\n4 pont: 702 sebzés 12 mp alatt.\n5 pont: 855 sebzés 12 mp alatt.",
}
-- One DoT per class: Warlock, Priest, Druid, Rogue, Hunter, Mage, Shaman, Warrior; then extra wordings.
local PER_CLASS={
    {"Corruption",438,18},{"Shadow Word: Pain",762,18},{"Moonfire",240,12},{"Garrote",552,18},
    {"Serpent Sting",555,15},{"Fireball",60,8},{"Flame Shock",176,12},{"Rend",147,21},{"Siphon Life",410,30},
}

test("parse_enUS_per_class",function()
    local Dots=Load()
    for _,case in ipairs(PER_CLASS) do
        local total,duration=Dots.ParseDescription(EN[case[1]],"enUS")
        eq(total,case[2],case[1].." total");eq(duration,case[3],case[1].." duration")
    end
    local total,duration=Dots.ParseDescription(EN["Bane of Agony"],"enUS")
    eq(total,552,"Bane of Agony total");eq(duration,24,"Bane of Agony duration")
    eq(Dots.ParseDescription("Sends a shadowy bolt at the enemy, causing 253 to 283 Shadow damage.","enUS"),nil,"direct damage")
end)
test("parse_huHU_per_class",function()
    local Dots=Load()
    for _,case in ipairs(PER_CLASS) do
        local total,duration=Dots.ParseDescription(HU[case[1]],"huHU")
        eq(total,case[2],case[1].." total");eq(duration,case[3],case[1].." duration")
    end
    eq(Dots.ParseDescription("Árnyéklövedéket küld az ellenségre.","huHU"),nil,"unparseable")
    eq(Dots.ParseDescription("","huHU"),nil,"empty")
    eq(Dots.ParseDescription(nil,"huHU"),nil,"nil")
    eq(Dots.ParseDescription("Corrompt la cible et lui inflige 438 points de dégâts d'Ombre en 18 s.","frFR"),nil,"other locale")
    -- An English description on a huHU client still parses.
    eq(Dots.ParseDescription(EN.Corruption,"huHU"),438,"enUS text on huHU")
end)
test("finisher_combo_points",function()
    local Dots=Load()
    local rupture,rip=Dots.SPELLS[RUPTURE].spell,Dots.SPELLS[RIP].spell
    for _,case in ipairs({{rupture,1,159,8},{rupture,5,469,16},{rip,1,243,12},{rip,5,855,12}}) do
        for _,set in ipairs({{EN,"enUS"},{HU,"huHU"}}) do
            local total,duration=Dots.FinisherTotal(case[1],set[1][case[1].name],set[2],case[2])
            eq(total,case[3],set[2].." "..case[1].name.." "..case[2].." total")
            eq(duration,case[4],set[2].." "..case[1].name.." "..case[2].." duration")
        end
    end
    eq(Dots.FinisherTotal(rupture,EN.Rupture,"enUS",0),nil,"0 combo points")
    eq(Dots.FinisherTotal(rupture,EN.Rupture,"enUS",nil),nil,"unknown combo points")
    eq(Dots.FinisherTotal(rupture,EN.Rupture,"enUS",6),nil,"6 combo points")
    eq(Dots.FinisherTotal(Dots.SPELLS[CORRUPTION].spell,EN.Corruption,"enUS",1),nil,"not a finisher")
end)
test("match_school_rhythm_size",function()
    local Dots,ns=Load()
    Dots.Start("nameplate1",CORRUPTION,EN.Corruption,"enUS",nil,100) -- 6 ticks of 73 every 3s
    eq(Dots.MatchTick("nameplate1",73,FIRE,false,103),nil,"wrong school")
    eq(Dots.MatchTick("nameplate1",73,SHADOW,false,101.5),nil,"off rhythm")
    eq(Dots.MatchTick("nameplate1",400,SHADOW,false,103),nil,"off size")
    eq(Dots.MatchTick("nameplate1",90,SHADOW,false,103.1),"match","fitting tick")
    eq(ns.db.dotTicks[CORRUPTION],90,"learned size")
    eq(Dots.states.nameplate1.dots.Corruption.landed,1,"ticks landed")
    eq(Dots.MatchTick("nameplate1",90,SHADOW,false,106.5),nil,"outside the anchored window")
    -- Two Shadow DoTs ticking together: expected size picks the DoT.
    Dots.Clear("nameplate1");ns.db.dotTicks={};Dots.InitLearned()
    Dots.Start("nameplate2",CORRUPTION,EN.Corruption,"enUS",nil,200)
    Dots.Start("nameplate2",SWP,EN["Shadow Word: Pain"],"enUS",nil,200) -- 6 ticks of 127
    eq(Dots.MatchTick("nameplate2",127,SHADOW,false,203),"match","Shadow Word: Pain tick")
    eq(Dots.states.nameplate2.dots["Shadow Word: Pain"].landed,1,"SW:P took it")
    eq(Dots.states.nameplate2.dots.Corruption.landed,0,"Corruption still waiting")
    eq(Dots.MatchTick("nameplate2",73,SHADOW,false,203.05),"match","Corruption tick")
    eq(Dots.states.nameplate2.dots.Corruption.landed,1,"Corruption took it")
    eq(ns.db.dotTicks[SWP],127,"SW:P learned");eq(ns.db.dotTicks[CORRUPTION],73,"Corruption learned")
    eq(Dots.Combat("nameplate2","WOUND","CRITICAL",146,SHADOW,206),"match","critical tick matches")
    eq(ns.db.dotTicks[CORRUPTION],73,"critical tick is not learned")
end)
test("learned_size_and_estimate",function()
    local Dots,ns=Load()
    Dots.Start("nameplate1",CORRUPTION,EN.Corruption,"enUS",nil,0)
    near(Dots.Remaining("nameplate1",0),438,"parsed estimate")
    Dots.MatchTick("nameplate1",80,SHADOW,false,3)
    near(Dots.Remaining("nameplate1",3),400,"after first tick")
    for t=6,18,3 do eq(Dots.MatchTick("nameplate1",80,SHADOW,false,t),"match","tick at "..t) end
    near(Dots.Remaining("nameplate1",18),0,"expired")
    Dots.Start("nameplate1",CORRUPTION,EN.Corruption,"enUS",nil,30)
    near(Dots.Remaining("nameplate1",30),480,"learned size wins over the description")
    -- No description and nothing learned: tracked, contributes nothing until its first tick.
    Dots.Start("nameplate3",SWP,nil,"deDE",nil,0)
    near(Dots.Remaining("nameplate3",0),0,"unknown size")
    eq(Dots.MatchTick("nameplate3",120,SHADOW,false,3),"match","first tick of an unknown size")
    near(Dots.Remaining("nameplate3",3),600,"learned from the first tick")
    -- Finishers learn per combo point; an unreadable count teaches nothing.
    Dots.Start("nameplate4",RUPTURE,EN.Rupture,"enUS",5,0)
    near(Dots.Remaining("nameplate4",0),469,"5 point Rupture")
    Dots.MatchTick("nameplate4",70,PHYSICAL,false,2)
    eq(ns.db.dotTicks[RUPTURE..":5"],70,"learned per combo point")
    Dots.Start("nameplate5",RUPTURE,EN.Rupture,"enUS",SECRET,0)
    near(Dots.Remaining("nameplate5",0),159,"unknown combo points use the lowest entry")
    Dots.MatchTick("nameplate5",40,PHYSICAL,false,2)
    for key in pairs(ns.db.dotTicks) do
        if key~=CORRUPTION and key~=SWP and key~=RUPTURE..":5" then error("unexpected learned key "..tostring(key)) end
    end
    -- Agony ticks 0.5x, 1x, 1.5x the average (46).
    Dots.Start("nameplate6",AGONY,EN["Bane of Agony"],"enUS",nil,0)
    near(Dots.Remaining("nameplate6",0),552,"Agony estimate")
    eq(Dots.MatchTick("nameplate6",23,SHADOW,false,2),"match","small first Agony tick")
    near(Dots.Remaining("nameplate6",2),46*11.5,"Agony after one tick")
    eq(ns.db.dotTicks[AGONY],46,"Agony learns the average tick")
end)
test("drop_on_miss_or_immune",function()
    local Dots=Load()
    for _,action in ipairs({"MISS","IMMUNE","RESIST"}) do
        Dots.Start("nameplate1",CORRUPTION,EN.Corruption,"enUS",nil,0)
        eq(Dots.Combat("nameplate1",action,"",nil,SHADOW,0.4),"drop",action)
        eq(Dots.states.nameplate1,nil,action.." clears the token");near(Dots.Remaining("nameplate1",0.4),0,action.." remaining")
    end
    for _,action in ipairs({"DODGE","PARRY"}) do
        Dots.Start("nameplate1",REND,EN.Rend,"enUS",nil,0)
        eq(Dots.Combat("nameplate1",action,"",nil,PHYSICAL,0.3),"drop",action.." on a bleed")
        eq(Dots.states.nameplate1,nil,action.." clears the token")
    end
    Dots.Start("nameplate1",CORRUPTION,EN.Corruption,"enUS",nil,0)
    -- An avoided white swing after a bleed's cast leaves the bleed alone.
    for _,action in ipairs({"MISS","DODGE","PARRY"}) do
        Dots.Start("nameplate3",REND,EN.Rend,"enUS",nil,0)
        eq(Dots.Combat("nameplate3",action,"",nil,PHYSICAL,1),nil,action.." 1s after a bleed")
        eq(Dots.states.nameplate3 and Dots.states.nameplate3.dots.Rend~=nil,true,action.." keeps the bleed")
        Dots.Clear("nameplate3")
    end
    Dots.Start("nameplate3",RUPTURE,EN.Rupture,"enUS",5,0)
    eq(Dots.Combat("nameplate3","MISS","",nil,PHYSICAL,1),nil,"MISS 1s after Rupture")
    near(Dots.Remaining("nameplate3",1),469,"Rupture kept")
    Dots.Clear("nameplate3")
    eq(Dots.Combat("nameplate1","DODGE","",nil,PHYSICAL,0.3),nil,"a dodge is not a Shadow DoT's miss")
    eq(Dots.Combat("nameplate1","MISS","",nil,SHADOW,2),nil,"miss after the window")
    Dots.MatchTick("nameplate1",73,SHADOW,false,3)
    eq(Dots.Combat("nameplate1","IMMUNE","",nil,SHADOW,3.2),nil,"immune after a confirmed tick")
    near(Dots.Remaining("nameplate1",3.2),365,"still tracked")
    -- Two casts back to back: only the newest unconfirmed one is dropped.
    Dots.Start("nameplate2",CORRUPTION,EN.Corruption,"enUS",nil,10)
    Dots.Start("nameplate2",SIPHON,EN["Siphon Life"],"enUS",nil,10.5)
    eq(Dots.Combat("nameplate2","RESIST","",nil,SHADOW,10.8),"drop","resist")
    eq(Dots.states.nameplate2.dots["Siphon Life"],nil,"newest dropped")
    eq(Dots.states.nameplate2.dots.Corruption~=nil,true,"older kept")
end)
test("drop_after_two_missed_ticks",function()
    local Dots=Load()
    Dots.Start("nameplate1",CORRUPTION,EN.Corruption,"enUS",nil,0)
    near(Dots.Remaining("nameplate1",3.5),365,"one missed tick")
    near(Dots.Remaining("nameplate1",6.5),0,"two missed ticks")
    eq(Dots.states.nameplate1,nil,"dropped")
    -- A matched tick in between resets the count.
    Dots.Start("nameplate2",CORRUPTION,EN.Corruption,"enUS",nil,0)
    Dots.Remaining("nameplate2",3.5)
    eq(Dots.MatchTick("nameplate2",73,SHADOW,false,6),"match","second tick")
    near(Dots.Remaining("nameplate2",9.3),219,"third tick missed")
    eq(Dots.MatchTick("nameplate2",73,SHADOW,false,12),"match","fourth tick")
    near(Dots.Remaining("nameplate2",12),146,"still tracked")
end)
test("ambiguous_same_school_hides",function()
    local Dots=Load()
    Dots.Start("nameplate1",CORRUPTION,EN.Corruption,"enUS",nil,0)
    eq(Dots.MatchTick("nameplate1",73,SHADOW,false,3),"match","own tick")
    eq(Dots.MatchTick("nameplate1",73,FIRE,false,3.1),nil,"other school")
    eq(Dots.MatchTick("nameplate1",300,SHADOW,false,3.1),nil,"off band")
    eq(Dots.MatchTick("nameplate1",73,SHADOW,false,4.2),nil,"off window")
    near(Dots.Remaining("nameplate1",4.2),365,"not ambiguous yet")
    eq(Dots.MatchTick("nameplate1",75,SHADOW,false,6.1),"match","own second tick")
    eq(Dots.MatchTick("nameplate1",75,SHADOW,false,6.2),"ambiguous","second fitting hit")
    local remaining,ambiguous=Dots.Remaining("nameplate1",6.2)
    near(remaining,0,"hidden");eq(ambiguous,true,"ambiguous flag")
    eq(Dots.MatchTick("nameplate1",74,SHADOW,false,9.1),"match","later clean tick")
    near(Dots.Remaining("nameplate1",9.2),0,"still hidden inside the window")
    local after,flag=Dots.Remaining("nameplate1",9.6)
    eq(flag,nil,"flag cleared");eq(after>0,true,"shown again")
    -- With no size known yet, any second same-school hit in the window is ambiguous.
    Dots.Start("nameplate2",SWP,nil,"deDE",nil,0)
    eq(Dots.MatchTick("nameplate2",100,SHADOW,false,3),"match","first unknown tick")
    eq(Dots.MatchTick("nameplate2",500,SHADOW,false,3.2),"ambiguous","second hit, no size yet")
end)

local registered,frames
local function StubCreateFrame()
    registered,frames={},{}
    CreateFrame=function()
        local frame={}
        function frame:RegisterUnitEvent(event,unit) registered[event]=unit end
        function frame:RegisterEvent(event) registered[event]="all" end
        function frame:UnregisterEvent(event) registered[event]=nil end
        function frame:SetScript(_,fn) self.script=fn end
        frames[#frames+1]=frame
        return frame
    end
end
test("sync_registers_only_when_both_on",function()
    StubCreateFrame()
    local db={enabled=true,showDotPrediction=false}
    local Dots,ns=Load(db)
    ns:Fire("MP_INIT")
    eq(next(registered),nil,"nothing registered while off")
    db.showDotPrediction=true
    ns:Fire("MP_INIT")
    eq(registered.UNIT_SPELLCAST_SENT,"player","SENT for player")
    eq(registered.UNIT_SPELLCAST_SUCCEEDED,"player","SUCCEEDED for player")
    eq(registered.UNIT_COMBAT,"all","UNIT_COMBAT")
    eq(#frames,1,"one frame")
    for _,combo in ipairs({{true,false},{false,true},{false,false}}) do
        db.enabled,db.showDotPrediction=true,true;Dots.Sync()
        local f={unit="nameplate1",dot=Bar()};f.dot.shown=true;ns.active.nameplate1=f
        Dots.Start("nameplate1",CORRUPTION,EN.Corruption,"enUS",nil,0)
        db.enabled,db.showDotPrediction=combo[1],combo[2];Dots.Sync()
        local label=tostring(combo[1]).."/"..tostring(combo[2])
        eq(next(registered),nil,label.." unregisters all")
        eq(next(Dots.states),nil,label.." wipes state")
        eq(f.dot.shown,false,label.." hides markers")
    end
    eq(#frames,1,"frame reused")
end)
test("update_marker_hides_when_off",function()
    local now=0
    GetTime=function() return now end
    local maxHP=5000
    UnitHealthMax=function() return maxHP end
    local Dots,ns=Load()
    local f={unit="nameplate1",dot=Bar()}
    ns.active.nameplate1=f
    ns.UpdateDotMarker(f);eq(f.dot.shown,false,"no state")
    Dots.Start("nameplate1",CORRUPTION,EN.Corruption,"enUS",nil,0)
    ns.UpdateDotMarker(f)
    eq(f.dot.shown,true,"shown");eq(f.dot.min,0,"min");eq(f.dot.max,5000,"max is UnitHealthMax");near(f.dot.value,438,"value")
    maxHP=SECRET
    ns.UpdateDotMarker(f);eq(f.dot.max,SECRET,"secret max passed through untouched");eq(f.dot.shown,true,"shown with secret max")
    ns.db.enabled=false;ns.UpdateDotMarker(f);eq(f.dot.shown,false,"addon off")
    ns.db.enabled,ns.db.showDotPrediction=true,false;ns.UpdateDotMarker(f);eq(f.dot.shown,false,"prediction off")
    ns.db.showDotPrediction=true;ns.UpdateDotMarker(f);eq(f.dot.shown,true,"back on")
    f.dot.failMinMax=true;ns.UpdateDotMarker(f);eq(f.dot.shown,false,"SetMinMaxValues failed")
    f.dot.failMinMax=nil;f.dot.reverseFill=false;ns.UpdateDotMarker(f);eq(f.dot.shown,false,"no reverse fill")
    f.dot.reverseFill=true;now=3;Dots.MatchTick("nameplate1",73,SHADOW,false,3);Dots.MatchTick("nameplate1",73,SHADOW,false,3.1)
    ns.UpdateDotMarker(f);eq(f.dot.shown,false,"ambiguous")
end)
test("clear_and_reset_learned",function()
    local Dots,ns=Load()
    Dots.Start("nameplate1",CORRUPTION,EN.Corruption,"enUS",nil,0)
    Dots.Start("nameplate2",CORRUPTION,EN.Corruption,"enUS",nil,0)
    Dots.Clear("nameplate1")
    eq(Dots.states.nameplate1,nil,"cleared");eq(Dots.states.nameplate2~=nil,true,"other token kept")
    Dots.MatchTick("nameplate2",80,SHADOW,false,3)
    eq(ns.db.dotTicks[CORRUPTION],80,"learned")
    Dots.ResetLearned()
    eq(next(ns.db.dotTicks),nil,"dotTicks emptied")
    Dots.Start("nameplate3",CORRUPTION,EN.Corruption,"enUS",nil,10)
    near(Dots.Remaining("nameplate3",10),438,"old size no longer used")
    ns.db.dotTicks="broken";Dots.InitLearned()
    eq(type(ns.db.dotTicks),"table","non-table repaired")
    ns.db.dotTicks={[CORRUPTION]=80,["11275:5"]=50,bad=-1,nan=0/0,huge=math.huge,text="12",[true]=3}
    Dots.InitLearned()
    eq(ns.db.dotTicks[CORRUPTION],80,"valid number key");eq(ns.db.dotTicks["11275:5"],50,"valid string key")
    local keys=0;for _ in pairs(ns.db.dotTicks) do keys=keys+1 end
    eq(keys,2,"invalid entries dropped")
    ns.db.dotTicks=nil
    StubCreateFrame()
    ns:Fire("MP_INIT")
    eq(type(ns.db.dotTicks),"table","MP_INIT creates dotTicks")
end)
test("detach_and_apply_options",function()
    StubCreateFrame()
    local Dots,ns=Load()
    ns.StopNativeAuras=function() end
    assert(loadfile(root.."/MotevePlates/Plates.lua"))("MotevePlates",ns)
    local f=Obj({unit="nameplate1",native=false,dot=Obj({shown=true}),questBadge=Obj(),cast=Obj({icon=Obj()}),raid=Obj(),auras={Obj()}})
    ns.active.nameplate1=f
    Dots.Start("nameplate1",CORRUPTION,EN.Corruption,"enUS",nil,0)
    ns.Detach("nameplate1")
    eq(Dots.states.nameplate1,nil,"Detach clears the token's DoTs")
    eq(f.dot.shown,false,"Detach hides the marker")
    eq(ns.active.nameplate1,nil,"plate released")
    registered={}
    ns.ApplyOptions()
    eq(registered.UNIT_COMBAT,"all","ApplyOptions syncs the DoT events")
    ns.db.showDotPrediction=false;ns.ApplyOptions()
    eq(next(registered),nil,"ApplyOptions unregisters when off")
end)

print(string.format("%d/%d passed",count-failures,count))
if failures>0 then os.exit(1) end
