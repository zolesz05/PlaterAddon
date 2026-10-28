-- Plain-Lua tests for ns.LevelColor in MotevePlates/Skins.lua (Lua 5.1 or later), run from the repository root:
--   lua tools/test_level_color.lua
-- Skins.lua is loaded against a stub `ns`; GetQuestDifficultyColor is stubbed per case. Exits non-zero on any failure.
local root=(arg and arg[0] or ""):match("^(.-)[/\\]?tools[/\\][^/\\]+$") or "."
if root=="" then root="." end
local unpack=unpack or table.unpack
local SECRET=setmetatable({},{__tostring=function() return "<secret>" end})
local SKINS={"minimal","classic","moteve"}
local failures,count=0,0

local function NewNS()
    local ns={WHITE="Interface\\Buttons\\WHITE8X8"}
    function ns.Secret(v) return v==SECRET end
    function ns.Number(v)
        if v==SECRET or type(v)~="number" or v~=v or v==math.huge or v==-math.huge then return nil end
        return v
    end
    function ns.API(fn,...)
        if type(fn)~="function" then return nil end
        local results={pcall(fn,...)}
        if not results[1] then return nil end
        return unpack(results,2,#results)
    end
    return ns
end
local ns=NewNS()
assert(loadfile(root.."/MotevePlates/Skins.lua"))("MotevePlates",ns)

local function test(name,fn)
    count=count+1
    GetQuestDifficultyColor=nil
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
-- Calls ns.LevelColor without letting an error escape unnoticed.
local function Level(level,skin)
    local results={pcall(ns.LevelColor,level,skin)}
    if not results[1] then error("LevelColor raised: "..tostring(results[2]),2) end
    return unpack(results,2,4)
end

test("difficulty_color_returned",function()
    local shared={r=0.5,g=0.5,b=0.5}
    local seen={}
    GetQuestDifficultyColor=function(level) seen[#seen+1]=level;return shared end
    for _,skin in ipairs(SKINS) do color(skin,{0.5,0.5,0.5},Level(5,skin)) end
    eq(#seen,3,"called once per skin")
    for i=1,3 do eq(seen[i],5,"level passed through") end
    eq(shared.r,0.5,"shared table r");eq(shared.g,0.5,"shared table g");eq(shared.b,0.5,"shared table b")
    local keys=0
    for _ in pairs(shared) do keys=keys+1 end
    eq(keys,3,"shared table untouched")
    GetQuestDifficultyColor=function() return {r=1,g=0.82,b=0,font="QuestDifficulty_Difficult"} end
    color("extra fields",{1,0.82,0},Level(60,"moteve"))
end)

test("skull_level_is_red",function()
    local called=false
    GetQuestDifficultyColor=function() called=true;return {r=0.5,g=0.5,b=0.5} end
    for _,skin in ipairs(SKINS) do color(skin,{1,0.1,0.1},Level(-1,skin)) end
    eq(called,false,"difficulty colour not consulted")
end)

test("missing_function_falls_back",function()
    GetQuestDifficultyColor=nil
    for _,skin in ipairs(SKINS) do color(skin,ns.Skins[skin].accent,Level(5,skin)) end
    GetQuestDifficultyColor="not a function"
    for _,skin in ipairs(SKINS) do color(skin.." (non-function)",ns.Skins[skin].accent,Level(5,skin)) end
end)

test("erroring_function_falls_back",function()
    GetQuestDifficultyColor=function() error("blocked") end
    for _,skin in ipairs(SKINS) do color(skin,ns.Skins[skin].accent,Level(5,skin)) end
end)

test("malformed_result_falls_back",function()
    local results={
        {"nil",nil},{"number",1},{"string","red"},{"secret",SECRET},
        {"missing b",{r=0.5,g=0.5}},{"string r",{r="1",g=0.5,b=0.5}},
        {"NaN g",{r=0.5,g=0/0,b=0.5}},{"secret b",{r=0.5,g=0.5,b=SECRET}},{"array",{0.5,0.5,0.5}},
    }
    for _,case in ipairs(results) do
        GetQuestDifficultyColor=function() return case[2] end
        for _,skin in ipairs(SKINS) do color(case[1].." / "..skin,ns.Skins[skin].accent,Level(5,skin)) end
    end
end)

test("secret_nil_zero_level_falls_back",function()
    local called=0
    GetQuestDifficultyColor=function() called=called+1;return {r=0.5,g=0.5,b=0.5} end
    for _,skin in ipairs(SKINS) do
        local accent=ns.Skins[skin].accent
        color("secret / "..skin,accent,Level(SECRET,skin))
        color("nil / "..skin,accent,Level(nil,skin))
        color("zero / "..skin,accent,Level(0,skin))
        color("string / "..skin,accent,Level("-1",skin))
        color("NaN / "..skin,accent,Level(0/0,skin))
    end
    eq(called,0,"difficulty colour not consulted")
end)

test("unknown_skin_safe",function()
    color("nil skin",ns.Skins.moteve.accent,Level(nil,nil))
    color("unknown skin",ns.Skins.moteve.accent,Level(5,"neon"))
    GetQuestDifficultyColor=function() return {r=0.25,g=0.75,b=0.25} end
    color("unknown skin with colour",{0.25,0.75,0.25},Level(5,"neon"))
    color("unknown skin, skull",{1,0.1,0.1},Level(-1,nil))
end)

print(string.format("%d/%d passed",count-failures,count))
if failures>0 then os.exit(1) end
