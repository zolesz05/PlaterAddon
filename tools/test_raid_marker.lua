-- Plain-Lua tests for the raid target marker (Lua 5.1 or later), run from the repository root:
--   lua tools/test_raid_marker.lua
-- Part 1 loads Core.lua and Skins.lua against a stub CreateFrame whose frames record every method call and checks the
-- marker's own frame. Part 2 loads Core.lua and Plates.lua against stubs (GetRaidTargetIndex, issecretvalue, a fake
-- native UnitFrame with its RaidTargetFrame, a secret index that can be joined into a string) and drives
-- ns.UpdateRaidMarker, ns.UpdatePlate, ns.Detach and /mp raid.
-- Exits non-zero on any failure.
local root=(arg and arg[0] or ""):match("^(.-)[/\\]?tools[/\\][^/\\]+$") or "."
if root=="" then root="." end
local unpack=unpack or table.unpack
local SECRET=setmetatable({},{__tostring=function() return "<secret>" end})
-- A secret that fails loudly on any use the client forbids: text conversion, concatenation, comparison, length.
local function Forbidden() error("secret value used",2) end
local SECRET_THROW=setmetatable({},{__tostring=Forbidden,__concat=Forbidden,__eq=Forbidden,__lt=Forbidden,__le=Forbidden,__len=Forbidden})
-- A secret index as the client hands it out: forbidden like SECRET_THROW, except that joining it into a string is allowed
-- and gives a secret string (SECRET_PATH, itself unprintable). SECRET_PATH_FOR records the string it was joined to.
local SECRET_PATH=setmetatable({},{__tostring=Forbidden,__concat=Forbidden,__eq=Forbidden,__lt=Forbidden,__le=Forbidden,__len=Forbidden})
local SECRET_PATH_FOR
local SECRET_CONCAT=setmetatable({},{__tostring=Forbidden,__eq=Forbidden,__lt=Forbidden,__le=Forbidden,__len=Forbidden,
    __concat=function(a,b)
        if type(a)~="string" then error("secret joined to a non-string",2) end
        SECRET_PATH_FOR=a;return SECRET_PATH
    end})
local failures,count=0,0

