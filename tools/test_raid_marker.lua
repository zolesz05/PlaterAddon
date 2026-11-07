-- Plain-Lua tests for the raid target marker (Lua 5.1 or later), run from the repository root:
--   lua tools/test_raid_marker.lua
-- Part 1 loads Core.lua and Skins.lua against a stub CreateFrame whose frames record every method call and checks the
-- marker's own frame. Part 2 loads Core.lua and Plates.lua against stubs (GetRaidTargetIndex, issecretvalue, a fake
-- native UnitFrame with its RaidTargetFrame) and drives ns.UpdateRaidMarker, ns.UpdatePlate and ns.Detach.
-- Exits non-zero on any failure.
local root=(arg and arg[0] or ""):match("^(.-)[/\\]?tools[/\\][^/\\]+$") or "."
if root=="" then root="." end
local unpack=unpack or table.unpack
local SECRET=setmetatable({},{__tostring=function() return "<secret>" end})
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
function frameMethods.GetStatusBarTexture(self) return NewFrame("Texture",self) end
function CreateFrame(kind,name,parent,template) return NewFrame(kind,parent,template) end
SlashCmdList={}
issecretvalue=function(v) return v==SECRET end

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
        eq(point,"BOTTOM","holder point");eq(rel,f,"holder relative frame");eq(relPoint,"TOP","holder relative point")
        eq(x,0,"holder x")
        if type(y)~="number" or y<80 then error("holder y "..tostring(y).." inside the aura rows (up to +80)") end
        eq(y,84,"holder y")
        eq(f.raid.kind,"Texture","f.raid is a texture")
        eq(f.raid.parent,holder,"f.raid lives on the holder")
        eq(Calls(f.raid,"SetAllPoints"),1,"f.raid fills the holder")
        eq(Last(f.raid,"SetTexture"),"Interface\\TargetingFrame\\UI-RaidTargetingIcons","marker texture")
        for i,a in ipairs(f.auras) do
            if a==holder then error("holder is aura "..i) end
            local _,_,_,_,ay=Last(a,"SetPoint")
            if ay+19>y then error("aura "..i.." top "..(ay+19).." reaches the marker at "..y) end
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
    local rtf={log={},points={{"RIGHT",opts.anchor or "HealthBar","LEFT",-6,0}},ignore=false}
    local function log(name,...) rtf.log[#rtf.log+1]={name,...} end
    function rtf:GetNumPoints() log("GetNumPoints");return #self.points end
    function rtf:GetPoint(i)
        log("GetPoint",i)
        if opts.secretPoint then return SECRET,nil,nil,0,0 end
        return unpack(self.points[i],1,5)
    end
    function rtf:ClearAllPoints() log("ClearAllPoints");self.points={} end
    function rtf:SetPoint(...)
        log("SetPoint",...)
        if opts.failSetPoint and select(2,...)~="HealthBar" then error("SetPoint blocked") end
        self.points[#self.points+1]={...}
    end
    if not opts.noIgnore then
        function rtf:IsIgnoringParentAlpha() log("IsIgnoringParentAlpha");return self.ignore end
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
    eq(#rtf.points,1,what.." single anchor")
    local p=rtf.points[1]
    eq(p[1],"CENTER",what.." point");eq(p[2],f.raidHolder,what.." anchored to the holder");eq(p[3],"CENTER",what.." relative point")
end
local function ExpectOriginal(rtf,what)
    eq(#rtf.points,1,what.." anchor count")
    local p=rtf.points[1]
    eq(p[1],"RIGHT",what.." point");eq(p[2],"HealthBar",what.." relative");eq(p[3],"LEFT",what.." relative point")
    eq(p[4],-6,what.." x");eq(p[5],0,what.." y")
    eq(rtf.ignore,false,what.." ignore flag")
end

test("index_1_to_8_texcoords",function()
    local f=Plate(UnitFrame(NativeRaid()))
    eq(ns.Number(4),4,"plain numbers pass")
    for i=1,8 do
        Index(i);f.raid.shown=false;Update(f)
        eq(f.raid.shown,true,i.." shown");ExpectCoords(f,i)
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
    eq(Calls(f.raid,"SetTexCoord"),0,"no manual texcoords")
end)

test("marker_change_and_clear",function()
    local f=Plate(nil)
    Index(8);Update(f);eq(f.raid.shown,true,"8 shown");ExpectCoords(f,8)
    Index(3);Update(f);eq(f.raid.shown,true,"3 shown");ExpectCoords(f,3)
    Index(nil);Update(f);eq(f.raid.shown,false,"cleared marker hidden")
    Index(2);Update(f);eq(f.raid.shown,true,"set again")
    Index(0);Update(f);eq(f.raid.shown,false,"0 hidden")
    Index(5);Update(f);Index(9);Update(f);eq(f.raid.shown,false,"9 hidden")
    Index(0/0);Update(f);eq(f.raid.shown,false,"NaN hidden")
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
    local function Check(what,f,rtf,expectWrites)
        f.raid.shown=true
        Index(SECRET);Update(f);Update(f)
        eq(f.raid.shown,false,what.." own icon hidden")
        eq(f.nativeRaid,nil,what.." nothing borrowed")
        if rtf and expectWrites==0 then eq(Writes(rtf),0,what.." native frame untouched") end
    end
    Check("no native",Plate(nil))
    Check("no RaidTargetFrame",Plate(UnitFrame(nil)))
    local throwing=UnitFrame(nil)
    setmetatable(throwing,{__index=function(_,key) if key=="RaidTargetFrame" then error("forbidden access") end end})
    Check("erroring RaidTargetFrame lookup",Plate(throwing))
    Check("secret RaidTargetFrame",Plate(UnitFrame(SECRET)))
    local forbidden=NativeRaid({forbidden=true})
    Check("forbidden",Plate(UnitFrame(forbidden)),forbidden,0)
    local noIgnore=NativeRaid({noIgnore=true})
    Check("no SetIgnoreParentAlpha",Plate(UnitFrame(noIgnore)),noIgnore,0)
    local secretPoint=NativeRaid({secretPoint=true})
    Check("secret GetPoint",Plate(UnitFrame(secretPoint)),secretPoint,0)
    ExpectOriginal(secretPoint,"secret GetPoint")
    local failing=NativeRaid({failSetPoint=true})
    Check("erroring SetPoint",Plate(UnitFrame(failing)),failing)
    ExpectOriginal(failing,"erroring SetPoint restored")
end)

print(string.format("%d/%d passed",count-failures,count))
if failures>0 then os.exit(1) end
