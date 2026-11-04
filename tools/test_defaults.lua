-- Plain-Lua tests for the default settings of a new install (Lua 5.1 or later), run from the repository root:
--   lua tools/test_defaults.lua
-- Core.lua and Skins.lua are loaded in TOC order against a stub CreateFrame, then MotevePlatesDB is loaded through
-- ADDON_LOADED as in the client: a new install gets the Classic skin with DoT prediction on, saved values are kept,
-- and invalid saved values are replaced by the defaults. Exits non-zero on any failure.
local root=(arg and arg[0] or ""):match("^(.-)[/\\]?tools[/\\][^/\\]+$") or "."
if root=="" then root="." end
local failures,count=0,0

-- A frame stub: any method (a capitalised key) is a no-op; unset lowercase fields stay nil.
local frameMethods={}
local function NewFrame(kind,parent,template)
    local frame={kind=kind,parent=parent,template=template}
    return setmetatable(frame,{__index=function(t,key)
        if frameMethods[key] then return frameMethods[key] end
        if type(key)~="string" or not key:match("^%u") then return nil end
        return function() end
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
-- Loads MotevePlatesDB as the client does on login; every case starts from the table (or nil) it passes.
local function Load(saved)
    MotevePlatesDB=saved
    ns.db=nil
    ns:Fire("ADDON_LOADED","MotevePlates")
    if not ns.db then error("ADDON_LOADED did not set ns.db",2) end
end

test("fresh_install_nil_db",function()
    Load(nil)
    eq(ns.db.skin,"classic","skin")
    eq(ns.db.showDotPrediction,true,"showDotPrediction")
    eq(MotevePlatesDB,ns.db,"saved table")
end)
test("fresh_install_empty_db",function()
    Load({})
    eq(ns.db.skin,"classic","skin")
    eq(ns.db.showDotPrediction,true,"showDotPrediction")
end)
test("saved_values_kept",function()
    Load({skin="moteve",showDotPrediction=false})
    eq(ns.db.skin,"moteve","skin")
    eq(ns.db.showDotPrediction,false,"showDotPrediction")
end)
test("saved_other_skin_kept",function()
    Load({skin="minimal",showDotPrediction=true})
    eq(ns.db.skin,"minimal","skin")
    eq(ns.db.showDotPrediction,true,"showDotPrediction")
end)
test("invalid_values_replaced",function()
    Load({skin="neon",showDotPrediction="igen"})
    eq(ns.db.skin,"classic","skin")
    eq(ns.db.showDotPrediction,true,"showDotPrediction")
end)
test("defaults_table",function()
    eq(ns.defaults.skin,"classic","ns.defaults.skin")
    eq(ns.defaults.showDotPrediction,true,"ns.defaults.showDotPrediction")
end)

print(string.format("%d/%d passed",count-failures,count))
if failures>0 then os.exit(1) end
