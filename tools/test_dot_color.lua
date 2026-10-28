-- Plain-Lua tests for the DoT-marker colour choice (Lua 5.1 or later), run from the repository root:
--   lua tools/test_dot_color.lua
-- Core.lua and Skins.lua are loaded in TOC order against a stub CreateFrame whose frames record every method call,
-- so ns.DotColor, ns.StylePlate and the saved `dotColor` setting (ADDON_LOADED, ns.SetOption) run as in the client.
-- Exits non-zero on any failure.
local root=(arg and arg[0] or ""):match("^(.-)[/\\]?tools[/\\][^/\\]+$") or "."
if root=="" then root="." end
local unpack=unpack or table.unpack
local SKINS={"minimal","classic","moteve"}
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
function CreateFrame(kind,name,parent,template) return NewFrame(kind,parent,template) end
SlashCmdList={}

local ns={}
assert(loadfile(root.."/MotevePlates/Core.lua"))("MotevePlates",ns)
assert(loadfile(root.."/MotevePlates/Skins.lua"))("MotevePlates",ns)

local function test(name,fn)
    count=count+1
    local ok,err=pcall(fn)
    if ok then print("ok   "..name) else failures=failures+1;print("FAIL "..name..": "..tostring(err)) end
end
local function eq(actual,expected,what)
    if actual~=expected then error((what or "value")..": expected "..tostring(expected)..", got "..tostring(actual),2) end
end
local function color(what,expected,...)
    local n=select("#",...)
    if n~=3 then error(what..": expected 3 values, got "..n,2) end
    for i=1,3 do
        local v=select(i,...)
        if v~=expected[i] then error(what..": component "..i.." expected "..tostring(expected[i])..", got "..tostring(v),2) end
    end
