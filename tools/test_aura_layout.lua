-- Plain-Lua tests for the configurable own-debuff icon size (Lua 5.1 or later), run from the repository root:
--   lua tools/test_aura_layout.lua
-- ns.AuraLayout (Skins.lua) is the one place that turns auraSize into icon size, column step, row step and row width.
-- Both aura paths use it: the fallback icons are sized and placed in ns.StylePlate, and the native AuraContainer
-- (Auras.lua) takes its button size and row width from it when the container is built (applied after /reload).
-- Core.lua, Skins.lua and Auras.lua are loaded in TOC order against a stub CreateFrame whose frames record every
-- method call. Exits non-zero on any failure.
-- The stack count of both paths sits on an overlay above the cooldown, bottom-right (ns.CreateAuraCount).
local root=(arg and arg[0] or ""):match("^(.-)[/\\]?tools[/\\][^/\\]+$") or "."
if root=="" then root="." end
local unpack=unpack or table.unpack
local failures,count=0,0

-- A frame stub: any method (a capitalised key) is a no-op that records its call in frame.calls[method];
-- unset lowercase fields stay nil.
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
local containerStub
function CreateFrame(kind,name,parent,template)
    if kind=="AuraContainer" then return containerStub end
    return NewFrame(kind,parent,template)
end
SlashCmdList={}

local ns={}
assert(loadfile(root.."/MotevePlates/Core.lua"))("MotevePlates",ns)
assert(loadfile(root.."/MotevePlates/Skins.lua"))("MotevePlates",ns)
assert(loadfile(root.."/MotevePlates/Auras.lua"))("MotevePlates",ns)

local function test(name,fn)
    count=count+1
    containerStub=nil
    local ok,err=pcall(fn)
    if ok then print("ok   "..name) else failures=failures+1;print("FAIL "..name..": "..tostring(err)) end
end
local function eq(actual,expected,what)
    if actual~=expected then error((what or "value")..": expected "..tostring(expected)..", got "..tostring(actual),2) end
