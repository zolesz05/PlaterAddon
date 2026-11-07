-- Plain-Lua tests for the combo-point dots on the owner's plate (Lua 5.1 or later), run from the repository root:
--   lua tools/test_combo_points.lua
-- Core.lua, Threat.lua, Skins.lua, Combo.lua and Options.lua are loaded in TOC order against a stub CreateFrame whose
-- frames record every method call, so the setting (ADDON_LOADED, ns.SetOption), the class filter, the read order,
-- the dots, the name width, the owner across target changes (with Plates.lua's ns.Detach) and the /mp switch run as
-- in the client. Exits non-zero on any failure.
local root=(arg and arg[0] or ""):match("^(.-)[/\\]?tools[/\\][^/\\]+$") or "."
if root=="" then root="." end
local unpack=unpack or table.unpack
local SECRET=setmetatable({},{__tostring=function() return "<secret>" end})
local SKINS={"minimal","classic","moteve"}
local failures,count=0,0

-- A frame stub: any method (a capitalised key) is a no-op that records its call in frame.calls[method];
-- unset lowercase fields stay nil. `Text` stays nil like on a template without a stock label.
local frameMethods={}
local frames={}
local function NewFrame(kind,parent,template)
    local frame={kind=kind,parent=parent,template=template,calls={}}
    frames[#frames+1]=frame
    return setmetatable(frame,{__index=function(t,key)
        if frameMethods[key] then return frameMethods[key] end
        if type(key)~="string" or not key:match("^%u") or key=="Text" then return nil end
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
function frameMethods.GetChecked(self) return self.checked end
function CreateFrame(kind,name,parent,template) return NewFrame(kind,parent,template) end
function issecretvalue(v) return v==SECRET end
function GetTime() return 100 end
SlashCmdList={}
UIParent=NewFrame("Frame")

-- Client stubs, reset by every test: the player's class file, the two combo-point sources (counting their calls)
-- and the plate units' GUIDs (guids[unit]; "error" raises).
local class,points,power
local calls={}
local guids={}
function UnitGUID(unit)
    if guids[unit]=="error" then error("UnitGUID failed") end
    return guids[unit]
end
function UnitClass(unit)
    if class=="error" then error("UnitClass failed") end
    return "Class",class
end
local function Source(name,value)
    return function(...)
        local list=calls[name] or {};calls[name]=list;list[#list+1]={...}
        if value()=="error" then error(name.." failed") end
        return value()
    end
end
GetComboPoints=Source("GetComboPoints",function() return points end)
UnitPower=Source("UnitPower",function() return power end)
local stockComboPoints,stockUnitPower,stockUnitClass,stockUnitGUID=GetComboPoints,UnitPower,UnitClass,UnitGUID

local ns={}
local function LoadFile(name) assert(loadfile(root.."/MotevePlates/"..name))("MotevePlates",ns) end
LoadFile("Core.lua");LoadFile("Threat.lua");LoadFile("Skins.lua");LoadFile("Combo.lua");LoadFile("Options.lua")
-- Plates.lua for ns.Detach only, loaded into a view of ns so its own functions (ns.ApplyOptions, ...) stay out of the
-- cases above; the modules Detach calls that this file does not load are no-ops.
local plates=setmetatable({Dots={Clear=function() end},StopNativeAuras=function() end},{__index=ns})
assert(loadfile(root.."/MotevePlates/Plates.lua"))("MotevePlates",plates)
local function Detach(f)
    plates.active[f.unit]=f;plates.Detach(f.unit)
end

local function test(name,fn)
    count=count+1
    class,points,power,calls,guids="ROGUE",nil,nil,{},{}
    GetComboPoints,UnitPower,UnitClass,UnitGUID=stockComboPoints,stockUnitPower,stockUnitClass,stockUnitGUID
    -- ns.ComboClass caches the class once readable and the owner is module state: every case starts afresh.
    LoadFile("Combo.lua")
    local ok,err=pcall(fn)
    if ok then print("ok   "..name) else failures=failures+1;print("FAIL "..name..": "..tostring(err)) end
end
local function eq(actual,expected,what)
    if actual~=expected then error((what or "value")..": expected "..tostring(expected)..", got "..tostring(actual),2) end
end
-- Loads MotevePlatesDB as the client does on login.
local function Load(saved)
    MotevePlatesDB=saved
    ns.db=nil
    ns:Fire("ADDON_LOADED","MotevePlates")
    if not ns.db then error("ADDON_LOADED did not set ns.db",2) end
    if #ns.errors>0 then error("handler error: "..ns.errors[#ns.errors],2) end
end
-- The arguments of the last call to method on frame.
local function Last(frame,method)
    local list=frame.calls[method]
    if not list then error(method.." never called",2) end
    return unpack(list[#list])
end
local function Calls(name) return calls[name] and #calls[name] or 0 end
-- A styled plate as ns.UpdatePlate has it, with the saved settings.
local function Plate(skin)
    local f=ns.CreatePlate(NewFrame("Frame"))
    ns.StylePlate(f,skin or "classic")
    return f
end
-- A styled plate for unit, whose GUID is guid (nil leaves it unset).
local function UnitPlate(unit,guid)
    local f=Plate()
    f.unit=unit;guids[unit]=guid
    return f
end
local function Shown(f) return (Last(f.combo,"SetShown")) end
local function NameWidth(f) return (Last(f.name,"SetWidth")) end
-- Asserts the combo row is visible with exactly n full dots and the rest dimmed.
local function Dots(f,n,what)
    eq(Shown(f),true,what.." shown")
    for i=1,5 do eq((Last(f.combo[i],"SetAlpha")),i<=n and 1 or 0.25,what.." dot "..i.." alpha") end
end
-- Shows 3 points on f's target plate, then applies change() and checks the row is hidden and the name restored.
local function HidesAfter(what,change,target)
    Load({width=190})
    points=3
    local f=Plate()
    ns.UpdateComboPoints(f,true);Dots(f,3,what.." before")
    change()
    ns.UpdateComboPoints(f,target~=false)
    eq(Shown(f),false,what.." hidden")
    eq(NameWidth(f),190,what.." name width")
    return f
end

test("toc_lists_combo_between_dots_and_plates",function()
    local file=assert(io.open(root.."/MotevePlates/MotevePlates.toc","r"))
    local text=file:read("*a");file:close()
    eq(text:match("## Version:%s*(%S+)"),"0.2.12","version")
    if not text:find("\nDots.lua\r?\nCombo.lua\r?\nPlates.lua\r?\n") then error("Combo.lua not between Dots.lua and Plates.lua") end
end)

test("default_and_saved_setting",function()
    eq(ns.defaults.showComboPoints,true,"default")
    Load(nil);eq(ns.db.showComboPoints,true,"fresh install")
    Load({skin="moteve"});eq(ns.db.showComboPoints,true,"missing key")
    Load({showComboPoints=false});eq(ns.db.showComboPoints,false,"saved false kept")
    Load({showComboPoints=true});eq(ns.db.showComboPoints,true,"saved true kept")
    for _,bad in ipairs({"yes",0,1,{},SECRET}) do
        Load({showComboPoints=bad});eq(ns.db.showComboPoints,true,"saved "..tostring(bad))
    end
    eq(ns.SetOption("showComboPoints",false),true,"SetOption false");eq(ns.db.showComboPoints,false,"stored false")
    eq(ns.SetOption("showComboPoints","off"),false,"SetOption string");eq(ns.db.showComboPoints,false,"rejected value")
end)

test("combo_class_rogue_and_druid_only",function()
    for _,case in ipairs({{"ROGUE",true},{"DRUID",true},{"WARRIOR",false},{"MAGE",false},{"WARLOCK",false},
        {"PRIEST",false},{"HUNTER",false},{"SHAMAN",false},{"PALADIN",false},{"rogue",false},{"",false},
        {nil,false},{SECRET,false},{42,false},{"error",false}}) do
        LoadFile("Combo.lua")
        class=case[1]
        eq(ns.ComboClass(),case[2],"class "..tostring(case[1]))
    end
    LoadFile("Combo.lua")
    UnitClass=nil;eq(ns.ComboClass(),false,"missing UnitClass")
    UnitClass=stockUnitClass;class="DRUID";eq(ns.ComboClass(),true,"read once the class is readable")
    class="WARRIOR";eq(ns.ComboClass(),true,"cached after the first readable class")
end)

test("read_prefers_target_combo_points",function()
    points,power=3,5
    eq(ns.ReadComboPoints(),3,"GetComboPoints value")
    local args=calls.GetComboPoints[1]
    eq(args[1],"player","unit");eq(args[2],"target","target")
    eq(Calls("UnitPower"),0,"UnitPower not read")
    points=0;eq(ns.ReadComboPoints(),0,"zero is a value")
    eq(Calls("UnitPower"),0,"UnitPower not read for 0")
end)

test("read_falls_back_to_unit_power_only_on_nil",function()
    points,power=nil,4
    eq(ns.ReadComboPoints(),4,"nil GetComboPoints")
    eq(calls.UnitPower[1][1],"player","unit");eq(calls.UnitPower[1][2],4,"power type")
    points=SECRET;eq(ns.ReadComboPoints(),4,"secret GetComboPoints, numeric UnitPower")
    points="error";eq(ns.ReadComboPoints(),4,"GetComboPoints raises")
    points=0/0;eq(ns.ReadComboPoints(),4,"NaN GetComboPoints")
    GetComboPoints=nil;eq(ns.ReadComboPoints(),4,"missing GetComboPoints")
end)

test("read_rejects_unreadable_values",function()
    for _,case in ipairs({{nil,nil},{SECRET,SECRET},{SECRET,nil},{nil,SECRET},{0/0,0/0},{"3","3"},
        {math.huge,-math.huge},{true,{}},{"error","error"}}) do
        points,power=case[1],case[2]
        eq(ns.ReadComboPoints(),nil,tostring(case[1]).." / "..tostring(case[2]))
    end
    UnitPower=nil;GetComboPoints=nil
    eq(ns.ReadComboPoints(),nil,"both missing")
end)

test("read_clamps_and_floors",function()
    for _,case in ipairs({{6,5},{5,5},{99,5},{2.7,2},{0.5,0},{-1,0},{1,1}}) do
        points=case[1];eq(ns.ReadComboPoints(),case[2],"points "..case[1])
        points=nil;power=case[1];eq(ns.ReadComboPoints(),case[2],"power "..case[1])
    end
end)

test("target_plate_shows_earned_and_free_dots",function()
    Load({width=190})
    for _,n in ipairs({3,1,5,2}) do
        local f=Plate()
        points=n;ns.UpdateComboPoints(f,true)
        Dots(f,n,n.." points")
    end
    local f=Plate()
    points=3;ns.UpdateComboPoints(f,true);Dots(f,3,"3 points")
    points=5;ns.UpdateComboPoints(f,true);Dots(f,5,"then 5 points")
    points=6;ns.UpdateComboPoints(f,true);Dots(f,5,"6 clamps to 5")
    class="DRUID";LoadFile("Combo.lua")
    f=Plate();points=nil;power=2;ns.UpdateComboPoints(f,true);Dots(f,2,"druid, UnitPower fallback")
end)

-- Mobs A, B and C on nameplate1..3. update(f,isTarget) runs one refresh of f, as the 0.1 s ticker does.
local function Mobs()
    Load({width=190})
    return UnitPlate("nameplate1","Creature-0-1-2-3-100-A"),UnitPlate("nameplate2","Creature-0-1-2-3-100-B"),
        UnitPlate("nameplate3","Creature-0-1-2-3-100-C")
end
local function Hidden(f,what)
    eq(Shown(f),false,what.." hidden")
    eq(NameWidth(f),190,what.." name width")
end

test("dots_stay_on_the_owner_after_a_target_change",function()
    local a,b,c=Mobs()
    points=3
    ns.UpdateComboPoints(a,true);ns.UpdateComboPoints(b,false);ns.UpdateComboPoints(c,false)
    Dots(a,3,"A as target");Hidden(b,"B before");Hidden(c,"C before")
    local guid,n=ns.ComboOwner();eq(guid,"Creature-0-1-2-3-100-A","owner");eq(n,3,"owner count")
    -- Tab to B: GetComboPoints("player","target") is now 0, nothing built on B yet.
    points=0;calls={}
    ns.UpdateComboPoints(a,false);ns.UpdateComboPoints(b,true);ns.UpdateComboPoints(c,false)
    Dots(a,3,"A after targeting B");Hidden(b,"B targeted");Hidden(c,"C")
    eq(Calls("GetComboPoints"),1,"only the target plate reads the client")
    -- Esc: no target at all, so no plate is the target.
    points=nil;calls={}
    ns.UpdateComboPoints(a,false);ns.UpdateComboPoints(b,false);ns.UpdateComboPoints(c,false)
    Dots(a,3,"A with no target");Hidden(b,"B untargeted");Hidden(c,"C")
    eq(Calls("GetComboPoints")+Calls("UnitPower"),0,"no client read on non-target plates")
end)

test("building_on_a_new_target_moves_the_owner",function()
    local a,b,c=Mobs()
    points=3;ns.UpdateComboPoints(a,true);Dots(a,3,"A as target")
    points=0;ns.UpdateComboPoints(b,true);ns.UpdateComboPoints(a,false);Dots(a,3,"A while B is targeted")
    points=1;ns.UpdateComboPoints(b,true);Dots(b,1,"B after 1 point")
    local guid,n=ns.ComboOwner();eq(guid,"Creature-0-1-2-3-100-B","new owner");eq(n,1,"new owner count")
    ns.UpdateComboPoints(a,false);Hidden(a,"A on its next update")
    ns.UpdateComboPoints(c,false);Hidden(c,"C")
    -- Back to A without building: A stays at 0 and B keeps its point.
    points=0;ns.UpdateComboPoints(a,true);ns.UpdateComboPoints(b,false)
    Hidden(a,"A targeted again");Dots(b,1,"B no longer targeted")
end)

test("old_owner_plate_shows_zero_when_it_comes_back",function()
    local a,b=Mobs()
    points=3;ns.UpdateComboPoints(a,true)
    -- A leaves the screen: NAME_PLATE_UNIT_REMOVED runs Plates.lua's ns.Detach, which only hides the row.
    Detach(a)
    eq(Shown(a),false,"row hidden on detach");eq(a.unit,nil,"plate released")
    eq(ns.ComboOwner(),"Creature-0-1-2-3-100-A","hiding the row keeps the owner")
    points=2;ns.UpdateComboPoints(b,true);Dots(b,2,"B")
    -- A comes back (NAME_PLATE_UNIT_ADDED) on another token.
    local back=UnitPlate("nameplate4","Creature-0-1-2-3-100-A")
    ns.UpdateComboPoints(back,false);Hidden(back,"old owner on return")
    -- The owner returning off-screen keeps its dots.
    Detach(b)
    local again=UnitPlate("nameplate5","Creature-0-1-2-3-100-B")
    ns.UpdateComboPoints(again,false);Dots(again,2,"owner on return")
end)

test("finisher_on_the_owner_clears_it",function()
    local a,b=Mobs()
    points=4;ns.UpdateComboPoints(a,true);Dots(a,4,"A")
    points=0;ns.UpdateComboPoints(a,true);Hidden(a,"A after the finisher")
    local guid,n=ns.ComboOwner();eq(guid,nil,"owner cleared");eq(n,0,"count cleared")
    ns.UpdateComboPoints(a,false);Hidden(a,"A no longer targeted")
    ns.UpdateComboPoints(b,false);Hidden(b,"B")
end)

test("unit_power_fallback_does_not_move_the_owner",function()
    local a,b=Mobs()
    points=3;ns.UpdateComboPoints(a,true)
    -- GetComboPoints unreadable on B: the player-level UnitPower still has A's 3 points.
    points,power=nil,3;ns.UpdateComboPoints(b,true);Dots(b,3,"B shows the fallback count as target")
    eq(ns.ComboOwner(),"Creature-0-1-2-3-100-A","owner kept")
    ns.UpdateComboPoints(a,false);Dots(a,3,"A keeps its dots")
    -- A 0 from the fallback on the owner does not clear it either.
    power=0;ns.UpdateComboPoints(a,true);Hidden(a,"A as target at fallback 0")
    eq(ns.ComboOwner(),"Creature-0-1-2-3-100-A","owner kept at fallback 0")
    -- With only the fallback from the start, nothing ever owns the points: target-only, as before.
    LoadFile("Combo.lua");a,b=Mobs()
    points,power=nil,2;ns.UpdateComboPoints(a,true);Dots(a,2,"fallback on the target")
    ns.UpdateComboPoints(a,false);Hidden(a,"fallback, no longer targeted")
    eq(ns.ComboOwner(),nil,"no owner from the fallback")
end)

test("secret_or_missing_guids_stay_hidden",function()
    -- Counted loop: ipairs would stop at the nil and skip every later case.
    local bads={n=6,SECRET,nil,false,"",42,"error"}
    for i=1,bads.n do
        local bad=bads[i]
        LoadFile("Combo.lua")
        local a,b=Mobs()
        points=3;ns.UpdateComboPoints(a,true)
        guids.nameplate2=bad
        ns.UpdateComboPoints(b,false);Hidden(b,"non-target with GUID "..tostring(bad))
        -- A target whose GUID is unreadable shows its points but owns nothing, and A no longer has them.
        guids.nameplate1=bad
        points=2;ns.UpdateComboPoints(a,true);Dots(a,2,"target with GUID "..tostring(bad))
        eq(ns.ComboOwner(),nil,"no owner with GUID "..tostring(bad))
        guids.nameplate1="Creature-0-1-2-3-100-A"
        ns.UpdateComboPoints(a,false);Hidden(a,"old owner after an unreadable target built")
    end
    LoadFile("Combo.lua")
    local a,b=Mobs()
    points=3;ns.UpdateComboPoints(a,true)
    UnitGUID=nil
    ns.UpdateComboPoints(a,false);Hidden(a,"missing UnitGUID")
    -- UnitGUID answers the owner's GUID for anything, so only the unit check can keep these hidden.
    UnitGUID=function() return "Creature-0-1-2-3-100-A" end
    local units={n=3,SECRET,nil,42}
    for i=1,units.n do
        local unit=units[i]
        b.unit=unit;ns.UpdateComboPoints(b,false);Hidden(b,"unit "..tostring(unit))
    end
end)

test("setting_off_or_other_class_clears_the_owner",function()
    local a=Mobs()
    points=3;ns.UpdateComboPoints(a,true)
    eq(ns.SetOption("showComboPoints",false),true,"SetOption")
    ns.UpdateComboPoints(a,false);Hidden(a,"setting off")
    eq(ns.ComboOwner(),nil,"owner cleared by the setting")
    ns.SetOption("showComboPoints",true)
    ns.UpdateComboPoints(a,false);Hidden(a,"setting back on")
    -- The class is cached once readable, so a non-combo class is one from the first read: it never gets an owner.
    class="WARRIOR";LoadFile("Combo.lua");a=Mobs()
    points=3;ns.UpdateComboPoints(a,true);Hidden(a,"warrior target")
    eq(ns.ComboOwner(),nil,"no owner for a warrior")
    ns.UpdateComboPoints(a,false);Hidden(a,"warrior non-target")
end)

test("hidden_at_zero_points",function()
    HidesAfter("zero",function() points=0;power=4 end)
end)

test("hidden_when_unreadable",function()
    HidesAfter("secret",function() points,power=SECRET,SECRET end)
    HidesAfter("missing",function() points,power=nil,nil end)
end)

test("hidden_when_setting_off",function()
    HidesAfter("setting off",function() eq(ns.SetOption("showComboPoints",false),true,"SetOption");calls={} end)
    eq(Calls("GetComboPoints"),0,"no client read with the setting off")
end)

test("hidden_for_other_classes",function()
    for _,other in ipairs({"WARRIOR","MAGE","WARLOCK"}) do
        class=other;LoadFile("Combo.lua")
        Load({width=190});points=3
        local f=Plate()
        ns.UpdateComboPoints(f,true)
        eq(Shown(f),false,other.." hidden")
        eq(NameWidth(f),190,other.." name width")
    end
    eq(Calls("GetComboPoints"),0,"no client read for other classes")
end)

test("name_narrows_while_dots_show",function()
    Load({width=190})
    local f=Plate()
    eq(NameWidth(f),190,"styled width")
    points=3;ns.UpdateComboPoints(f,true)
    eq(NameWidth(f),190-54,"narrow while shown")
    local before=#f.name.calls.SetWidth
    ns.UpdateComboPoints(f,true)
    eq(#f.name.calls.SetWidth,before,"no width call while unchanged")
    points=0;ns.UpdateComboPoints(f,true)
    eq(NameWidth(f),190,"restored when hidden")
    points=2;ns.UpdateComboPoints(f,true);eq(NameWidth(f),136,"narrow again")
    -- A restyle (setting change) gives the name the full width; the next update narrows it from the new width.
    ns.SetOption("width",220);ns.StylePlate(f,"classic")
    eq(NameWidth(f),220,"restyled width")
    ns.UpdateComboPoints(f,true);eq(NameWidth(f),166,"narrow from the new width")
    ns.ShowComboPoints(f,0);eq(NameWidth(f),220,"restored to the new width")
end)

test("restyle_redraws_dot_alpha",function()
    Load({})
    local f=Plate();points=3
    ns.UpdateComboPoints(f,true)
    local before=#f.combo[1].calls.SetAlpha
    ns.UpdateComboPoints(f,true);eq(#f.combo[1].calls.SetAlpha,before,"no redraw while unchanged")
    ns.StylePlate(f,"moteve");ns.UpdateComboPoints(f,true)
    eq(#f.combo[1].calls.SetAlpha,before+1,"redrawn after restyle");Dots(f,3,"after restyle")
end)

test("dots_use_skin_accent",function()
    local f=Plate()
    for _,skin in ipairs(SKINS) do
        ns.StylePlate(f,skin)
        local a=ns.Skins[skin].accent
        for i=1,5 do
            local r,g,b,alpha=Last(f.combo[i],"SetColorTexture")
            eq(r,a[1],skin.." dot "..i.." red");eq(g,a[2],skin.." dot "..i.." green")
            eq(b,a[3],skin.." dot "..i.." blue");eq(alpha,1,skin.." dot "..i.." alpha")
        end
    end
end)

test("dots_sit_in_the_name_row",function()
    local f=ns.CreatePlate(NewFrame("Frame"))
    local point,relative,relativePoint,x,y=Last(f.combo,"SetPoint")
    eq(point,"BOTTOMRIGHT","point");eq(relative,f,"relative");eq(relativePoint,"TOPRIGHT","relative point")
    eq(x,0,"x");eq(y,4,"y")
    eq(#f.combo,5,"five dots")
    eq(#f.combo.calls.Hide,1,"hidden on creation")
    eq(f.combo.calls.EnableMouse[1][1],false,"click-through")
end)

-- The /mp panel: find the switch by its label and run its click handler.
local function Switch()
    for _,frame in ipairs(frames) do
        if frame.kind=="FontString" and frame.parent and frame.parent.kind=="CheckButton" and frame.calls.SetText
            and Last(frame,"SetText")=="Kombópontok a célponton" then return frame.parent end
    end
    error("switch not found",2)
end

test("panel_switch_place_visibility_and_click",function()
    local cb=Switch()
    local point,x,y=Last(cb,"SetPoint")
    eq(point,"TOPLEFT","point");eq(x,320,"x");eq(y,-764,"y")
    if y>-458-30 then error("switch at y="..y.." overlaps the legend at y=-458") end
    Load({});eq(Last(cb,"SetShown"),true,"shown for a Rogue")
    eq(Last(cb,"SetChecked"),true,"checked by default")
    class="WARRIOR";LoadFile("Combo.lua");Load({})
    eq(Last(cb,"SetShown"),false,"hidden for a Warrior")
    class="DRUID";LoadFile("Combo.lua");Load({})
    eq(Last(cb,"SetShown"),true,"shown for a Druid")
    local set=ns.SetOption
    local seen={}
    ns.SetOption=function(key,value) seen[#seen+1]={key,value};return set(key,value) end
    local click
    for _,c in ipairs(cb.calls.SetScript) do if c[1]=="OnClick" then click=c[2] end end
    cb.checked=false;click(cb)
    cb.checked=true;click(cb)
    ns.SetOption=set
    eq(#seen,2,"SetOption calls")
    eq(seen[1][1],"showComboPoints","key");eq(seen[1][2],false,"unchecked")
    eq(seen[2][1],"showComboPoints","key");eq(seen[2][2],true,"checked")
    eq(ns.db.showComboPoints,true,"stored")
end)

test("panel_preview_draws_three_dots",function()
    Load({})
    for i,skin in ipairs(SKINS) do
        local f=ns.previewPlates[i]
        Dots(f,3,skin.." preview")
        eq(NameWidth(f),170-54,skin.." preview name width")
    end
    eq(Calls("GetComboPoints")+Calls("UnitPower"),0,"preview reads no client value")
    ns.SetOption("showComboPoints",false)
    for i,skin in ipairs(SKINS) do
        eq(Shown(ns.previewPlates[i]),false,skin.." preview off");eq(NameWidth(ns.previewPlates[i]),170,skin.." name width")
    end
    class="MAGE";LoadFile("Combo.lua");Load({})
    for i,skin in ipairs(SKINS) do eq(Shown(ns.previewPlates[i]),false,skin.." preview for a Mage") end
end)

print(string.format("%d/%d passed",count-failures,count))
if failures>0 then os.exit(1) end
