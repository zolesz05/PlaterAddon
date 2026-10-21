local _,ns=...
ns.active={}
local pool={}
local revision=0
local function IsForbidden(frame)
    return frame.IsForbidden and ns.Bool(ns.API(frame.IsForbidden,frame))~=false
end
local function NativeVisuals(f,hide)
    if not hide then
        if f.native then pcall(f.native.SetAlpha,f.native,f.nativeAlpha or 1) end
        f.native,f.nativeAlpha=nil,nil
        return true
    end
    local native=f.base.UnitFrame
    if not native or IsForbidden(native) then return false end
    if f.native~=native then
        NativeVisuals(f,false)
        f.native=native;f.nativeAlpha=ns.Number(ns.API(native.GetAlpha,native)) or 1
    end
    return pcall(native.SetAlpha,native,0)
end
function ns.Detach(unit)
    local f=ns.active[unit]
    if not f then return end
    NativeVisuals(f,false)
    ns.StopNativeAuras(f)
    f.questBadge:Hide();f.questRelevant=nil;f.questNextCheck=nil
    f.unit=nil;f.cast:Hide();f.cast.icon:Hide();f.raid:Hide()
    for _,a in ipairs(f.auras) do a:Hide();a.expiration=nil end
    f:Hide();ns.active[unit]=nil
end
local function Compact(n)
    if n>=1000000 then return string.format("%.1fm",n/1000000) end
    if n>=1000 then return string.format("%.2fk",n/1000) end
    return tostring(math.floor(n+0.5))
end
local function SetRawText(fs,text)
    if not pcall(fs.SetText,fs,text) then fs:SetText("?") end
end
local function SetFormatted(fs,pattern,value)
    if not pcall(fs.SetFormattedText,fs,pattern,value) then fs:SetText("?") end
end
local function Health(f)
    local hp,maxHP=ns.API(UnitHealth,f.unit),ns.API(UnitHealthMax,f.unit)
    local n,m=ns.Number(hp),ns.Number(maxHP)
    if not ns.Secret(maxHP) and (not m or m<=0) then maxHP=1;m=1 end
    if not ns.Secret(hp) and not n then hp=0;n=0 end
    pcall(f.health.SetMinMaxValues,f.health,0,maxHP)
    pcall(f.health.SetValue,f.health,hp)
    f.healthText:SetShown(ns.db.healthText);f.healthPct:SetShown(ns.db.healthPercent)
    if n then f.healthText:SetText(Compact(n)) else SetFormatted(f.healthText,"%d",hp) end
    if n and m then f.healthPct:SetText(string.format("%d%%",math.floor(n/m*100+0.5)))
    elseif UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
        local pct=ns.API(UnitHealthPercent,f.unit,true,CurveConstants.ScaleTo100)
        if ns.Secret(pct) or ns.Number(pct) then SetFormatted(f.healthPct,"%.0f%%",pct) else f.healthPct:SetText("?%") end
    else f.healthPct:SetText("?%") end
end
local function Cast(f)
    local bar=f.cast
    if not ns.db.showCast then bar:Hide();bar.icon:Hide();return end
    local name,_,icon,startMS,endMS,_,_,locked=ns.API(UnitCastingInfo,f.unit)
    local channel=false
    if not ns.Secret(name) and name==nil then
        name,_,icon,startMS,endMS,_,locked=ns.API(UnitChannelInfo,f.unit);channel=true
    end
    if not ns.Secret(name) and name==nil then bar:Hide();bar.icon:Hide();return end
    SetRawText(bar.name,name);pcall(bar.icon.SetTexture,bar.icon,icon)
    local interruptible=ns.Bool(locked)==false
    if interruptible then bar:SetStatusBarColor(0.95,0.70,0.12) else bar:SetStatusBarColor(0.54,0.57,0.64) end
    bar.channel=channel
    local start,finish=ns.Number(startMS),ns.Number(endMS)
    if start and finish and finish>start then
        local now=GetTime();start,finish=start/1000,finish/1000
        local remaining=math.max(0,finish-now)
        if remaining<=0 then bar:Hide();bar.icon:Hide();return end
        bar:SetMinMaxValues(0,finish-start)
        bar:SetValue(channel and remaining or math.max(0,now-start))
        bar.time:SetText(string.format("%.1fs",remaining))
    else
        bar:SetMinMaxValues(0,1);bar:SetValue(1);bar.time:SetText("")
        local duration=ns.API(channel and UnitChannelDuration or UnitCastingDuration,f.unit)
        if bar.SetTimerDuration and (ns.Secret(duration) or duration~=nil) then
            local direction=Enum and Enum.StatusBarTimerDirection and (channel and Enum.StatusBarTimerDirection.RemainingTime or Enum.StatusBarTimerDirection.ElapsedTime)
            if direction then pcall(bar.SetTimerDuration,bar,duration,nil,direction) else pcall(bar.SetTimerDuration,bar,duration) end
        end
    end
    bar:Show();bar.icon:Show()