end
local function Last(frame,method)
    local calls=frame.calls[method]
    if not calls then error(method.." never called",2) end
    return unpack(calls[#calls])
end
local function Load(saved)
    MotevePlatesDB=saved
    ns.db=nil
    ns:Fire("ADDON_LOADED","MotevePlates")
end
local function Options(size)
    local d={};for key,value in pairs(ns.defaults) do d[key]=value end
    d.auraSize=size
    return d
end
local function Layout(size)
    local s,column,row,width=ns.AuraLayout(size)
    return {s,column,row,width}
end
local function Same(actual,expected,what)
    for i=1,#expected do eq(actual[i],expected[i],what.." ["..i.."]") end
end

test("layout_19_matches_previous_fixed_layout",function()
    Same(Layout(19),{19,23,31,134},"size 19")
end)
test("layout_14",function()
    Same(Layout(14),{14,18,26,104},"size 14")
end)
test("layout_32",function()
    Same(Layout(32),{32,36,44,212},"size 32")
end)
test("layout_invalid_size_uses_default",function()
    Same(Layout(nil),{19,23,31,134},"nil")
    Same(Layout("big"),{19,23,31,134},"string")
end)

test("create_plate_leaves_size_to_style",function()
    local f=ns.CreatePlate(NewFrame("Frame"))
    eq(#f.auras,12,"aura frames")
    for i,a in ipairs(f.auras) do
        eq(a.calls.SetSize,nil,"aura "..i.." SetSize in CreatePlate")
        eq(a.calls.SetPoint,nil,"aura "..i.." SetPoint in CreatePlate")
    end
end)

-- Every fallback icon gets the size and the grid position (6 per row, growing up from y=30) of the given auraSize.
local function CheckGrid(f,size,column,row)
    for i,a in ipairs(f.auras) do
        local w,h=Last(a,"SetSize")
        eq(w,size,"aura "..i.." width");eq(h,size,"aura "..i.." height")
        local point,rel,relPoint,x,y=Last(a,"SetPoint")
        eq(point,"BOTTOMLEFT","aura "..i.." point");eq(rel,f,"aura "..i.." relative");eq(relPoint,"TOPLEFT","aura "..i.." relative point")
        eq(x,((i-1)%6)*column,"aura "..i.." x");eq(y,30+math.floor((i-1)/6)*row,"aura "..i.." y")
        if not a.calls.ClearAllPoints then error("aura "..i.." anchors not cleared before re-anchoring") end
    end
end
test("style_plate_default_matches_previous_layout",function()
    local f=ns.CreatePlate(NewFrame("Frame"))
    ns.StylePlate(f,"classic",Options(19))
    CheckGrid(f,19,23,31)
end)
test("style_plate_sizes_from_aura_size",function()
    for _,size in ipairs({14,26,32}) do
        local f=ns.CreatePlate(NewFrame("Frame"))
        ns.StylePlate(f,"moteve",Options(size))
        CheckGrid(f,size,size+4,size+12)
    end
end)
test("restyle_applies_new_size_immediately",function()
    local f=ns.CreatePlate(NewFrame("Frame"))
    ns.StylePlate(f,"minimal",Options(19))
    ns.StylePlate(f,"minimal",Options(30))
    CheckGrid(f,30,34,42)
end)
test("style_plate_reads_saved_size",function()
    Load({auraSize=22})
    local f=ns.CreatePlate(NewFrame("Frame"))
    ns.StylePlate(f,"classic")
    CheckGrid(f,22,26,34)
end)

-- Builds the native container for a plate and returns the stub and the options passed to AddAuraGroup.
local function Native(plate)
    local group
    containerStub=NewFrame("AuraContainer")
    function containerStub.AddAuraGroup(_,name,filter,options) group={name=name,filter=filter,options=options} end
    eq(ns.UseNativeAuras(plate),true,"native container used")
    if not group then error("AddAuraGroup not called") end
    return containerStub,group.options
end
test("native_container_uses_aura_size",function()
    for _,size in ipairs({14,19,28,32}) do
        Load({auraSize=size,enabled=false})
        local c,options=Native(NewFrame("Frame"))
        local _,_,_,width=ns.AuraLayout(size)
        eq(Last(c,"SetFlowLayoutMaximumLineSize"),width,"row width at "..size)
        eq(options.layout.elementSpacing,4,"element spacing");eq(options.layout.lineSpacing,12,"line spacing")
        local button=NewFrame("Button")
        options.initializeFrame(button)
        local w,h=Last(button,"SetSize")
        eq(w,size,"button width at "..size);eq(h,size,"button height at "..size)
    end
end)
test("native_size_fixed_until_reload",function()
    Load({auraSize=28,enabled=false})
    local plate=NewFrame("Frame")
    local c,options=Native(plate)
    eq(ns.SetOption("auraSize",16),true,"size changed")
    eq(ns.UseNativeAuras(plate),true,"same container used")
    eq(plate.auraContainer,c,"container not rebuilt")
    local button=NewFrame("Button")
    options.initializeFrame(button)
    local w=Last(button,"SetSize")
    eq(w,28,"button initialised after the change keeps its container's size")
    -- A plate whose container is built after the change (in practice: after /reload) gets the new size.
    local _,fresh=Native(NewFrame("Frame"))
    local later=NewFrame("Button")
    fresh.initializeFrame(later)
    eq(Last(later,"SetSize"),16,"new container size")
end)

-- Stack count: a child frame draws above all of its parent's regions, so the count must not be a region of the icon
-- frame under its full-size Cooldown child. It lives on an overlay (a child of the icon, one frame level above the
-- cooldown), bottom-right and right-justified, with a font sized from the icon size.
local function FontSize(fontString)
    local _,size,flags=Last(fontString,"SetFont")
    return size,flags
end
local function CheckCount(countText,icon,cooldown,what)
    eq(countText.kind,"FontString",what.." kind")
    local overlay=countText.parent
    if overlay==icon then error(what.." is a region of the icon frame, under the cooldown") end
    if overlay==cooldown then error(what.." is a region of the cooldown, hidden with it") end
    eq(overlay.kind,"Frame",what.." overlay kind");eq(overlay.parent,icon,what.." overlay parent")
    eq(Last(overlay,"SetFrameLevel"),cooldown:GetFrameLevel()+1,what.." overlay level above the cooldown")
    if not overlay.calls.SetAllPoints then error(what.." overlay does not cover the icon") end
    local point,x,y=Last(countText,"SetPoint")
    eq(point,"BOTTOMRIGHT",what.." point");eq(x,1,what.." x");eq(y,-1,what.." y")
    eq(Last(countText,"SetJustifyH"),"RIGHT",what.." justify")
    return overlay
end
test("count_size_from_icon_size",function()
    eq(ns.AuraCountSize(14),10,"14 px");eq(ns.AuraCountSize(19),10,"19 px")
    eq(ns.AuraCountSize(26),14,"26 px");eq(ns.AuraCountSize(32),17,"32 px")
    eq(ns.AuraCountSize(nil),10,"invalid size uses the default icon size")
end)
test("fallback_count_above_cooldown_bottom_right",function()
    local f=ns.CreatePlate(NewFrame("Frame"))
    for i,a in ipairs(f.auras) do
        eq(a.cooldown.parent,a,"aura "..i.." cooldown parent")
        eq(CheckCount(a.count,a,a.cooldown,"aura "..i.." count"),a.countFrame,"aura "..i.." count frame")
    end
end)
test("fallback_count_font_follows_aura_size",function()
    local f=ns.CreatePlate(NewFrame("Frame"))
    ns.StylePlate(f,"moteve",Options(19))
    for i,a in ipairs(f.auras) do
        local size,flags=FontSize(a.count)
        eq(size,10,"aura "..i.." count size at 19");eq(flags,"OUTLINE","aura "..i.." count outline")
    end
    ns.StylePlate(f,"moteve",Options(30))
    for i,a in ipairs(f.auras) do eq(FontSize(a.count),16,"aura "..i.." count size at 30") end
end)
test("native_count_above_cooldown_bottom_right",function()
    for _,size in ipairs({14,19,32}) do
        Load({auraSize=size,enabled=false})
        local _,options=Native(NewFrame("Frame"))
        local button=NewFrame("Button")
        options.initializeFrame(button)
        local cooldown=Last(button,"SetDurationCooldown")
        eq(cooldown.kind,"Cooldown","cooldown kind");eq(cooldown.parent,button,"cooldown parent")
        local countText=Last(button,"SetApplicationCount")
        CheckCount(countText,button,cooldown,"native count at "..size)
        local fontSize,flags=FontSize(countText)
        eq(fontSize,ns.AuraCountSize(size),"native count size at "..size);eq(flags,"OUTLINE","native count outline")
        eq(#button.calls.SetApplicationCount,1,"count registered once")
    end
end)
test("native_count_falls_back_to_button_when_rejected",function()
    Load({auraSize=19,enabled=false})
    local _,options=Native(NewFrame("Frame"))
    local button=NewFrame("Button")
    local registered={}
    function button.SetApplicationCount(self,fontString)
        if fontString.parent~=self then error("count must belong to the button") end
        registered[#registered+1]=fontString
    end
    options.initializeFrame(button)
    eq(#registered,1,"fallback count registered")
    local countText=registered[1]
    eq(countText.parent,button,"fallback count parent")
    eq(Last(countText,"SetPoint"),"BOTTOMRIGHT","fallback count point")
    eq(Last(countText,"SetJustifyH"),"RIGHT","fallback count justify")
    eq(FontSize(countText),10,"fallback count size")
end)

print(string.format("%d/%d passed",count-failures,count))
if failures>0 then os.exit(1) end
