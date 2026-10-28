-- Moteve Plates: predicted remaining damage of the player's own DoTs per enemy nameplate.
-- Casts and spell descriptions give the first estimate, UNIT_COMBAT ticks the real tick size. Health is never
-- read here except UnitHealthMax, which goes straight into the marker StatusBar: the client draws the result.
-- Tracking approach ported from swirllyman/DoesItDie (MIT, see LICENSE-DoesItDie.txt).
local _,ns=...
local Dots={}
ns.Dots=Dots
local PHYSICAL,FIRE,NATURE,SHADOW,ARCANE=1,4,8,32,64
-- Tick windows (s) either side of an expected tick; tighter once a tick has re-anchored the rhythm, so melee
-- white hits (Physical, ~1s rhythm) don't pass as bleed ticks. Projectiles may tick up to TRAVEL later.
local WINDOW,WINDOW_ANCHORED,TRAVEL=0.45,0.25,1.5
-- Physical DoTs are instant melee specials: their avoidance arrives with the cast, while white swings
-- (own or party) are avoided all the time, so only an avoidance within MELEE_MISS_WINDOW counts for them.
local MISS_WINDOW,MELEE_MISS_WINDOW,MISSED_TICKS_DROP,PENDING_TTL=1.5,0.3,2,5
local CRIT_MIN,CRIT_MAX=1.3,2.3
local MISS_ACTIONS={MISS=true,DODGE=true,PARRY=true,IMMUNE=true,RESIST=true,EVADE=true,DEFLECT=true,REFLECT=true}
local AGONY={0.5,0.5,0.5,0.5,1,1,1,1,1.5,1.5,1.5,1.5}
-- Rank spellIDs with their base durations (the last one repeats); finishers list durations per combo point.
local SPELLS={
    {name="Corruption",school=SHADOW,interval=3,ids={172,6222,6223,7648,11671,11672,25311},durations={12,15,18}},
    {name="Curse of Agony",alias="Bane of Agony",school=SHADOW,interval=2,ids={980,1014,6217,11711,11712,11713},durations={24},shape=AGONY},
    {name="Immolate",school=FIRE,interval=3,ids={348,707,1094,2941,11665,11667,11668,25309},durations={15}},
    {name="Siphon Life",school=SHADOW,interval=3,ids={18265,18879,18880,18881},durations={30}},
    {name="Shadow Word: Pain",school=SHADOW,interval=3,ids={589,594,970,992,2767,10892,10893,10894},durations={18}},
    {name="Devouring Plague",school=SHADOW,interval=3,ids={2944,19276,19277,19278,19279,19280},durations={24}},
    {name="Moonfire",school=ARCANE,interval=3,ids={8921,8924,8925,8926,8927,8928,8929,9833,9834,9835},durations={9,12}},
    {name="Insect Swarm",school=NATURE,interval=2,ids={5570,24974,24975,24976,24977},durations={12}},
    {name="Rake",school=PHYSICAL,interval=3,ids={1822,1823,1824,9904},durations={9}},
    {name="Rip",school=PHYSICAL,interval=2,ids={1079,9492,9493,9752,9894,9896},finisher={12,12,12,12,12}},
    {name="Rupture",school=PHYSICAL,interval=2,ids={1943,8639,8640,11273,11274,11275},finisher={8,10,12,14,16}},
    {name="Garrote",school=PHYSICAL,interval=3,ids={703,8631,8632,8633,11289,11290},durations={18}},
    {name="Serpent Sting",school=NATURE,interval=3,ids={1978,13549,13550,13551,13552,13553,13554,13555,25295},durations={15},travel=true},
    {name="Fireball",school=FIRE,interval=2,ids={133,143,145,3140,8400,8401,8402,10148,10149,10150,10151,25306},durations={4,6,6,8},travel=true},
    {name="Pyroblast",school=FIRE,interval=3,ids={11366,12505,12522,12523,12524,12525,12526,18809},durations={12},travel=true},
    {name="Flame Shock",school=FIRE,interval=3,ids={8050,8052,8053,10447,10448,29228},durations={12}},
    {name="Rend",school=PHYSICAL,interval=3,ids={772,6546,6547,6548,11572,11573,11574},durations={9,12,15,18,21}},
}
local byID,byName={},{}
for _,spell in ipairs(SPELLS) do
    for rank,id in ipairs(spell.ids) do
        local durations=spell.durations
        byID[id]={spell=spell,duration=durations and (durations[rank] or durations[#durations])}
    end
    byName[spell.name]=spell
    if spell.alias then byName[spell.alias]=spell end
end
Dots.SPELLS,Dots.SPELL_NAMES=byID,byName

-- Description patterns. "dt": duration then total, "td": total then duration; the last match wins, so mixed
-- spells (direct hit plus DoT) give their over-time part.
local PATTERNS={
    enUS={
        over={{"(%d[%d,]*)%s*[%a ]-%s*damage over (%d+%.?%d*) sec","td"}},
        every={"(%d[%d,]*) health.-every (%d+%.?%d*) sec","[Ll]asts (%d+%.?%d*) sec"},
        finisher="(%d)%s*points?%s*:%s*(%d[%d,]*)%s*damage over (%d+%.?%d*) sec",
    },
    huHU={
        over={{"(%d+%.?%d*)%s*mp alatt[^%d]-(%d+)%s*[^%s%d]*%s?sebz","dt"},{"(%d+%.?%d*)%s*másodperc alatt[^%d]-(%d+)%s*[^%s%d]*%s?sebz","dt"},
            {"(%d+)%s*[^%s%d]*%s?sebz[^%d]-(%d+%.?%d*)%s*mp alatt","td"},{"(%d+)%s*[^%s%d]*%s?sebz[^%d]-(%d+%.?%d*)%s*másodperc alatt","td"}},
        every={"(%d+)%s*életerő.-(%d+%.?%d*)%s*mp%-enként","Időtartam:%s*(%d+%.?%d*)%s*mp"},
        everyFirst="(%d+%.?%d*)%s*mp%-enként%s*(%d+)%s*életerő",
        finisher="(%d)%s*pont%s*:%s*(%d+)[^%d]-(%d+%.?%d*)%s*mp",
    },
}
local function Num(text) return tonumber((tostring(text):gsub(",",""))) end
local function Sets(locale)
    if locale=="huHU" then return {PATTERNS.huHU,PATTERNS.enUS} end
    return {PATTERNS.enUS,PATTERNS.huHU}
end
local function ParseWith(set,text)
    local total,duration
    for _,pattern in ipairs(set.over) do
        for a,b in text:gmatch(pattern[1]) do
            if pattern[2]=="td" then total,duration=Num(a),Num(b) else duration,total=Num(a),Num(b) end
        end
        if total then break end
    end
    if total and duration and total>0 and duration>0 then return total,duration end
    local amount,every=text:match(set.every[1])
    if set.everyFirst and not amount then every,amount=text:match(set.everyFirst) end
    local lasts=text:match(set.every[2])
    amount,every,lasts=amount and Num(amount),every and Num(every),lasts and Num(lasts)
    if amount and every and lasts and amount>0 and every>0 and lasts>0 then
        return amount*math.floor(lasts/every+0.5),lasts
    end
end
-- Total over-time damage and duration of a DoT description, or nil when it can't be read.
function Dots.ParseDescription(text,locale)
    if type(text)~="string" or text=="" then return nil end
    for _,set in ipairs(Sets(locale)) do
        local total,duration=ParseWith(set,text)
        if total then return total,duration end
    end
end
-- Total and duration for a finisher at `cp` combo points, from its per-combo-point description lines.
function Dots.FinisherTotal(spell,text,locale,cp)
    cp=tonumber(cp)
    if not spell or not spell.finisher or not cp or cp<1 or not spell.finisher[cp] or type(text)~="string" then return nil end
    for _,set in ipairs(Sets(locale)) do
        for points,total,duration in text:gmatch(set.finisher) do
            if tonumber(points)==cp then
                total,duration=Num(total),Num(duration)
                if total and duration and total>0 and duration>0 then return total,duration end
            end
        end
    end
end

local states,pending={},{}
local learned
Dots.states=states
local function HasSchool(mask,school)
    mask=tonumber(mask)
    return mask~=nil and math.floor(mask/school)%2==1
end
-- Factor of tick k (1 for even DoTs); shapes stretch to the DoT's tick count.
local function Weight(dot,k)
    local shape=dot.spell.shape
    if not shape then return 1 end
    local i=math.ceil(math.min(math.max(k,1),dot.n)/dot.n*#shape)
    return shape[math.max(1,math.min(i,#shape))]
end
-- Average tick and its size tolerance: this cast's ticks, else a learned size, else the description.
local function TickSize(dot)
    if dot.normalTicks>0 then return dot.tickSum/dot.normalTicks,0.25,0.25 end
    local saved=dot.key and learned and ns.Number(learned[dot.key])
    if saved then return saved,0.3,0.3 end
    if dot.base then return dot.base,0.3,2 end
end
local function InBand(dot,k,amount,critical)
    local size,below,above=TickSize(dot)
    if not size then return true end
    local expected=size*Weight(dot,k)
    if critical then return amount>=expected*CRIT_MIN and amount<=expected*CRIT_MAX end
    return amount>=expected*(1-below)-1 and amount<=expected*(1+above)+1
end
local function Window(dot,k)
    local early=dot.confirmed and WINDOW_ANCHORED or WINDOW
    local late=early+((not dot.confirmed and dot.spell.travel) and TRAVEL or 0)
    return dot.start+k*dot.spell.interval,early,late
end
local function Prune(token)
    local st=states[token]
    if st and next(st.dots)==nil then states[token]=nil end
end

-- A new DoT state for a cast of spellID at `now`, or nil for spells that aren't tracked.
-- Finishers with an unreadable combo point count use the lowest entry and teach no saved size.
function Dots.NewDot(spellID,text,locale,cp,now)
    local record=byID[spellID]
    if not record then return nil end
    local spell=record.spell
    local total,duration,key,points
    if spell.finisher then
        cp=tonumber(cp);cp=cp and math.floor(cp)
        points=cp and spell.finisher[cp] and cp or nil
        total,duration=Dots.FinisherTotal(spell,text,locale,points or 1)
        duration=duration or spell.finisher[points or 1]
        key=points and (spellID..":"..points) or nil
    else
        total,duration=Dots.ParseDescription(text,locale)
        duration=duration or record.duration
        key=spellID
    end
    local dot={spell=spell,id=spellID,key=key,cp=points,cast=now,start=now,landed=0,missed=0,normalTicks=0,tickSum=0}
    dot.n=math.max(1,math.floor(duration/spell.interval+0.5))
    if total then
        local weights=0
        for k=1,dot.n do weights=weights+Weight(dot,k) end
        dot.base=total/weights
    end
    return dot
end
-- Tracks a successful cast on a nameplate token; a recast of the same spell replaces its state.
function Dots.Start(token,spellID,text,locale,cp,now)
    local dot=Dots.NewDot(spellID,text,locale,cp,now)
    if not dot then return nil end
    local st=states[token] or {dots={}}
    states[token]=st
    st.dots[dot.spell.name]=dot
    return dot
end
-- Moves expected ticks that passed unseen into the past; two missed ticks in a row drop the DoT.
function Dots.Advance(token,now)
    local st=states[token]
    if not st then return end
    for name,dot in pairs(st.dots) do
        while dot.landed<dot.n do
            local expected,_,late=Window(dot,dot.landed+1)
            if now<=expected+late then break end
            dot.landed=dot.landed+1;dot.missed=dot.missed+1
            if dot.missed>=MISSED_TICKS_DROP then st.dots[name]=nil;break end
        end
        if st.dots[name] and dot.landed>=dot.n and now>dot.start+(dot.n+1)*dot.spell.interval+WINDOW then st.dots[name]=nil end
    end
    if st.cleanAt and now>=st.cleanAt then st.ambiguous,st.cleanAt=nil,nil end
    Prune(token)
end
-- Matches one hit to at most one DoT by school, tick rhythm and size. Returns "match", "ambiguous" or nil.
function Dots.MatchTick(token,amount,school,critical,now)
    Dots.Advance(token,now)
    local st=states[token]
    if not st then return nil end
    local best,bestK,bestScore
    for _,dot in pairs(st.dots) do
        local k=dot.landed+1
        if HasSchool(school,dot.spell.school) and (k<=dot.n or dot.confirmed) and InBand(dot,k,amount,critical) then
            local expected,early,late=Window(dot,k)
            if now>=expected-early and now<=expected+late then
                local size=TickSize(dot)
                local score=math.abs(now-expected)+(size and math.abs(amount-size*Weight(dot,k))/(size*Weight(dot,k)) or 0.5)
                if not best or score<bestScore then best,bestK,bestScore=dot,k,score end
            end
        end
    end
    if best then
        local dot,k=best,bestK
        if k>dot.n then dot.n=k end
        dot.looseTick=TickSize(dot)==nil
        dot.landed,dot.missed,dot.confirmed=k,0,true
        dot.start=now-k*dot.spell.interval;dot.lastTick=now
        if not critical then
            local size=amount/Weight(dot,k)
            dot.normalTicks,dot.tickSum=dot.normalTicks+1,dot.tickSum+size
            if dot.key and learned then learned[dot.key]=size end
        end
        if st.ambiguous then st.cleanAt=now+WINDOW end
        return "match"
    end
    -- A second fitting hit in a window already taken: someone else's damage looks like ours.
    for _,dot in pairs(st.dots) do
        if dot.lastTick and HasSchool(school,dot.spell.school) and math.abs(now-dot.lastTick)<=WINDOW
            and (dot.looseTick or InBand(dot,dot.landed,amount,critical)) then
            st.ambiguous,st.cleanAt=true,nil
            return "ambiguous"
        end
    end
end
-- An avoided cast: drops the newest unconfirmed DoT cast within MISS_WINDOW in a matching school.
-- Dodges and parries are melee outcomes, so they only count against Physical DoTs, and for those only
-- within MELEE_MISS_WINDOW of the cast.
function Dots.Miss(token,action,school,now)
    local st=states[token]
    if not st or not MISS_ACTIONS[action] then return false end
    local melee=action=="DODGE" or action=="PARRY"
    local mask=tonumber(school)
    local newest,newestName
    for name,dot in pairs(st.dots) do
        local window=dot.spell.school==PHYSICAL and MELEE_MISS_WINDOW or MISS_WINDOW+(dot.spell.travel and TRAVEL or 0)
        if not dot.confirmed and now-dot.cast<=window and (not melee or dot.spell.school==PHYSICAL)
            and (not mask or mask==0 or HasSchool(mask,dot.spell.school)) and (not newest or dot.cast>newest.cast) then
            newest,newestName=dot,name
        end
    end
    if not newest then return false end
    st.dots[newestName]=nil
    Prune(token)
    return true
end
-- Dispatches one readable UNIT_COMBAT event for a tracked token.
function Dots.Combat(token,action,flag,amount,school,now)
    if action=="WOUND" then
        amount=tonumber(amount)
        if not amount or amount<=0 then return nil end
        return Dots.MatchTick(token,amount,school,flag=="CRITICAL",now)
    end
    if Dots.Miss(token,action,school,now) then return "drop" end
end
-- Remaining predicted damage on a token, and whether it is hidden because the ticks are ambiguous.
function Dots.Remaining(token,now)
    Dots.Advance(token,now)
    local st=states[token]
    if not st then return 0 end
    if st.ambiguous then return 0,true end
    local total=0
    for _,dot in pairs(st.dots) do
        local size=TickSize(dot)
        if size then
            for k=dot.landed+1,dot.n do total=total+size*Weight(dot,k) end
        end
    end
    return total
end
function Dots.Clear(token)
    states[token]=nil
    for guid,cast in pairs(pending) do
        if cast.token==token then pending[guid]=nil end
    end
end
function Dots.ResetLearned()
    if not ns.db then return end
    ns.db.dotTicks={}
    learned=ns.db.dotTicks
end
-- dotTicks stays out of ns.defaults (the defaults loop would drop a table), so it is repaired here.
function Dots.InitLearned()
    if not ns.db then return end
    if type(ns.db.dotTicks)~="table" then ns.db.dotTicks={} end
    for key,value in pairs(ns.db.dotTicks) do
        local size=ns.Number(value)
        if (type(key)~="number" and type(key)~="string") or not size or size<=0 then ns.db.dotTicks[key]=nil end
    end
    learned=ns.db.dotTicks
end

local function Now() return ns.Number(ns.API(GetTime)) or 0 end
local function Readable(v) return not ns.Secret(v) and v or nil end
-- The first readable string of fn(spellID) for the given API functions.
local function SpellText(spellID,...)
    for i=1,select("#",...) do
        local text=ns.API(select(i,...),spellID)
        if ns.Secret(text) then return nil end
        if type(text)=="string" and text~="" then return text end
    end
end
function ns.UpdateDotMarker(f)
    local bar=f.dot
    if not bar then return end
    local remaining=0
    if ns.db and ns.db.enabled and ns.db.showDotPrediction and bar.reverseFill and f.unit then
        remaining=Dots.Remaining(f.unit,Now())
    end
    if remaining<=0 then bar:Hide();return end
    local maxHP=ns.API(UnitHealthMax,f.unit)
    if not pcall(bar.SetMinMaxValues,bar,0,maxHP) or not pcall(bar.SetValue,bar,remaining) then bar:Hide();return end
    bar:Show()
end
local function Refresh(token)
    local f=ns.active[token]
    if f then ns.UpdateDotMarker(f) end
end
local function TargetToken()
    for token in pairs(ns.active) do
        if ns.Bool(ns.API(UnitIsUnit,"target",token))==true then return token end
    end
end
local handlers={}
function handlers.UNIT_SPELLCAST_SENT(unit,targetName,castGUID,spellID)
    if Readable(unit)~="player" then return end
    local now=Now()
    for guid,cast in pairs(pending) do
        if now-cast.at>PENDING_TTL then pending[guid]=nil end
    end
    spellID=ns.Number(spellID)
    if not spellID or ns.Secret(castGUID) or type(castGUID)~="string" then return end
    if not byID[spellID] and not byName[SpellText(spellID,C_Spell and C_Spell.GetSpellName,GetSpellInfo) or ""] then return end
    local token=TargetToken()
    if not token then return end
    -- A cast sent at another named unit (mouseover or focus macros) isn't on the target's plate.
    local current=Readable(ns.API(UnitName,"target"))
    targetName=Readable(targetName)
    if type(targetName)=="string" and targetName~="" and type(current)=="string" and current~=targetName then return end
    local cp=ns.Number(ns.API(GetComboPoints,"player","target")) or ns.Number(ns.API(UnitPower,"player",4))
    pending[castGUID]={token=token,cp=cp,at=now}
end
function handlers.UNIT_SPELLCAST_SUCCEEDED(unit,castGUID,spellID)
    if Readable(unit)~="player" or ns.Secret(castGUID) or type(castGUID)~="string" then return end
    local cast=pending[castGUID]
    pending[castGUID]=nil
    spellID=ns.Number(spellID)
    if not cast or not spellID or not ns.active[cast.token] then return end
    if not byID[spellID] then
        local spell=byName[SpellText(spellID,C_Spell and C_Spell.GetSpellName,GetSpellInfo) or ""]
        if not spell then return end
        byID[spellID]={spell=spell,duration=spell.durations and spell.durations[#spell.durations]}
    end
    local text=SpellText(spellID,C_Spell and C_Spell.GetSpellDescription,GetSpellDescription)
    local locale=Readable(ns.API(GetLocale))
    Dots.Start(cast.token,spellID,text,type(locale)=="string" and locale or nil,cast.cp,Now())
    Refresh(cast.token)
end
function handlers.UNIT_COMBAT(unit,action,flag,amount,school)
    if ns.Secret(unit) or type(unit)~="string" or not ns.active[unit] or not states[unit] then return end
    if ns.Secret(action) or type(action)~="string" or ns.Secret(flag) then return end
    if action=="WOUND" and not ns.Number(amount) then return end
    school=ns.Number(school)
    if Dots.Combat(unit,action,type(flag)=="string" and flag or "",ns.Number(amount),school,Now()) then Refresh(unit) end
end
local EVENTS={"UNIT_SPELLCAST_SENT","UNIT_SPELLCAST_SUCCEEDED","UNIT_COMBAT"}
local frame,registered
-- Events are registered only while both the addon and the prediction are on; off wipes every state.
function Dots.Sync()
    local on=ns.db and ns.db.enabled and ns.db.showDotPrediction
    if on then
        if not frame then
            frame=CreateFrame("Frame")
            frame:SetScript("OnEvent",function(_,event,...) ns.Safe("dots",handlers[event],...) end)
        end
        if not registered then
            for i,event in ipairs(EVENTS) do
                local unitEvent=i<3 and frame.RegisterUnitEvent and pcall(frame.RegisterUnitEvent,frame,event,"player")
                if not unitEvent then pcall(frame.RegisterEvent,frame,event) end
            end
            registered=true
        end
        return
    end
    if frame and registered then
        for _,event in ipairs(EVENTS) do pcall(frame.UnregisterEvent,frame,event) end
    end
    registered=false
    for token in pairs(states) do states[token]=nil end
    for guid in pairs(pending) do pending[guid]=nil end
    for _,f in pairs(ns.active or {}) do if f.dot then f.dot:Hide() end end
end
ns:On("MP_INIT",function() Dots.InitLearned();Dots.Sync() end)