end
local function AuraData(unit,i)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        return ns.API(C_UnitAuras.GetAuraDataByIndex,unit,i,"HARMFUL|PLAYER")
    end
    local name,icon,count,_,duration,expiration=ns.API(UnitAura,unit,i,"HARMFUL|PLAYER")
    if not ns.Secret(name) and name==nil then return nil end
    return {name=name,icon=icon,applications=count,duration=duration,expirationTime=expiration}
end
function ns.UpdateAuras(f)
    for _,a in ipairs(f.auras) do a:Hide();a.expiration=nil end
    if ns.UseNativeAuras(f) then return end
    if not ns.db.showAuras then return end
    for i,a in ipairs(f.auras) do
        if i>ns.db.maxAuras then break end
        local data=AuraData(f.unit,i)
        if ns.Secret(data) or type(data)~="table" then break end
        pcall(a.icon.SetTexture,a.icon,data.icon)
        local count=ns.Number(data.applications)
        a.count:SetText(count and count>1 and tostring(count) or "")
        local duration,expiration=ns.Number(data.duration),ns.Number(data.expirationTime)
        a.cooldown:Hide();a.timer:SetText("")
        if duration and expiration and duration>0 and expiration>0 then
            a.expiration=expiration
            a.cooldown:SetCooldown(expiration-duration,duration);a.cooldown:Show()
        end
        a:Show()
    end
end
local function Metadata(f)
    local name=ns.API(UnitName,f.unit)
    if ns.Secret(name) or name~=nil then SetRawText(f.name,name) else f.name:SetText("?") end
    local level=ns.Number(ns.API(UnitLevel,f.unit))
    local classification=ns.API(UnitClassification,f.unit)
    local elite=not ns.Secret(classification) and (classification=="elite" or classification=="rareelite" or classification=="worldboss")
    f.level:SetText(level and level>0 and (tostring(level)..(elite and "+" or "")) or "??")
    local raid=ns.Number(ns.API(GetRaidTargetIndex,f.unit))
    if raid and raid>=1 and raid<=8 then
        if SetRaidTargetIconTexture then SetRaidTargetIconTexture(f.raid,raid)
        else
            local col,row=(raid-1)%4,math.floor((raid-1)/4)
            f.raid:SetTexCoord(col/4,(col+1)/4,row/2,(row+1)/2)
        end
        f.raid:Show()
    else f.raid:Hide() end
end
function ns.UpdatePlate(f,auras)
    local unit=f.unit
    if not unit then return end
    if not ns.db.enabled or ns.Bool(ns.API(UnitExists,unit))~=true or ns.Bool(ns.API(UnitCanAttack,"player",unit))~=true or IsForbidden(f.base) then ns.Detach(unit);return end
    if not NativeVisuals(f,true) then f:Hide();return end
    if f.revision~=revision then ns.StylePlate(f,ns.db.skin);f.revision=revision end
    f:Show();Health(f);Metadata(f);Cast(f);ns.UpdateQuestMarker(f)
    local target=ns.Bool(ns.API(UnitIsUnit,unit,"target"))==true
    ns.TargetStyle(f,target,ns.Bool(ns.API(UnitExists,"target"))==true)
    local state,percent=ns.ReadThreat(unit)
    f.threatState=state
    local color=ns.db.colorThreat and state.color or ns.ThreatStates.neutral.color
    f.health:SetStatusBarColor(color[1],color[2],color[3])
    local visible=state.key~="neutral" and state.key~="tapped"
    f.threatText:SetText(ns.ThreatLabel(state,ns.GetRole()))
    f.threatText:SetTextColor(state.color[1],state.color[2],state.color[3])
    f.threatPct:SetTextColor(state.color[1],state.color[2],state.color[3])
    if ns.Secret(percent) then SetFormatted(f.threatPct,"%.0f%%",percent)
    elseif ns.Number(percent) then f.threatPct:SetText(string.format("%.0f%%",percent))
    else f.threatPct:SetText("") end
    ns.PlaceThreatText(f,visible)
    if auras then ns.UpdateAuras(f) end
    for _,a in ipairs(f.auras) do
        if a.expiration then a.timer:SetText(tostring(math.max(0,math.ceil(a.expiration-GetTime())))) end
    end
