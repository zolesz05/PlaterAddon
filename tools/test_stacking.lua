-- Plain-Lua tests for stacked enemy plates (Lua 5.1 or later), run from the repository root:
--   lua tools/test_stacking.lua
-- ns.ApplyStacking (Core.lua) turns the client's "Stacking Nameplates" motion on (nameplateMotion 1) or off (0);
-- ns.ApplyPlateSize sizes Blizzard's enemy base plate to the custom frame's footprint (ns.PlateFootprint, Skins.lua)
-- so the engine's stacked slots fit everything the frame draws, and restores Blizzard's size when stacking is off.
-- Both wait for PLAYER_REGEN_ENABLED in combat. Plates.lua anchors each frame so its visual centre is the slot's.
-- Core.lua, Skins.lua and Plates.lua are loaded in TOC order against stubs of CreateFrame, the CVar API,
-- InCombatLockdown, C_NamePlate, NamePlateDriverFrame and hooksecurefunc. Exits non-zero on any failure.
local root=(arg and arg[0] or ""):match("^(.-)[/\\]?tools[/\\][^/\\]+$") or "."
if root=="" then root="." end
local unpack=unpack or table.unpack
local failures,count=0,0

-- A frame stub: any method (a capitalised key) is a no-op that records its call in frame.calls[method].
local frameMethods={}
local function NewFrame(kind,parent,template)
    local frame={kind=kind,parent=parent,template=template,calls={}}
    return setmetatable(frame,{__index=function(t,key)
        if frameMethods[key] then return frameMethods[key] end
        if type(key)~="string" or not key:match("^%u") then return nil end
        return function(self,...)
            local list=self.calls[key] or {}
            self.calls[key]=list
            list[#list+1]={...}
        end
    end})
end
function frameMethods.CreateTexture(self) return NewFrame("Texture",self) end
function frameMethods.CreateFontString(self) return NewFrame("FontString",self) end
function frameMethods.GetFrameLevel() return 1 end
function frameMethods.GetStatusBarTexture(self) return NewFrame("Texture",self) end
function CreateFrame(kind,name,parent,template) return NewFrame(kind,parent,template) end
SlashCmdList={}

-- Client stubs, reset by every test.
local cvars,cvarWrites,combat,cvarResult
local enemySize,sizeWrites,sizeAvailable,hooks
local function SetCVarStub(name,value)
    cvarWrites[#cvarWrites+1]={name,value}
    cvars[name]=value
    return cvarResult
end
C_CVar={SetCVar=function(...) return SetCVarStub(...) end,GetCVar=function(name) return cvars[name] end}
function InCombatLockdown() return combat end
C_NamePlate={}
local function NamePlateAPI()
    C_NamePlate.GetNamePlateEnemySize=function() return enemySize[1],enemySize[2] end
    C_NamePlate.SetNamePlateEnemySize=function(w,h) sizeWrites[#sizeWrites+1]={w,h};enemySize={w,h} end
end
NamePlateDriverFrame={}
function NamePlateDriverFrame:UpdateNamePlateOptions()
    C_NamePlate.SetNamePlateEnemySize(110,45)
end
function hooksecurefunc(object,method,hook)
    hooks[#hooks+1]=method
    local original=object[method]
    object[method]=function(...) original(...);hook(...) end
end

local ns={}
assert(loadfile(root.."/MotevePlates/Core.lua"))("MotevePlates",ns)
assert(loadfile(root.."/MotevePlates/Skins.lua"))("MotevePlates",ns)
assert(loadfile(root.."/MotevePlates/Plates.lua"))("MotevePlates",ns)
ns.Dots={Sync=function() end,Clear=function() end}
local driverUpdate=NamePlateDriverFrame.UpdateNamePlateOptions

local function test(name,fn)
    count=count+1
    cvars={nameplateMotion="0",nameplateMaxDistance="40"};cvarWrites={};combat=false;cvarResult=nil
    enemySize={110,45};sizeWrites={};hooks={}
    NamePlateDriverFrame.UpdateNamePlateOptions=driverUpdate
    ns.driverHooked=nil;ns.sizeApplied=nil;ns.sizeOriginal=nil;ns.sizePending=nil;ns.sizeRecapture=nil
    ns.stackingPending=nil;ns.stackingFailure=nil
    C_NamePlate.GetNamePlateEnemySize=nil;C_NamePlate.SetNamePlateEnemySize=nil;C_NamePlate.GetNamePlateForUnit=nil
    NamePlateAPI()
    for unit in pairs(ns.active) do ns.active[unit]=nil end
    local ok,err=pcall(fn)
    if ok then print("ok   "..name) else failures=failures+1;print("FAIL "..name..": "..tostring(err)) end
end
local function eq(actual,expected,what)
    if actual~=expected then error((what or "value")..": expected "..tostring(expected)..", got "..tostring(actual),2) end
end
local function near(actual,expected,what)
    if type(actual)~="number" or math.abs(actual-expected)>1e-6 then
        error((what or "value")..": expected "..tostring(expected)..", got "..tostring(actual),2)
    end
end
local function Load(saved)
    MotevePlatesDB=saved
    ns.db=nil
    ns:Fire("ADDON_LOADED","MotevePlates")
    if not ns.db then error("ADDON_LOADED did not set ns.db",2) end
end
local function MotionWrites()
    local list={}
    for _,w in ipairs(cvarWrites) do if w[1]=="nameplateMotion" then list[#list+1]=w[2] end end
    return list
end
local function Copy(t) local c={};for k,v in pairs(t) do c[k]=v end;return c end
-- Defaults: 190x17 bar, scale 1, offset 0, 8 debuffs of 19 px (two rows), cast bar and threat percent on.
-- Above the bar: debuff rows up to 30+19+31=80. Below: threat text under the cast bar, 23+10=33.
-- Height 80+17+33=130; width 2*(95+36)=262 (raid marker left of the bar); centring shift (33-80)/2=-23.5.
local DEFAULT_W,DEFAULT_H,DEFAULT_SHIFT=262,130,-23.5

test("login_turns_stacking_on",function()
    Load(nil)
    ns:Fire("PLAYER_LOGIN")
    local writes=MotionWrites()
    eq(#writes,1,"nameplateMotion writes");eq(writes[1],"1","nameplateMotion")
    eq(ns.stackingPending,false,"not pending");eq(ns.stackingFailure,nil,"no failure")
end)
test("login_sizes_the_enemy_plate",function()
    Load(nil)
    ns:Fire("PLAYER_LOGIN")
    eq(#sizeWrites,1,"size writes")
    near(sizeWrites[1][1],DEFAULT_W,"width");near(sizeWrites[1][2],DEFAULT_H,"height")
    eq(ns.sizeApplied,true,"sizeApplied")
    eq(ns.sizeOriginal[1],110,"original width kept");eq(ns.sizeOriginal[2],45,"original height kept")
end)
test("set_option_off_restores_overlap_and_size",function()
    Load(nil)
    ns:Fire("PLAYER_LOGIN")
    eq(ns.SetOption("stackPlates",false),true,"SetOption")
    local writes=MotionWrites()
    eq(writes[#writes],"0","nameplateMotion back to overlapping")
    local last=sizeWrites[#sizeWrites]
    eq(last[1],110,"Blizzard width restored");eq(last[2],45,"Blizzard height restored")
    eq(ns.sizeApplied,false,"sizeApplied")
    local before=#sizeWrites
    ns.ApplyOptions()
    eq(#sizeWrites,before,"no size writes while off")
    ns.SetOption("stackPlates",true)
    eq(MotionWrites()[#MotionWrites()],"1","on again")
    near(sizeWrites[#sizeWrites][2],DEFAULT_H,"footprint again")
end)
test("saved_off_writes_overlap_and_keeps_size",function()
    Load({stackPlates=false})
    ns:Fire("PLAYER_LOGIN")
    eq(MotionWrites()[1],"0","nameplateMotion")
    eq(#sizeWrites,0,"Blizzard size untouched")
end)
test("login_disabled_leaves_motion_alone",function()
    Load({enabled=false})
    cvars.nameplateMotion="0" -- the user's own Overlapping choice in Blizzard's Interface options
    ns:Fire("PLAYER_LOGIN")
    eq(#MotionWrites(),0,"no nameplateMotion writes while disabled")
    eq(cvars.nameplateMotion,"0","Blizzard Motion Type kept")
    eq(#sizeWrites,0,"Blizzard size untouched")
    eq(ns.stackingPending,false,"not pending")
    ns:Fire("PLAYER_REGEN_ENABLED")
    eq(#MotionWrites(),0,"no write after combat either")
end)
test("toggling_enabled_reapplies_stacking",function()
    Load(nil)
    ns:Fire("PLAYER_LOGIN")
    eq(#MotionWrites(),1,"written at login")
    eq(ns.SetOption("enabled",false),true,"SetOption enabled off")
    eq(#MotionWrites(),1,"no nameplateMotion write when disabling")
    local last=sizeWrites[#sizeWrites]
    eq(last[1],110,"Blizzard width restored");eq(last[2],45,"Blizzard height restored")
    cvars.nameplateMotion="0" -- user picks Overlapping while the addon is off
    ns.SetOption("stackPlates",false);ns.SetOption("stackPlates",true)
    eq(#MotionWrites(),1,"stackPlates changes do not write while disabled")
    eq(cvars.nameplateMotion,"0","user's choice kept")
    eq(ns.SetOption("enabled",true),true,"SetOption enabled on")
    local writes=MotionWrites()
    eq(#writes,2,"written again on enable");eq(writes[2],"1","stacking on")
    near(sizeWrites[#sizeWrites][2],DEFAULT_H,"footprint again")
end)
test("enabling_in_combat_waits",function()
    Load({enabled=false})
    ns:Fire("PLAYER_LOGIN")
    combat=true
    ns.SetOption("enabled",true)
    eq(#MotionWrites(),0,"held in combat");eq(ns.stackingPending,true,"pending")
    combat=false
    ns:Fire("PLAYER_REGEN_ENABLED")
    eq(MotionWrites()[1],"1","written after combat")
end)
test("combat_defers_until_regen",function()
    Load(nil)
    combat=true
    ns:Fire("PLAYER_LOGIN")
    eq(#MotionWrites(),0,"no CVar write in combat");eq(#sizeWrites,0,"no size write in combat")
    eq(ns.stackingPending,true,"stacking pending");eq(ns.sizePending,true,"size pending")
    eq(ns.StackingStatus(),"Névtábla-rendezés: alkalmazás harc után.","status")
    ns:Fire("PLAYER_REGEN_ENABLED")
    eq(#MotionWrites(),0,"still in combat lockdown")
    combat=false
    ns:Fire("PLAYER_REGEN_ENABLED")
    eq(MotionWrites()[1],"1","applied after combat");eq(#MotionWrites(),1,"once")
    near(sizeWrites[1][2],DEFAULT_H,"size applied after combat")
    eq(ns.stackingPending,false,"stacking no longer pending");eq(ns.sizePending,false,"size no longer pending")
    ns:Fire("PLAYER_REGEN_ENABLED")
    eq(#MotionWrites(),1,"nothing more on the next regen");eq(#sizeWrites,1,"no extra size write")
end)
test("option_change_in_combat_defers_size",function()
    Load(nil)
    ns:Fire("PLAYER_LOGIN")
    combat=true
    ns.SetOption("showAuras",false)
    eq(#sizeWrites,1,"no size write in combat");eq(ns.sizePending,true,"pending")
    combat=false
    ns:Fire("PLAYER_REGEN_ENABLED")
    eq(#sizeWrites,2,"written after combat")
    near(sizeWrites[2][2],17+17+33,"height without debuff rows")
    eq(#MotionWrites(),1,"motion not rewritten")
end)
test("cvar_api_missing_or_refused",function()
    Load(nil)
    local api=C_CVar;C_CVar=nil
    ns.ApplyStacking()
    C_CVar=api
    eq(ns.stackingFailure,"A névtábla-rendezés nem állítható ezen a kliensen.","no API")
    cvarResult=false
    ns.ApplyStacking()
    eq(ns.stackingFailure,"A névtábla-rendezés módosítása sikertelen; a kliens nem engedélyezte.","refused")
    C_CVar={SetCVar=function() error("blocked") end}
    ns.ApplyStacking()
    C_CVar=api
    eq(ns.stackingFailure,"A névtábla-rendezés módosítása sikertelen; a kliens nem engedélyezte.","error")
end)
test("size_api_missing",function()
    Load(nil)
    C_NamePlate.SetNamePlateEnemySize=nil
    ns:Fire("PLAYER_LOGIN")
    eq(MotionWrites()[1],"1","stacking still on")
    eq(ns.sizeApplied,false,"no size")
    eq(ns.sizeFailure,"unavailable","failure")
    eq(ns.PlateAnchorY(ns.db,ns.sizeApplied),0,"no centring shift without the size")
end)
test("addon_disabled_keeps_blizzard_size",function()
    Load(nil)
    ns:Fire("PLAYER_LOGIN")
    ns.SetOption("enabled",false)
    local last=sizeWrites[#sizeWrites]
    eq(last[1],110,"restored width");eq(last[2],45,"restored height")
    eq(ns.sizeApplied,false,"sizeApplied")
end)
test("driver_reset_is_overridden",function()
    Load(nil)
    ns:Fire("PLAYER_LOGIN")
    eq(hooks[1],"UpdateNamePlateOptions","hooked")
    eq(#hooks,1,"hooked once");ns.ApplyPlateSize();eq(#hooks,1,"not hooked twice")
    -- Blizzard's driver sets its own (new) size, e.g. after a CVar change; the footprint is written back after it.
    local before=#sizeWrites
    NamePlateDriverFrame:UpdateNamePlateOptions()
    eq(#sizeWrites,before+2,"Blizzard write then ours")
    near(enemySize[2],DEFAULT_H,"footprint wins")
    eq(ns.sizeOriginal[2],45,"Blizzard's size kept as the one to restore")
end)
test("footprint_defaults",function()
    Load(nil)
    local w,h,shift=ns.PlateFootprint(ns.db)
    near(w,DEFAULT_W,"width");near(h,DEFAULT_H,"height");near(shift,DEFAULT_SHIFT,"shift")
end)
test("footprint_includes_aura_and_cast_rows",function()
    Load(nil)
    local d=Copy(ns.db)
    local _,full=ns.PlateFootprint(d)
    d.showAuras=false
    local _,noAuras=ns.PlateFootprint(d)
    near(full-noAuras,80-17,"debuff rows above the name row")
    d.showCast=false
    local _,noCast=ns.PlateFootprint(d)
    near(noAuras-noCast,33-15,"cast bar moves the threat text down")
    d.showThreatPercent=false;d.showAggro=false
    local _,bare=ns.PlateFootprint(d)
    near(bare,17+17+3,"name row, bar and a 3 px edge")
    d.showAggro=true
    local _,aggro=ns.PlateFootprint(d)
    near(aggro,17+17+15,"threat text without cast")
end)
test("footprint_aura_rows_follow_count_and_size",function()
    Load(nil)
    local d=Copy(ns.db)
    d.maxAuras=6
    local _,oneRow,shift=ns.PlateFootprint(d)
    near(oneRow,(30+19)+17+33,"one row of six");near(shift,(33-49)/2,"shift")
    d.maxAuras=12;d.auraSize=32
    local w,twoRows=ns.PlateFootprint(d)
    near(twoRows,(30+32+44)+17+33,"two rows of 32 px")
    near(w,DEFAULT_W,"the raid marker side is still the widest")
    d.width=140
    w=ns.PlateFootprint(d)
    near(w,2*(6*36-4-70),"six 32 px icons reach past a 140 px bar")
end)
test("footprint_scale_and_offset",function()
    Load(nil)
    local d=Copy(ns.db)
    d.scale=1.5
    local w,h,shift=ns.PlateFootprint(d)
    near(w,DEFAULT_W*1.5,"scaled width");near(h,DEFAULT_H*1.5,"scaled height");near(shift,DEFAULT_SHIFT,"shift in plate units")
    d.scale=1;d.offset=-30
    local _,low=ns.PlateFootprint(d)
    near(low,DEFAULT_H+60,"room for the offset on both sides")
    d.width=260
    local wide=ns.PlateFootprint(d)
    near(wide,2*(130+36),"wider bar")
end)
test("anchor_y",function()
    Load({offset=10})
    eq(ns.PlateAnchorY(ns.db,false),10,"unstacked: offset only")
    near(ns.PlateAnchorY(ns.db,true),10+DEFAULT_SHIFT,"stacked: offset plus centring shift")
end)
test("attached_plate_sits_in_its_slot",function()
    Load(nil)
    ns:Fire("PLAYER_LOGIN")
    local base=NewFrame("Frame");base.IsForbidden=function() return false end
    UnitCanAttack=function() return true end
    C_NamePlate.GetNamePlateForUnit=function() return base end
    local f=ns.Attach("nameplate1")
    UnitCanAttack=nil
    assert(f,"attached")
    local p=f.calls.SetPoint[#f.calls.SetPoint]
    eq(p[1],"CENTER","point");eq(p[2],base,"relative to the base plate");near(p[5],DEFAULT_SHIFT,"y")
    ns.SetOption("stackPlates",false)
    p=f.calls.SetPoint[#f.calls.SetPoint]
    eq(p[5],0,"back to the base centre when off")
    ns.SetOption("stackPlates",true);ns.SetOption("offset",20)
    p=f.calls.SetPoint[#f.calls.SetPoint]
    near(p[5],20+DEFAULT_SHIFT,"offset on top of the shift")
end)

print(string.format("%d/%d passed",count-failures,count))
if failures>0 then os.exit(1) end