end
-- Calls ns.DotColor without letting an error escape unnoticed.
local function Dot(skin,choice)
    local results={pcall(ns.DotColor,skin,choice)}
    if not results[1] then error("DotColor raised: "..tostring(results[2]),2) end
    return unpack(results,2,#results)
end
-- Loads MotevePlatesDB as the client does on login.
local function Load(saved)
    MotevePlatesDB=saved
    ns.db=nil
    ns:Fire("ADDON_LOADED","MotevePlates")
    if not ns.db then error("ADDON_LOADED did not set ns.db",2) end
end
-- The arguments of the last call to method on frame.
local function Last(frame,method)
    local calls=frame.calls[method]
    if not calls then error(method.." never called",2) end
    return unpack(calls[#calls])
end

test("skin_dot_values_unchanged",function()
    color("minimal",{1,1,1},unpack(ns.Skins.minimal.dot))
    color("classic",{0.72,0.45,1},unpack(ns.Skins.classic.dot))
    color("moteve",{0.95,0.45,1},unpack(ns.Skins.moteve.dot))
end)

test("skin_choice_uses_skin_colour",function()
    for _,skin in ipairs(SKINS) do
        color(skin.." / skin",ns.Skins[skin].dot,Dot(skin,"skin"))
        color(skin.." / nil",ns.Skins[skin].dot,Dot(skin,nil))
    end
end)

test("palette_choice_ignores_skin",function()
    local skins={"minimal","classic","moteve","neon"}
    for _,key in ipairs(ns.DotColorOrder) do
        for _,skin in ipairs(skins) do color(key.." / "..skin,ns.DotColors[key],Dot(skin,key)) end
        color(key.." / nil skin",ns.DotColors[key],Dot(nil,key))
    end
end)

test("bad_choice_and_skin_fall_back",function()
    local choices={{"unknown string","magenta"},{"upper case","RED"},{"number",3},{"table",{1,0,0}},{"boolean",true},{"index",1}}
    for _,case in ipairs(choices) do
        for _,skin in ipairs(SKINS) do color(case[1].." / "..skin,ns.Skins[skin].dot,Dot(skin,case[2])) end
    end
    local moteve=ns.Skins.moteve.dot
    color("nil skin, nil choice",moteve,Dot(nil,nil))
    color("nil skin, skin choice",moteve,Dot(nil,"skin"))
    color("unknown skin",moteve,Dot("neon","skin"))
    color("table skin",moteve,Dot({},"bogus"))
    color("number skin",moteve,Dot(2,7))
end)

test("palette_shape",function()
    local listed=0
    for i,key in ipairs(ns.DotColorOrder) do
        listed=listed+1
        if type(ns.DotColors[key])~="table" then error("DotColorOrder["..i.."] "..tostring(key).." has no colour") end
        for j=i+1,#ns.DotColorOrder do
            if ns.DotColorOrder[j]==key then error("duplicate key "..key) end
        end
    end
    eq(listed,7,"palette size")
    local keys=0
    for key,c in pairs(ns.DotColors) do
        keys=keys+1
        local found=false
        for _,k in ipairs(ns.DotColorOrder) do if k==key then found=true end end
        if not found then error("DotColors."..tostring(key).." missing from DotColorOrder") end
        if ns.Skins[key] or key=="skin" then error("palette key "..key.." clashes with a skin choice") end
        eq(#c,3,key.." components")
        for i=1,3 do
            if type(c[i])~="number" or c[i]<0 or c[i]>1 then error(key.." component "..i.." out of range: "..tostring(c[i])) end
        end
    end
    eq(keys,listed,"DotColors keys")
end)

test("style_plate_colours_marker",function()
    local f=ns.CreatePlate(NewFrame("Frame"))
    local cases={{"green","classic",ns.DotColors.green},{"skin","classic",ns.Skins.classic.dot},
        {nil,"minimal",ns.Skins.minimal.dot},{"bogus","moteve",ns.Skins.moteve.dot},{"red","minimal",ns.DotColors.red}}
    for _,case in ipairs(cases) do
        local what=tostring(case[1]).." / "..case[2]
        ns.StylePlate(f,case[2],{width=170,height=17,showLevel=true,dotColor=case[1]})
        local c=case[3]
        local function check(part,alpha,...)
            local args={...}
            eq(#args,4,what.." "..part.." argument count")
            color(what.." "..part,c,args[1],args[2],args[3])
            eq(args[4],alpha,what.." "..part.." alpha")
        end
        check("fill",0.55,Last(f.dot,"SetStatusBarColor"))
        check("stripe",0.6,Last(f.dot.stripe,"SetVertexColor"))
        check("edge",1,Last(f.dot.edge,"SetColorTexture"))
    end
end)

test("saved_value_validated_on_load",function()
    eq(ns.defaults.dotColor,"skin","default")
    Load(nil);eq(ns.db.dotColor,"skin","fresh install")
    Load({skin="classic"});eq(ns.db.dotColor,"skin","missing key")
    Load({dotColor="cyan"});eq(ns.db.dotColor,"cyan","saved palette key")
    Load({dotColor="skin"});eq(ns.db.dotColor,"skin","saved skin choice")
    for _,bad in ipairs({"bogus","moteve",3,true,{1,0,0}}) do
        Load({dotColor=bad});eq(ns.db.dotColor,"skin","saved "..tostring(bad))
    end
end)

test("set_option_accepts_only_palette_keys",function()
    Load({})
    for _,key in ipairs(ns.DotColorOrder) do
        eq(ns.SetOption("dotColor",key),true,"SetOption "..key)
        eq(ns.db.dotColor,key,"stored "..key)
    end
    eq(ns.SetOption("dotColor","skin"),true,"SetOption skin")
    eq(ns.db.dotColor,"skin","stored skin")
    ns.SetOption("dotColor","red")
    for _,bad in ipairs({"bogus","classic",{1,0,0},true,0.5}) do
        eq(ns.SetOption("dotColor",bad),false,"SetOption "..tostring(bad))
    end
    eq(ns.SetOption("dotColor",nil),false,"SetOption nil")
    eq(ns.db.dotColor,"red","rejected values leave the setting")
end)

print(string.format("%d/%d passed",count-failures,count))
if failures>0 then os.exit(1) end