end
function ns.Attach(unit)
    if not ns.db or not ns.db.enabled or ns.Secret(unit) or type(unit)~="string" then return end
    if ns.Bool(ns.API(UnitCanAttack,"player",unit))~=true then return end
    local base=ns.API(C_NamePlate and C_NamePlate.GetNamePlateForUnit,unit)
    if not base or ns.Secret(base) or IsForbidden(base) then return end
    local f=pool[base]
    if not f then f=ns.CreatePlate(base);f.base=base;pool[base]=f end
    if f.unit and f.unit~=unit then ns.Detach(f.unit) end
    f.unit=unit;ns.active[unit]=f
    f:ClearAllPoints();f:SetPoint("CENTER",base,"CENTER",0,ns.db.offset)
    f.revision=nil
    ns.Safe("plate",ns.UpdatePlate,f,true)
    return f
end
function ns.RefreshAll()
    if not ns.db then return end
    for _,f in pairs(ns.active) do ns.Safe("plate",ns.UpdatePlate,f,true) end
    if not ns.db.enabled then return end
    local plates=ns.API(C_NamePlate and C_NamePlate.GetNamePlates)
    if type(plates)~="table" or ns.Secret(plates) then return end
    for _,base in ipairs(plates) do
        if not IsForbidden(base) then
            local unit=base.namePlateUnitToken or ns.API(base.GetUnit,base) or (base.UnitFrame and base.UnitFrame.unit)
            if not ns.Secret(unit) and type(unit)=="string" and not ns.active[unit] then ns.Attach(unit) end
        end
    end
end
function ns.ApplyOptions()
    revision=revision+1
    for _,f in pairs(ns.active) do
        f.questNextCheck=nil
        f:ClearAllPoints();f:SetPoint("CENTER",f.base,"CENTER",0,ns.db.offset)
    end
    ns.RefreshAll()
end
ns:On("NAME_PLATE_UNIT_ADDED",function(_,unit) ns.Attach(unit) end)
ns:On("NAME_PLATE_UNIT_REMOVED",function(_,unit) ns.Detach(unit) end)
ns:On("PLAYER_LOGIN",ns.RefreshAll)
for _,event in ipairs({"PLAYER_TARGET_CHANGED","UNIT_THREAT_LIST_UPDATE","UNIT_THREAT_SITUATION_UPDATE",
    "PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","PLAYER_ROLES_ASSIGNED","GROUP_ROSTER_UPDATE",
    "PLAYER_SPECIALIZATION_CHANGED","RAID_TARGET_UPDATE","UNIT_HEALTH","UNIT_MAXHEALTH","UNIT_NAME_UPDATE",
    "UNIT_FACTION","UNIT_TARGET","UNIT_SPELLCAST_START","UNIT_SPELLCAST_STOP","UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_DELAYED","UNIT_SPELLCAST_CHANNEL_START","UNIT_SPELLCAST_CHANNEL_STOP","UNIT_SPELLCAST_CHANNEL_UPDATE"}) do
    local global=event:sub(1,7)=="PLAYER_" or event=="GROUP_ROSTER_UPDATE" or event=="RAID_TARGET_UPDATE"
    local eventName=event
    ns:On(event,function(_,unit)
        if global then ns.RefreshAll()
        elseif unit and ns.active[unit] then ns.UpdatePlate(ns.active[unit],false)
        elseif eventName=="UNIT_THREAT_SITUATION_UPDATE" and unit=="player" then ns.RefreshAll() end
    end)
end
ns:On("UNIT_AURA",function(_,unit) if not ns.Secret(unit) and ns.active[unit] then ns.UpdateAuras(ns.active[unit]) end end)
local ticker=CreateFrame("Frame")
local elapsed,auraElapsed=0,0
ticker:SetScript("OnUpdate",function(_,dt)
    if not ns.db or not ns.db.enabled then return end
    elapsed=elapsed+dt;auraElapsed=auraElapsed+dt
    if elapsed<0.1 then return end
    elapsed=0
    local auras=auraElapsed>=0.4
    if auras then auraElapsed=0 end
    for _,f in pairs(ns.active) do ns.Safe("plate tick",ns.UpdatePlate,f,auras) end
end)
ns.ticker=ticker