-- A frame stub: any method (a capitalised key) is a no-op that records its call in frame.calls[method];
-- Show/Hide also track frame.shown. Unset lowercase fields stay nil.
local frameMethods={}
local function NewFrame(kind,parent,template)
    local frame={kind=kind,parent=parent,template=template,calls={},shown=true}
    return setmetatable(frame,{__index=function(t,key)
        if frameMethods[key] then return frameMethods[key] end
        if type(key)~="string" or not key:match("^%u") then return nil end
        return function(self,...)
            local list=self.calls[key] or {}
            self.calls[key]=list
            list[#list+1]={...}
            if key=="Show" then self.shown=true elseif key=="Hide" then self.shown=false end
        end
    end})
end
function frameMethods.CreateTexture(self) return NewFrame("Texture",self) end
function frameMethods.CreateFontString(self) return NewFrame("FontString",self) end
function frameMethods.GetFrameLevel() return 1 end
function frameMethods.IsShown(self) return self.shown end
function frameMethods.GetStatusBarTexture(self) return NewFrame("Texture",self) end
function CreateFrame(kind,name,parent,template) return NewFrame(kind,parent,template) end
SlashCmdList={}
issecretvalue=function(v) return rawequal(v,SECRET) or rawequal(v,SECRET_THROW) or rawequal(v,SECRET_CONCAT) or rawequal(v,SECRET_PATH) end

local function test(name,fn)
    count=count+1
    GetRaidTargetIndex,SetRaidTargetIconTexture=nil,nil
    local ok,err=pcall(fn)
    if ok then print("ok   "..name) else failures=failures+1;print("FAIL "..name..": "..tostring(err)) end
end
local function eq(actual,expected,what)
    if actual~=expected then error((what or "value")..": expected "..tostring(expected)..", got "..tostring(actual),2) end
end
-- The arguments of the last call to method on frame.
local function Last(frame,method)
    local calls=frame.calls[method]
    if not calls then error(method.." never called",2) end
    return unpack(calls[#calls])
end
local function Calls(frame,method) return frame.calls[method] and #frame.calls[method] or 0 end

-- Part 1: the marker's frame in ns.CreatePlate.
do
    local ns={}
    assert(loadfile(root.."/MotevePlates/Core.lua"))("MotevePlates",ns)
    assert(loadfile(root.."/MotevePlates/Skins.lua"))("MotevePlates",ns)
    test("skins_raid_holder_layout",function()
        local f=ns.CreatePlate(NewFrame("Frame"))
        local holder=f.raidHolder
        eq(type(holder),"table","f.raidHolder exists")
        eq(holder.kind,"Frame","holder is a frame")
        eq(holder.parent,f,"holder parent")
        eq(Last(holder,"EnableMouse"),false,"holder mouse")
        local w,h=Last(holder,"SetSize")
        eq(w,18,"holder width");eq(h,18,"holder height")
        local level=Last(holder,"SetFrameLevel")
        if type(level)~="number" or level<=f:GetFrameLevel()+5 then error("holder level "..tostring(level).." not above the aura container (+5)") end
        eq(level,11,"holder level with stub level 1")
        local point,rel,relPoint,x,y=Last(holder,"SetPoint")
        eq(point,"RIGHT","holder point");eq(rel,f,"holder relative frame");eq(relPoint,"LEFT","holder relative point")
        eq(x,-18,"holder x");eq(y,0,"holder y")
        eq(f.raid.kind,"Texture","f.raid is a texture")
        eq(f.raid.parent,holder,"f.raid lives on the holder")
        eq(Calls(f.raid,"SetAllPoints"),1,"f.raid fills the holder")
        eq(Last(f.raid,"SetTexture"),"Interface\\TargetingFrame\\UI-RaidTargetingIcons","marker texture")
        -- Horizontal clearance, in plate coordinates (the plate's left edge is x=0). The holder spans x -36..-18.
        local right=x
        -- Target arrow: its right edge sits at the plate's left edge plus its offset; leave room for the glyph overhang.
        local apoint,arel,arelPoint,ax=Last(f.targetLeft,"SetPoint")
        eq(apoint,"RIGHT","arrow point");eq(arel,f,"arrow relative");eq(arelPoint,"LEFT","arrow relative point")
        if right>ax-8 then error("holder right edge "..right.." within 8 px of the target arrow at "..ax) end
        -- Quest badge: right edge 3 px left of the name, which starts at the plate's left edge.
        local npoint,nrel,nrelPoint,nx=Last(f.name,"SetPoint")
        eq(npoint,"BOTTOMLEFT","name point");eq(nrel,f,"name relative");eq(nrelPoint,"TOPLEFT","name relative point")
        if right>nx then error("holder reaches the name row at "..nx) end
        local _,brel,_,bx=Last(f.questBadge,"SetPoint")
        eq(brel,f.name,"badge beside the name")
        local bw=Last(f.questBadge,"SetSize")
        local badgeLeft=nx+bx-bw
        eq(badgeLeft,-15,"badge left edge")
        if right>badgeLeft then error("holder right edge "..right.." overlaps the quest badge from "..badgeLeft) end
        for i,a in ipairs(f.auras) do
            if a==holder then error("holder is aura "..i) end
            local _,arel2,_,aurax=Last(a,"SetPoint")
            eq(arel2,f,"aura "..i.." relative")
            if right>aurax then error("aura "..i.." left edge "..aurax.." reaches the marker at "..right) end
        end
    end)
end

-- Part 2: ns.UpdateRaidMarker, its native fallback and the restore paths in Plates.lua.
local ns={}
assert(loadfile(root.."/MotevePlates/Core.lua"))("MotevePlates",ns)
ns.Dots={Clear=function() end}
ns.StopNativeAuras=function() end
ns.UseNativeAuras=function() return false end
assert(loadfile(root.."/MotevePlates/Combo.lua"))("MotevePlates",ns) -- TOC order: Plates.lua's Detach/UpdatePlate use the combo functions
assert(loadfile(root.."/MotevePlates/Plates.lua"))("MotevePlates",ns)

-- A fake Blizzard RaidTargetFrame: real anchors and ignore flag, every method call logged in rtf.log.
local function NativeRaid(opts)
    opts=opts or {}
    local rtf={log={},points={{"RIGHT",opts.anchor or "HealthBar","LEFT",-6,0}},ignore=false,level=3}
    local function log(name,...) rtf.log[#rtf.log+1]={name,...} end
    function rtf:GetFrameLevel() log("GetFrameLevel");if opts.secretLevel then return SECRET end;return self.level end
    function rtf:SetFrameLevel(v) log("SetFrameLevel",v);self.level=v end
    function rtf:GetNumPoints() log("GetNumPoints");if opts.badCount then return SECRET end;return #self.points end
    function rtf:GetPoint(i)
        log("GetPoint",i)
        if opts.secretPoint then return SECRET,nil,nil,0,0 end
        if opts.throwPoint then error("GetPoint blocked") end
        return unpack(self.points[i],1,5)
    end
    function rtf:ClearAllPoints() log("ClearAllPoints");self.points={} end
    function rtf:SetPoint(...)
        log("SetPoint",...)
        if opts.failSetPoint and select(2,...)~="HealthBar" then error("SetPoint blocked") end
        self.points[#self.points+1]={...}
    end
    if not opts.noIgnore then
        function rtf:IsIgnoringParentAlpha()
            log("IsIgnoringParentAlpha")
            if opts.throwIgnore then error("blocked") end
            if opts.secretIgnore then return SECRET end
            return self.ignore
        end
        function rtf:SetIgnoreParentAlpha(v) log("SetIgnoreParentAlpha",v);self.ignore=v end
    end
    if opts.forbidden then function rtf:IsForbidden() return true end end
    return rtf
end
-- Calls on the native frame that change it.
local function Writes(rtf)
    local n=0
    for _,entry in ipairs(rtf.log) do
        if entry[1]=="ClearAllPoints" or entry[1]=="SetPoint" or entry[1]=="SetIgnoreParentAlpha" then n=n+1 end
    end
    return n
end
local function UnitFrame(rtf)
    local uf={alpha=1,RaidTargetFrame=rtf}
    function uf:GetAlpha() return self.alpha end
    function uf:SetAlpha(a) self.alpha=a end
    return uf
end
-- A plate as ns.CreatePlate builds it, with the native UnitFrame already faded by NativeVisuals.
local function Plate(uf)
    local f=NewFrame("Frame")
    f.unit="nameplate1";f.raidHolder=NewFrame("Frame",f);f.raid=NewFrame("Texture",f.raidHolder);f.raid.shown=false
    f.questBadge=NewFrame("Frame",f);f.cast=NewFrame("StatusBar",f);f.cast.icon=NewFrame("Texture",f)
    f.dot=NewFrame("StatusBar",f);f.auras={NewFrame("Frame",f)}
    for _,key in ipairs({"name","level","health","healthText","healthPct","threatText","threatPct"}) do f[key]=NewFrame("Frame",f) end
    f.base={UnitFrame=uf}
    if uf then f.native=uf;f.nativeAlpha=uf.alpha;uf.alpha=0 end
    return f
end
local function Update(f)
    local ok,err=pcall(ns.UpdateRaidMarker,f)
    if not ok then error("UpdateRaidMarker raised: "..tostring(err),2) end
end
local function Index(v) GetRaidTargetIndex=function(unit) eq(unit,"nameplate1","unit");return v end end
local function ExpectCoords(f,i)
    local col,row=(i-1)%4,math.floor((i-1)/4)
    local l,r,t,b=Last(f.raid,"SetTexCoord")
    eq(l,col/4,i.." left");eq(r,(col+1)/4,i.." right");eq(t,row/2,i.." top");eq(b,(row+1)/2,i.." bottom")
end
local function ExpectBorrowed(f,rtf,what)
    eq(f.nativeRaid,rtf,what.." borrowed")
    eq(rtf.ignore,true,what.." ignores parent alpha")
    -- Two corners on the holder, so the borrowed frame takes the holder's size even if it had none of its own.
    eq(#rtf.points,2,what.." two anchors")
    for i,corner in ipairs({"TOPLEFT","BOTTOMRIGHT"}) do
        local p=rtf.points[i]
        eq(p[1],corner,what.." point "..i);eq(p[2],f.raidHolder,what.." anchored to the holder");eq(p[3],corner,what.." relative point "..i)
        eq(p[4],0,what.." x "..i);eq(p[5],0,what.." y "..i)
    end
end
local function ExpectOriginal(rtf,what)
    eq(#rtf.points,1,what.." anchor count")
    local p=rtf.points[1]
    eq(p[1],"RIGHT",what.." point");eq(p[2],"HealthBar",what.." relative");eq(p[3],"LEFT",what.." relative point")
    eq(p[4],-6,what.." x");eq(p[5],0,what.." y")
    eq(rtf.ignore,false,what.." ignore flag")
    eq(rtf.level,3,what.." frame level")
end

test("index_1_to_8_texcoords",function()
    local f=Plate(UnitFrame(NativeRaid()))
    eq(ns.Number(4),4,"plain numbers pass")
    for i=1,8 do
        Index(i);f.raid.shown=false;Update(f)
        eq(f.raid.shown,true,i.." shown");ExpectCoords(f,i)
        eq(f.raidStatus,"icon:"..i,i.." status")
    end
    local l,r,t,b=Last(f.raid,"SetTexCoord")
    eq(l,0.75,"8 left");eq(r,1,"8 right");eq(t,0.5,"8 top");eq(b,1,"8 bottom")
    Index(1);Update(f)
    l,r,t,b=Last(f.raid,"SetTexCoord")
    eq(l,0,"1 left");eq(r,0.25,"1 right");eq(t,0,"1 top");eq(b,0.5,"1 bottom")
    eq(f.nativeRaid,nil,"plain numbers never borrow the native marker")
    eq(Writes(f.native.RaidTargetFrame),0,"native marker untouched")
end)

test("uses_blizzard_helper_when_present",function()
    local f=Plate(UnitFrame(NativeRaid()))
    local seen
    SetRaidTargetIconTexture=function(tex,i) seen={tex,i} end
    Index(6);Update(f)
    eq(seen and seen[1],f.raid,"helper texture");eq(seen and seen[2],6,"helper index")
    eq(f.raid.shown,true,"shown")
    eq(f.raidStatus,"icon:6","status")
    eq(Calls(f.raid,"SetTexCoord"),0,"no manual texcoords")
end)

test("marker_change_and_clear",function()
    local f=Plate(nil)
    Index(8);Update(f);eq(f.raid.shown,true,"8 shown");ExpectCoords(f,8);eq(f.raidStatus,"icon:8","8 status")
    Index(3);Update(f);eq(f.raid.shown,true,"3 shown");ExpectCoords(f,3);eq(f.raidStatus,"icon:3","3 status")
    Index(nil);Update(f);eq(f.raid.shown,false,"cleared marker hidden");eq(f.raidStatus,"unavailable:no-native","nil status")
    Index(2);Update(f);eq(f.raid.shown,true,"set again");eq(f.raidStatus,"icon:2","2 status")
    Index(0);Update(f);eq(f.raid.shown,false,"0 hidden");eq(f.raidStatus,"none","0 status")
    Index(5);Update(f);eq(f.raidStatus,"icon:5","5 status")
    Index(9);Update(f);eq(f.raid.shown,false,"9 hidden");eq(f.raidStatus,"none","9 status")
    Index(0/0);Update(f);eq(f.raid.shown,false,"NaN hidden");eq(f.raidStatus,"none","NaN status")
    -- NaN with a usable native marker: a plain number, so Blizzard's marker is not borrowed (and is released).
    local rtf=NativeRaid()
    local g=Plate(UnitFrame(rtf))
    Index(SECRET);Update(g);ExpectBorrowed(g,rtf,"secret before NaN")
    Index(0/0);Update(g)
    eq(g.raidStatus,"none","NaN status with native");eq(g.nativeRaid,nil,"NaN releases the native marker")
    ExpectOriginal(rtf,"NaN released")
end)

test("secret_nil_error_take_native_fallback",function()
    local cases={{"secret",function() return SECRET end},{"nil",function() return nil end},{"error",function() error("blocked") end}}
    for _,case in ipairs(cases) do
        local what=case[1]
        local rtf=NativeRaid()
        local f=Plate(UnitFrame(rtf))
        f.raid.shown=true
        GetRaidTargetIndex=case[2]
        Update(f)
        eq(f.raid.shown,false,what.." hides the own icon")
        eq(f.raidStatus,"native",what.." status")
        ExpectBorrowed(f,rtf,what)
        eq(f.nativeRaidIgnore,false,what.." saved ignore flag")
        eq(#f.nativeRaidPoints,1,what.." saved anchor count")
        local saved=f.nativeRaidPoints[1]
        eq(saved[1],"RIGHT",what.." saved point");eq(saved[2],"HealthBar",what.." saved relative")
        eq(saved[3],"LEFT",what.." saved relative point");eq(saved[4],-6,what.." saved x");eq(saved[5],0,what.." saved y")
        -- Blizzard re-lays the plate out: the next tick puts it back without touching the saved originals.
        rtf.points={{"TOP","Elsewhere","TOP",0,0}};rtf.ignore=false
        local savedPoints=f.nativeRaidPoints
        Update(f)
        ExpectBorrowed(f,rtf,what.." second call")
        eq(f.raidStatus,"native",what.." second call status")
        eq(f.nativeRaidPoints,savedPoints,what.." originals kept")
        eq(f.nativeRaidPoints[1][1],"RIGHT",what.." original point kept")
        eq(f.nativeRaidIgnore,false,what.." original flag kept")
    end
end)

test("plain_number_releases_fallback",function()
    local rtf=NativeRaid()
    local f=Plate(UnitFrame(rtf))
    Index(SECRET);Update(f);ExpectBorrowed(f,rtf,"secret")
    Index(5);Update(f)
    eq(f.raid.shown,true,"own icon shown");ExpectCoords(f,5)
    ExpectOriginal(rtf,"released")
    eq(f.nativeRaid,nil,"nativeRaid cleared");eq(f.nativeRaidPoints,nil,"points cleared");eq(f.nativeRaidIgnore,nil,"flag cleared")
end)

test("detach_restores_native_marker",function()
    local rtf=NativeRaid()
    local uf=UnitFrame(rtf);uf.alpha=0.8
    local f=Plate(uf)
    Index(SECRET);Update(f);ExpectBorrowed(f,rtf,"secret")
    f.raid.shown=true
    ns.active.nameplate1=f
    ns.Detach("nameplate1")
    ExpectOriginal(rtf,"detached")
    eq(uf.alpha,0.8,"UnitFrame alpha restored")
    eq(f.raid.shown,false,"own icon hidden")
    eq(f.nativeRaid,nil,"nativeRaid cleared");eq(f.native,nil,"native released")
    eq(ns.active.nameplate1,nil,"plate released")
end)

test("detach_clears_raid_status",function()
    local f=Plate(UnitFrame(NativeRaid()))
    Index(SECRET);Update(f);eq(f.raidStatus,"native","borrowed status")
    ns.active.nameplate1=f;ns.Detach("nameplate1")
    eq(f.raidStatus,nil,"status cleared after the fallback")
    local g=Plate(nil)
    Index(4);Update(g);eq(g.raidStatus,"icon:4","icon status")
    ns.active.nameplate1=g;ns.Detach("nameplate1")
    eq(g.raidStatus,nil,"status cleared after the own icon")
end)

test("new_native_frame_restores_previous",function()
    -- Through the fallback itself: a different UnitFrame is seen on the next update.
    local rtf1,rtf2=NativeRaid(),NativeRaid({anchor="HealthBar"})
    local f=Plate(UnitFrame(rtf1))
    Index(nil);Update(f);ExpectBorrowed(f,rtf1,"first")
    f.native=UnitFrame(rtf2)
    Update(f)
    ExpectOriginal(rtf1,"previous frame")
    ExpectBorrowed(f,rtf2,"new frame")
    eq(f.nativeRaidPoints[1][1],"RIGHT","new frame's own originals saved")
    -- Through ns.UpdatePlate: a recycled base hands NativeVisuals a new UnitFrame before the marker update.
    ns.db={enabled=true,showCast=false,showAuras=false,colorThreat=false,healthText=true,healthPercent=true}
    UnitExists=function() return true end
    UnitCanAttack=function() return true end
    UnitIsUnit=function() return false end
    UnitName=function() return "Mob" end
    ns.StylePlate=function() end;ns.UpdateDotMarker=function() end;ns.UpdateQuestMarker=function() end
    ns.TargetStyle=function() end;ns.PlaceThreatText=function() end;ns.ThreatLabel=function() return "" end
    ns.LevelColor=function() return 1,1,1 end
    ns.ReadThreat=function() local s={key="neutral",color={1,1,1}};return s,nil,s end
    local rtf3,rtf4=NativeRaid(),NativeRaid()
    local uf3,uf4=UnitFrame(rtf3),UnitFrame(rtf4)
    local g=Plate(nil);g.base={UnitFrame=uf3}
    Index(SECRET)
    local ok,err=pcall(ns.UpdatePlate,g,false)
    if not ok then error("UpdatePlate raised: "..tostring(err)) end
    eq(g.native,uf3,"UpdatePlate fades the UnitFrame");eq(uf3.alpha,0,"faded")
    ExpectBorrowed(g,rtf3,"UpdatePlate fallback")
    g.base={UnitFrame=uf4}
    ok,err=pcall(ns.UpdatePlate,g,false)
    if not ok then error("UpdatePlate raised: "..tostring(err)) end
    ExpectOriginal(rtf3,"recycled plate's previous marker")
    eq(uf3.alpha,1,"previous UnitFrame alpha restored")
    ExpectBorrowed(g,rtf4,"recycled plate's new marker")
    Index(7)
    ok,err=pcall(ns.UpdatePlate,g,false)
    if not ok then error("UpdatePlate raised: "..tostring(err)) end
    eq(g.raid.shown,true,"own icon through UpdatePlate");ExpectCoords(g,7);ExpectOriginal(rtf4,"released by UpdatePlate")
    ns.db=nil
end)

test("fallback_unavailable_is_safe",function()
    local function Check(what,f,status,rtf,expectWrites)
        f.raid.shown=true
        Index(SECRET);Update(f)
        eq(f.raidStatus,status,what.." status")
        Update(f)
        eq(f.raid.shown,false,what.." own icon hidden")
        eq(f.nativeRaid,nil,what.." nothing borrowed")
        eq(f.raidStatus,status,what.." status on the next tick")
        if rtf and expectWrites==0 then eq(Writes(rtf),0,what.." native frame untouched") end
    end
    Check("no native",Plate(nil),"unavailable:no-native")
    Check("no RaidTargetFrame",Plate(UnitFrame(nil)),"unavailable:no-frame")
    local throwing=UnitFrame(nil)
    setmetatable(throwing,{__index=function(_,key) if key=="RaidTargetFrame" then error("forbidden access") end end})
    Check("erroring RaidTargetFrame lookup",Plate(throwing),"unavailable:no-frame")
    Check("secret RaidTargetFrame",Plate(UnitFrame(SECRET)),"unavailable:no-frame")
    local forbidden=NativeRaid({forbidden=true})
    Check("forbidden",Plate(UnitFrame(forbidden)),"unavailable:forbidden",forbidden,0)
    local noIgnore=NativeRaid({noIgnore=true})
    Check("no SetIgnoreParentAlpha",Plate(UnitFrame(noIgnore)),"unavailable:no-ignore-alpha",noIgnore,0)
    local secretIgnore=NativeRaid({secretIgnore=true})
    Check("secret IsIgnoringParentAlpha",Plate(UnitFrame(secretIgnore)),"unavailable:ignore-unreadable",secretIgnore,0)
    ExpectOriginal(secretIgnore,"secret IsIgnoringParentAlpha")
    local throwIgnore=NativeRaid({throwIgnore=true})
    Check("erroring IsIgnoringParentAlpha",Plate(UnitFrame(throwIgnore)),"unavailable:ignore-unreadable",throwIgnore,0)
    ExpectOriginal(throwIgnore,"erroring IsIgnoringParentAlpha")
    local failing=NativeRaid({failSetPoint=true})
    Check("erroring SetPoint",Plate(UnitFrame(failing)),"unavailable:setpoint-failed",failing)
    ExpectOriginal(failing,"erroring SetPoint restored")
end)

-- Calls on the native frame by name.
local function Logged(rtf,name)
    local n=0
    for _,entry in ipairs(rtf.log) do if entry[1]==name then n=n+1 end end
    return n
end
local function ExpectAlphaOnly(f,rtf,what)
    eq(f.raidStatus,"native-alpha",what.." status")
    eq(f.nativeRaid,rtf,what.." borrowed");eq(f.nativeRaidAlphaOnly,true,what.." alpha-only mode")
    eq(f.nativeRaidPoints,nil,what.." no anchors saved")
    eq(rtf.ignore,true,what.." ignores parent alpha")
    eq(Logged(rtf,"ClearAllPoints"),0,what.." never cleared");eq(Logged(rtf,"SetPoint"),0,what.." never anchored")
    eq(rtf.points[1][2],"HealthBar",what.." stays where Blizzard put it")
    -- Raised above the holder (and so above the addon's plate that covers the faded native plate).
    eq(rtf.level,f.raidHolder:GetFrameLevel()+1,what.." raised above the holder")
    eq(f.nativeRaidLevel,3,what.." original level saved")
end

test("unreadable_anchors_borrow_alpha_only",function()
    local cases={{"secret GetPoint",{secretPoint=true}},{"secret GetNumPoints",{badCount=true}},
        {"erroring GetPoint",{throwPoint=true}}}
    for _,case in ipairs(cases) do
        local what=case[1]
        local rtf=NativeRaid(case[2])
        local f=Plate(UnitFrame(rtf))
        f.raid.shown=true
        Index(SECRET);Update(f)
        ExpectAlphaOnly(f,rtf,what)
        eq(Writes(rtf),1,what.." one write");eq(Logged(rtf,"SetIgnoreParentAlpha"),1,what.." one flag write")
        eq(rtf.log[#rtf.log-1][1],"SetIgnoreParentAlpha",what.." flag written before the level")
        eq(rtf.log[#rtf.log-1][2],true,what.." flag set to true")
        eq(rtf.log[#rtf.log][1],"SetFrameLevel",what.." level raised last");eq(Logged(rtf,"SetFrameLevel"),1,what.." one level write")
        eq(f.raid.shown,false,what.." own icon hidden")
        eq(f.nativeRaidIgnore,false,what.." original flag saved")
        -- The next tick keeps the mode without reading or moving anything.
        local reads=Logged(rtf,"GetNumPoints")
        rtf.ignore=false;Update(f)
        ExpectAlphaOnly(f,rtf,what.." next tick");eq(Logged(rtf,"GetNumPoints"),reads,what.." anchors not read again")
        -- Detach puts only the flag back and restores the UnitFrame.
        ns.active.nameplate1=f;ns.Detach("nameplate1")
        ExpectOriginal(rtf,what.." detached")
        eq(Logged(rtf,"ClearAllPoints"),0,what.." detach never cleared");eq(Logged(rtf,"SetPoint"),0,what.." detach never anchored")
        eq(f.nativeRaid,nil,what.." released");eq(f.nativeRaidAlphaOnly,nil,what.." mode cleared")
        eq(f.native,nil,what.." native released");eq(f.raidStatus,nil,what.." status cleared")
    end
    -- An original flag of true goes back as true; an unreadable one goes back as false.
    local kept=NativeRaid({badCount=true});kept.ignore=true
    local f=Plate(UnitFrame(kept))
    Index(SECRET);Update(f);eq(f.raidStatus,"native-alpha","true flag status")
    Index(4);Update(f)
    eq(kept.ignore,true,"original true flag restored");eq(f.nativeRaid,nil,"plain index releases");eq(f.raidStatus,"icon:4","plain status")
    eq(Logged(kept,"SetPoint"),0,"plain index never anchored")
    for _,opts in ipairs({{badCount=true,secretIgnore=true},{secretPoint=true,throwIgnore=true}}) do
        local rtf=NativeRaid(opts);rtf.ignore=true
        local g=Plate(UnitFrame(rtf))
        Index(nil);Update(g)
        eq(g.raidStatus,"native-alpha","unreadable flag status");eq(g.nativeRaidIgnore,false,"unreadable flag saved as false")
        Index(0);Update(g)
        eq(rtf.ignore,false,"unreadable flag restored as false");eq(Logged(rtf,"SetPoint"),0,"never anchored")
    end
    -- Readable anchors with an unreadable flag still refuse to borrow.
    local secretIgnore=NativeRaid({secretIgnore=true})
    local h=Plate(UnitFrame(secretIgnore))
    Index(SECRET);Update(h);eq(h.raidStatus,"unavailable:ignore-unreadable","readable anchors need the flag")
    eq(Writes(secretIgnore),0,"untouched")
    -- No IsIgnoringParentAlpha at all: borrowed, restored as false.
    local noRead=NativeRaid({badCount=true});noRead.IsIgnoringParentAlpha=nil
    local k=Plate(UnitFrame(noRead))
    Index(SECRET);Update(k);ExpectAlphaOnly(k,noRead,"no flag reader")
    Index(0);Update(k);eq(noRead.ignore,false,"no flag reader restored")
end)

test("alpha_only_recycled_plate_restores",function()
    -- Through ns.UpdatePlate: a recycled base hands NativeVisuals a new UnitFrame; the old marker gets its flag back.
    ns.db={enabled=true,showCast=false,showAuras=false,colorThreat=false,healthText=true,healthPercent=true}
    UnitExists=function() return true end
    UnitCanAttack=function() return true end
    UnitIsUnit=function() return false end
    UnitName=function() return "Mob" end
    ns.StylePlate=function() end;ns.UpdateDotMarker=function() end;ns.UpdateQuestMarker=function() end
    ns.TargetStyle=function() end;ns.PlaceThreatText=function() end;ns.ThreatLabel=function() return "" end
    ns.LevelColor=function() return 1,1,1 end
    ns.ReadThreat=function() local s={key="neutral",color={1,1,1}};return s,nil,s end
    local rtf1,rtf2=NativeRaid({secretPoint=true}),NativeRaid()
    local uf1,uf2=UnitFrame(rtf1),UnitFrame(rtf2)
    local g=Plate(nil);g.base={UnitFrame=uf1}
    Index(SECRET)
    local ok,err=pcall(ns.UpdatePlate,g,false)
    if not ok then error("UpdatePlate raised: "..tostring(err)) end
    eq(uf1.alpha,0,"faded");ExpectAlphaOnly(g,rtf1,"UpdatePlate alpha-only")
    g.base={UnitFrame=uf2}
    ok,err=pcall(ns.UpdatePlate,g,false)
    if not ok then error("UpdatePlate raised: "..tostring(err)) end
    ExpectOriginal(rtf1,"recycled plate's previous marker")
    eq(Logged(rtf1,"SetPoint"),0,"previous marker never anchored")
    eq(uf1.alpha,1,"previous UnitFrame alpha restored")
    ExpectBorrowed(g,rtf2,"recycled plate's new marker")
    eq(g.nativeRaidAlphaOnly,nil,"new marker fully borrowed");eq(g.raidStatus,"native","new marker status")
    ns.db=nil
end)

test("alpha_only_unreadable_level_left_alone",function()
    local rtf=NativeRaid({badCount=true,secretLevel=true})
    local f=Plate(UnitFrame(rtf))
    Index(SECRET);Update(f)
    eq(f.raidStatus,"native-alpha","status");eq(rtf.ignore,true,"ignores parent alpha")
    eq(f.nativeRaidLevel,nil,"no level saved");eq(Logged(rtf,"SetFrameLevel"),0,"level never set")
    Update(f);eq(Logged(rtf,"SetFrameLevel"),0,"next tick level never set")
    Index(0);Update(f)
    eq(rtf.ignore,false,"flag restored");eq(rtf.level,3,"level untouched");eq(Logged(rtf,"SetFrameLevel"),0,"restore never set level")
    -- Readable anchors (full borrow) never touch the level.
    local full=NativeRaid()
    local g=Plate(UnitFrame(full))
    Index(SECRET);Update(g);eq(g.raidStatus,"native","full borrow status")
    eq(Logged(full,"SetFrameLevel"),0,"full borrow keeps its level");eq(g.nativeRaidLevel,nil,"full borrow saves no level")
    Index(0);Update(g);eq(Logged(full,"SetFrameLevel"),0,"full borrow restore keeps its level")
end)

test("secret_icon_unconfirmed_with_alpha_only",function()
    local rtf=NativeRaid({badCount=true})
    local f=Plate(UnitFrame(rtf))
    f.raid.SetTexture=function() return nil end
    Index(SECRET_CONCAT);Update(f)
    eq(f.raid.shown,true,"own icon shown")
    eq(f.raidStatus,"icon:secret+native-alpha","status")
    eq(Logged(rtf,"SetPoint"),0,"never anchored")
end)

-- A plate whose own icon answers SetTexture with result (or raises when result is "error"), logging every path.
local function SecretPlate(uf,result)
    local f=Plate(uf)
    f.raid.textures={}
    f.raid.SetTexture=function(self,path)
        self.textures[#self.textures+1]=path
        if rawequal(path,SECRET_PATH) and result=="error" then error("secret texture refused") end
        return result
    end
    return f
end
local SHEET="Interface\\TargetingFrame\\UI-RaidTargetingIcons"

test("secret_index_own_icon_when_confirmed",function()
    local rtf=NativeRaid()
    local f=SecretPlate(UnitFrame(rtf),true)
    SECRET_PATH_FOR=nil
    Index(SECRET_CONCAT);Update(f)
    eq(SECRET_PATH_FOR,"Interface\\TargetingFrame\\UI-RaidTargetingIcon_","per-marker file prefix")
    eq(rawequal(f.raid.textures[#f.raid.textures],SECRET_PATH),true,"own icon gets the secret path")
    local l,r,t,b=Last(f.raid,"SetTexCoord")
    eq(l,0,"full left");eq(r,1,"full right");eq(t,0,"full top");eq(b,1,"full bottom")
    eq(f.raid.shown,true,"own icon shown")
    eq(f.raidStatus,"icon:secret","status")
    eq(f.raidSecretIcon,"loaded","secret icon result")
    eq(f.nativeRaid,nil,"Blizzard's marker not borrowed");eq(Writes(rtf),0,"native marker untouched")
    -- Borrowed earlier, then confirmed: Blizzard's marker goes back.
    local rtf2=NativeRaid()
    local g=SecretPlate(UnitFrame(rtf2),true)
    Index(SECRET);Update(g);ExpectBorrowed(g,rtf2,"plain secret");eq(g.raidSecretIcon,"concat-failed","no concat")
    Index(SECRET_CONCAT);Update(g)
    eq(g.raidStatus,"icon:secret","confirmed after borrowing");ExpectOriginal(rtf2,"released once confirmed")
    -- A plain index afterwards puts the sprite sheet back before its texcoords.
    Index(5);Update(f)
    eq(f.raid.textures[#f.raid.textures],SHEET,"sheet restored");ExpectCoords(f,5)
    eq(f.raidStatus,"icon:5","plain status");eq(f.raidSecretIcon,nil,"secret result cleared")
    local n=#f.raid.textures
    Index(6);Update(f);eq(#f.raid.textures,n,"sheet set only once")
end)

test("secret_index_unconfirmed_keeps_native",function()
    -- SetTexture gives no plain boolean: the own icon stays up and Blizzard's marker is borrowed behind it.
    for _,case in ipairs({{"nil result",nil},{"secret result",SECRET}}) do
        local what=case[1]
        local rtf=NativeRaid()
        local f=SecretPlate(UnitFrame(rtf),case[2])
        Index(SECRET_CONCAT);Update(f)
        eq(f.raid.shown,true,what.." own icon shown")
        eq(f.raidStatus,"icon:secret+native",what.." status")
        eq(f.raidSecretIcon,"unconfirmed",what.." secret icon result")
        ExpectBorrowed(f,rtf,what)
        Update(f);eq(f.raidStatus,"icon:secret+native",what.." next tick");ExpectBorrowed(f,rtf,what.." next tick")
    end
    local f=SecretPlate(nil,nil)
    Index(SECRET_CONCAT);Update(f)
    eq(f.raid.shown,true,"shown without a native frame")
    eq(f.raidStatus,"icon:secret+unavailable:no-native","status without a native frame")
    -- Detach and a NaN index both clear the secret icon result.
    ns.active.nameplate1=f;ns.Detach("nameplate1")
    eq(f.raidSecretIcon,nil,"cleared by Detach");eq(f.raidStatus,nil,"status cleared by Detach")
    local g=SecretPlate(nil,nil)
    Index(SECRET_CONCAT);Update(g);eq(g.raidSecretIcon,"unconfirmed","set")
    Index(0/0);Update(g);eq(g.raidSecretIcon,nil,"cleared by NaN");eq(g.raid.shown,false,"NaN hides")
end)

test("secret_index_own_icon_failures_fall_back",function()
    local cases={
        {"refused texture",SECRET_CONCAT,false,"not-loaded"},
        {"erroring texture",SECRET_CONCAT,"error","texture-failed"},
        {"secret that cannot be joined",SECRET_THROW,true,"concat-failed"},
        {"secret without concatenation",SECRET,true,"concat-failed"},
    }
    for _,case in ipairs(cases) do
        local what=case[1]
        local rtf=NativeRaid()
        local f=SecretPlate(UnitFrame(rtf),case[3])
        f.raid.shown=true
        Index(case[2]);Update(f)
        eq(f.raid.shown,false,what.." own icon hidden")
        eq(f.raidStatus,"native",what.." status")
        eq(f.raidSecretIcon,case[4],what.." secret icon result")
        ExpectBorrowed(f,rtf,what)
    end
    -- A nil or erroring index never tries the secret icon.
    for _,case in ipairs({{"nil",function() return nil end},{"error",function() error("blocked") end}}) do
        local f=SecretPlate(UnitFrame(NativeRaid()),true)
        GetRaidTargetIndex=case[2];Update(f)
        eq(#f.raid.textures,0,case[1].." no texture change");eq(f.raidSecretIcon,nil,case[1].." no secret result")
        eq(f.raidStatus,"native",case[1].." status")
    end
end)

-- /mp raid: runs the real slash handler and captures everything ns.Print sends to print.
local function SlashRaid(input)
    local out,realPrint={},print
    print=function(text) out[#out+1]=text end
    local ok,err=pcall(SlashCmdList.MOTEVEPLATES,input or "raid")
    print=realPrint
    if not ok then error("/mp raid raised: "..tostring(err),2) end
    return out
end
local function Has(out,needle,what)
    for _,line in ipairs(out) do if line:find(needle,1,true) then return line end end
    error((what or needle).." not printed; got:\n"..table.concat(out,"\n"),2)
end
local function Lacks(out,needle,what)
    for _,line in ipairs(out) do if line:find(needle,1,true) then error((what or needle).." printed: "..line,2) end end
end
-- The client side of /mp raid: one plate (nameplate1) is the target's, found through C_NamePlate by default.
local function ReportWorld(f,opts)
    opts=opts or {}
    ns.db={enabled=true}
    for k in pairs(ns.active) do ns.active[k]=nil end
    if f then ns.active.nameplate1=f end
    C_AddOns=nil
    GetAddOnMetadata=function(name,field) eq(name,"MotevePlates","addon name");eq(field,"Version","field");return "9.9.9" end
    C_NamePlate={GetNamePlateForUnit=function(unit)
        eq(unit,"target","plate lookup unit")
        if opts.secretBase then return SECRET end
        return opts.base or (f and f.base)
    end}
    UnitExists=function() return opts.exists~=false end
    if opts.secretExists then UnitExists=function() return SECRET end end
    UnitIsUnit=function(a,b) return opts.unitIsUnit==true and a=="nameplate1" and b=="target" end
    GetBuildInfo=function() return "1.16.0","65000","Nov 1 2026",16001 end
end
local function ReportCleanup()
    ns.db=nil;C_AddOns,GetAddOnMetadata,C_NamePlate,UnitExists,UnitIsUnit,GetBuildInfo=nil,nil,nil,nil,nil,nil
    for k in pairs(ns.active) do ns.active[k]=nil end
end

test("raid_report_with_plate",function()
    -- Index 8: the own icon.
    local f=Plate(UnitFrame(NativeRaid()))
    ReportWorld(f)
    GetRaidTargetIndex=function() return 8 end
    Update(f)
    local out=SlashRaid()
    eq(out[1],"|cffa88bffMoteve Plates|r: Verzió: 9.9.9","version first")
    Has(out,"nameplate1 (keresés: nameplate), látható: igen","plate found through C_NamePlate")
    Has(out,"Jel sorszáma (nameplate1): number 8","plate index")
    Has(out,"Jel sorszáma (target): number 8","target index")
    Has(out,"Gyári UnitFrame: van","native present")
    Has(out,"RaidTargetFrame: table","RaidTargetFrame classified")
    Has(out,"Átemelt Blizzard-jel: nem","not borrowed")
    Has(out,"raidStatus: icon:8","status")
    Has(out,"Saját ikon látható: igen, jelkeret látható: igen","icon shown")
    eq(out[2],"|cffa88bffMoteve Plates|r: Kliens: 1.16.0 (65000), interfész: 16001, titkos értékek: igen","client second")
    Has(out,"Blizzard-jel: keret látható: ?, ikon látható: ?, méret: ?","native marker without readers")
    Has(out,"Titkos sorszám saját ikonja: —","no secret icon")
    -- /mplates RAID reaches the same branch; nothing about the plate changed.
    eq(#SlashRaid("RAID"),#out,"case-insensitive")
    eq(f.raidStatus,"icon:8","report is read-only")
    -- Erroring index: Blizzard's marker taken over.
    GetRaidTargetIndex=function() error("blocked") end
    Update(f)
    out=SlashRaid()
    Has(out,"Jel sorszáma (nameplate1): error","error index")
    Has(out,"raidStatus: native","native status")
    Has(out,"Átemelt Blizzard-jel: igen","borrowed")
    Has(out,"Saját ikon látható: nem","own icon hidden")
    -- Nil index.
    GetRaidTargetIndex=function() return nil end
    out=SlashRaid()
    Has(out,"Jel sorszáma (nameplate1): nil","nil index")
    -- Missing index function, a plate without a native frame and a hidden plate; no C_AddOns version either.
    GetRaidTargetIndex=nil;GetAddOnMetadata=nil
    local g=Plate(nil);g.shown=false
    ReportWorld(g);GetAddOnMetadata=nil
    out=SlashRaid()
    eq(out[1],"|cffa88bffMoteve Plates|r: Verzió: ?","unknown version")
    Has(out,"Jel sorszáma (nameplate1): missing","missing index")
    Has(out,"Gyári UnitFrame: nincs","no native")
    Has(out,"RaidTargetFrame: no native","RaidTargetFrame without native")
    Has(out,"raidStatus: —","never updated")
    Has(out,"látható: nem","hidden plate")
    -- C_AddOns.GetAddOnMetadata wins over the global.
    C_AddOns={GetAddOnMetadata=function() return "1.2.3" end}
    out=SlashRaid()
    eq(out[1],"|cffa88bffMoteve Plates|r: Verzió: 1.2.3","C_AddOns version")
    ReportCleanup()
end)

test("raid_report_secret_never_stringified",function()
    local f=Plate(UnitFrame(NativeRaid()))
    ReportWorld(f,{secretBase=true,unitIsUnit=true})
    GetAddOnMetadata=function() return SECRET_THROW end
    GetRaidTargetIndex=function() return SECRET_THROW end
    Update(f)
    eq(f.raidStatus,"native","secret index takes the native fallback")
    local out=SlashRaid()
    eq(out[1],"|cffa88bffMoteve Plates|r: Verzió: ?","secret version not printed")
    Has(out,"nameplate1 (keresés: UnitIsUnit)","plate found through UnitIsUnit")
    Has(out,"Jel sorszáma (nameplate1): secret","plate index secret")
    Has(out,"Jel sorszáma (target): secret","target index secret")
    Has(out,"raidStatus: native","status")
    -- Alpha-only borrowing is reported as such.
    local alpha=Plate(UnitFrame(NativeRaid({secretPoint=true})))
    ReportWorld(alpha)
    Update(alpha)
    out=SlashRaid()
    Has(out,"Átemelt Blizzard-jel: csak alfa","alpha-only borrowing")
    Has(out,"raidStatus: native-alpha","alpha-only status")
    -- A secret RaidTargetFrame is classified, never printed.
    local g=Plate(UnitFrame(SECRET_THROW))
    ReportWorld(g)
    out=SlashRaid()
    Has(out,"RaidTargetFrame: secret","secret frame")
    Lacks(out,"<secret>","secret text")
    ReportCleanup()
end)

test("raid_report_secret_icon_and_native_marker",function()
    -- Blizzard's marker with readable visibility and size, and a secret index the own icon showed unconfirmed.
    local rtf=NativeRaid()
    local icon={}
    function icon:IsVisible() return false end
    rtf.RaidTargetIcon=icon
    function rtf:IsVisible() return true end
    function rtf:GetSize() return 22,22 end
    local f=SecretPlate(UnitFrame(rtf),nil)
    ReportWorld(f)
    Index(SECRET_CONCAT)
    GetRaidTargetIndex=function() return SECRET_CONCAT end
    Update(f)
    local out=SlashRaid()
    Has(out,"Jel sorszáma (nameplate1): secret","secret index")
    Has(out,"raidStatus: icon:secret+native","status")
    Has(out,"Titkos sorszám saját ikonja: unconfirmed","secret icon result")
    Has(out,"Blizzard-jel: keret látható: igen, ikon látható: nem, méret: 22x22","native marker state")
    -- Secret build values and a secret size are never printed.
    GetBuildInfo=function() return SECRET_THROW,SECRET_THROW,nil,SECRET_THROW end
    function rtf:GetSize() return SECRET_THROW,22 end
    function rtf:IsVisible() return SECRET_THROW end
    rtf.RaidTargetIcon=SECRET_THROW
    out=SlashRaid()
    Has(out,"Kliens: ? (?), interfész: ?","secret build")
    Has(out,"Blizzard-jel: keret látható: ?, ikon látható: ?, méret: ?","secret native marker state")
    -- No RaidTargetFrame on the native UnitFrame, and an erroring lookup.
    ReportWorld(Plate(UnitFrame(nil)))
    Has(SlashRaid(),"Blizzard-jel: nincs","no native marker frame")
    local throwing=UnitFrame(nil)
    setmetatable(throwing,{__index=function(_,key) if key=="RaidTargetFrame" then error("forbidden access") end end})
    ReportWorld(Plate(throwing))
    Has(SlashRaid(),"Blizzard-jel: nincs","erroring native marker frame")
    ReportCleanup()
end)

test("raid_report_no_target_or_plate",function()
    GetRaidTargetIndex=function() return 8 end
    ReportWorld(nil,{exists=false})
    local out=SlashRaid()
    eq(#out,3,"version, client and one hint")
    Has(out,"Verzió: 9.9.9","version")
    Has(out,"Nincs kijelölt célpont","no target hint")
    -- A target with no Moteve Plates plate: a plate exists but belongs to another unit.
    local f=Plate(nil)
    ReportWorld(f,{base={}})
    out=SlashRaid()
    Has(out,"nincs Moteve Plates névtáblája","no plate hint")
    Lacks(out,"raidStatus","plate details")
    ReportWorld(nil,{base={}})
    out=SlashRaid()
    Has(out,"nincs Moteve Plates névtáblája","no plate hint without active plates")
    -- Secret UnitExists and a secret plate base: still a hint, no error.
    ReportWorld(nil,{secretExists=true,secretBase=true})
    out=SlashRaid()
    eq(#out,3,"version, client and one hint with secret values")
    Has(out,"Nincs kijelölt célpont","hint for an unreadable target")
    ReportCleanup()
end)

print(string.format("%d/%d passed",count-failures,count))
if failures>0 then os.exit(1) end
