-- Moteve Plates: settings, event dispatch and secret-safe API adapters.
local ADDON,ns=...
ns.ADDON=ADDON
ns.MEDIA="Interface\\AddOns\\"..ADDON.."\\"
ns.WHITE="Interface\\Buttons\\WHITE8X8"
ns.errors={}
local reported,handlers={},{}
local eventFrame=CreateFrame("Frame")
local secret=issecretvalue or function() return false end
function ns.Secret(v) return secret(v) end
function ns.Number(v)
    if secret(v) or type(v)~="number" then return nil end
    if v~=v or v==math.huge or v==-math.huge then return nil end
    return v
end
function ns.Bool(v) if not secret(v) and type(v)=="boolean" then return v end end
function ns.API(fn,...)
    if type(fn)~="function" then return nil end
    local results={pcall(fn,...)}
    if not results[1] then return nil end
    return (unpack or table.unpack)(results,2,#results)
end
function ns.Safe(where,fn,...)
    local ok,err=pcall(fn,...)
    if not ok then
        local msg=where..": "..tostring(err)
        if not reported[msg] then
            reported[msg]=true;ns.errors[#ns.errors+1]=msg
            if #ns.errors>10 then table.remove(ns.errors,1) end
        end
    end
    return ok
end
function ns:On(event,fn)
    if not handlers[event] then
        handlers[event]={}
        if event:sub(1,3)~="MP_" then pcall(eventFrame.RegisterEvent,eventFrame,event) end
    end
    handlers[event][#handlers[event]+1]=fn
end
function ns:Fire(event,...)
    for _,fn in ipairs(handlers[event] or {}) do ns.Safe(event,fn,event,...) end
end
eventFrame:SetScript("OnEvent",function(_,event,...) ns:Fire(event,...) end)
function ns.Print(text) print("|cffa88bffMoteve Plates|r: "..text) end
ns.defaults={enabled=true,skin="moteve",role="auto",scale=1,width=190,height=17,offset=0,distance=40,
    showAggro=false,colorThreat=true,showThreatPercent=true,warningAt=85,
    healthText=true,healthPercent=true,showLevel=true,showCast=true,showAuras=true,maxAuras=8,dimOthers=true,showQuest=true,
    showDotPrediction=false,dotColor="skin"}
local ranges={scale={0.65,1.5},width={140,260},height={12,26},offset={-30,40},warningAt={50,95},distance={5,100},maxAuras={1,12}}
local skins={minimal=true,classic=true,moteve=true}
local roles={auto=true,tank=true,dps=true}
local function Validate(key,value)
    local default=ns.defaults[key]
    if default==nil then return nil end
    if ranges[key] then
        local number=ns.Number(value)
        if not number then return nil end
        if key=="maxAuras" then number=math.floor(number) end
        return math.max(ranges[key][1],math.min(ranges[key][2],number))
    elseif key=="skin" then return skins[value] and value or nil
    elseif key=="role" then return roles[value] and value or nil
    -- ns.DotColors comes from Skins.lua, which loads after this file; Validate only runs from ADDON_LOADED on.
    elseif key=="dotColor" then
        if value=="skin" or (type(value)=="string" and ns.DotColors and ns.DotColors[value]) then return value end
        return nil
    elseif type(value)=="boolean" then return value end
end
-- Use the native visibility distance; never fabricate nameplates outside engine range.
function ns.ReadDistance()
    local value=ns.API(C_CVar and C_CVar.GetCVar or GetCVar,"nameplateMaxDistance")
    if ns.Secret(value) then return nil end
    local number=ns.Number(tonumber(value))
    if number and number>0 then return number end
end
function ns.ApplyDistance()
    if not ns.db then return end
    ns.distancePending=false;ns.distanceFailure=nil
    local fn=C_CVar and C_CVar.SetCVar or SetCVar
    if type(fn)~="function" or not ns.ReadDistance() then
        ns.distanceFailure="A távolságbeállítás nem elérhető ezen a kliensen."
    elseif ns.API(InCombatLockdown) then
        ns.distancePending=true
    else
        local ok,result=pcall(fn,"nameplateMaxDistance",tostring(ns.db.distance))
        if not ok or result==false then ns.distanceFailure="A távolság módosítása sikertelen; a kliens nem engedélyezte." end
    end
    if ns.UpdateOptions then ns.UpdateOptions() end
end
function ns.DistanceStatus()
    local actual=ns.ReadDistance()
    local text=actual and string.format("Kliensbeállítás: %g yd.",actual) or "A távolság nem olvasható ki."
    if ns.distancePending then return text.." Alkalmazás harc után." end
    if ns.distanceFailure then return ns.distanceFailure.." "..text end
    if actual and ns.db and math.abs(actual-ns.db.distance)>0.01 then
        return text.." Eltérés: klienskorlát vagy külső módosítás."
    end
    return text
end
ns:On("PLAYER_LOGIN",ns.ApplyDistance)
ns:On("PLAYER_REGEN_ENABLED",function() if ns.distancePending then ns.ApplyDistance() end end)
function ns.SetOption(key,value)
    if not ns.db then return false end
    local validated=Validate(key,value)
    if validated==nil then return false end
    ns.db[key]=validated
    if key=="distance" then ns.ApplyDistance() end
    if ns.ApplyOptions then ns.ApplyOptions() end
    if ns.UpdateOptions then ns.UpdateOptions() end
    return true
end
ns:On("ADDON_LOADED",function(_,name)
    if name~=ADDON then return end
    if type(MotevePlatesDB)~="table" then MotevePlatesDB={} end
    ns.db=MotevePlatesDB
    if Validate("distance",ns.db.distance)==nil then
        ns.db.distance=ns.ReadDistance() or ns.defaults.distance
    end
    for key,default in pairs(ns.defaults) do
        local value=Validate(key,ns.db[key])
        if value==nil then value=default end
        ns.db[key]=value
    end
    ns:Fire("MP_INIT")
end)
function ns.GetRole()
    if ns.db and ns.db.role~="auto" then return ns.db.role end
    local role=ns.API(UnitGroupRolesAssigned,"player")
    if not secret(role) and role=="TANK" then return "tank" end
    if not secret(role) and (role=="HEALER" or role=="DAMAGER") then return "dps" end
    local spec=ns.Number(ns.API(GetSpecialization))
    if spec then
        role=ns.API(GetSpecializationRole,spec)
        if not secret(role) and role=="TANK" then return "tank" end
    end
    return "dps"
end
SLASH_MOTEVEPLATES1,SLASH_MOTEVEPLATES2="/mp","/mplates"
SlashCmdList.MOTEVEPLATES=function(input)
    if not ns.db then return end
    local cmd,arg=(input or ""):lower():match("^(%S*)%s*(%S*)")
    if cmd=="skin" then
        if not ns.SetOption("skin",arg) then ns.Print("/mp skin minimal|classic|moteve") end
    elseif cmd=="tank" then ns.SetOption("role","tank")
    elseif cmd=="dps" or cmd=="heal" then ns.SetOption("role","dps")
    elseif cmd=="auto" then ns.SetOption("role","auto")
    elseif cmd=="scale" then
        if not ns.SetOption("scale",tonumber(arg)) then ns.Print("/mp scale 0.85 (0.65–1.50)") end
    elseif cmd=="distance" then
        if ns.SetOption("distance",tonumber(arg)) then ns.Print(ns.DistanceStatus())
        else ns.Print("/mp distance 40 (5–100 yd, a kliens korlátain belül)") end
    elseif cmd=="on" then ns.SetOption("enabled",true)
    elseif cmd=="off" then ns.SetOption("enabled",false)
    elseif cmd=="auras" then
        ns.Print("Saját debuffok: "..(ns.db.showAuras and "bekapcsolva" or "kikapcsolva"))
        local count=0
        for unit,f in pairs(ns.active or {}) do
            count=count+1
            ns.Print(unit..": "..(f.auraContainer and "Blizzard AuraContainer" or "régi aura API"))
        end
        if count==0 then ns.Print("Nincs aktív ellenséges névtábla. Jelölj ki egy közeli ellenfelet.") end
    elseif cmd=="dotreset" then
        ns.Dots.ResetLearned()
        ns.Print("A tanult DoT-sebzésértékek törölve.")
    elseif cmd=="errors" then
        if #ns.errors==0 then ns.Print("Nincs rögzített hiba.") end
        for _,msg in ipairs(ns.errors) do ns.Print(msg) end
    else if ns.OpenOptions then ns.OpenOptions() end end
end
