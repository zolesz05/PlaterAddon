-- Plain-Lua tests for the own-debuff icons in MotevePlates/Skins.lua and MotevePlates/Auras.lua (Lua 5.1 or later),
-- run from the repository root:
--   lua tools/test_aura_timer.lua
-- Only the cooldown's own countdown inside the icon shows the remaining time: no separate text under the icon,
-- on the fallback icons (ns.CreatePlate) or on the native AuraContainer buttons (InitializeButton).
-- Both files are loaded against a stub `ns` and a stub CreateFrame whose frames record every method call.
-- Exits non-zero on any failure.
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

local created
local containerStub
function CreateFrame(kind,name,parent,template)
    if kind=="AuraContainer" then return containerStub end
    local frame=NewFrame(kind,parent,template)
    created[#created+1]=frame
    return frame
end

local function NewNS()
    local ns={WHITE="Interface\\Buttons\\WHITE8X8",MEDIA="Interface\\AddOns\\MotevePlates\\",db={maxAuras=6}}
    function ns.Secret() return false end
    function ns.Number(v) if type(v)=="number" then return v end end
    function ns.Bool(v) if type(v)=="boolean" then return v end end
    function ns.API(fn,...)
        if type(fn)~="function" then return nil end
        local results={pcall(fn,...)}
        if not results[1] then return nil end
        return unpack(results,2,#results)
    end
    function ns.Safe(_,fn,...)
        local ok,err=pcall(fn,...)
        if not ok then error("ns.Safe caught: "..tostring(err)) end
        return true
    end
    function ns.On() end
    return ns
end
local ns=NewNS()
assert(loadfile(root.."/MotevePlates/Skins.lua"))("MotevePlates",ns)
assert(loadfile(root.."/MotevePlates/Auras.lua"))("MotevePlates",ns)

local function test(name,fn)
    count=count+1
    created={}
    containerStub=nil
    local ok,err=pcall(fn)
    if ok then print("ok   "..name) else failures=failures+1;print("FAIL "..name..": "..tostring(err)) end
end
local function eq(actual,expected,what)
    if actual~=expected then error((what or "value")..": expected "..tostring(expected)..", got "..tostring(actual),2) end
end
-- The value passed to the last SetHideCountdownNumbers call, or "never called".
local function LastHide(cooldown)
    local calls=cooldown.calls.SetHideCountdownNumbers
    if not calls then return "never called" end
    return calls[#calls][1]
end

test("fallback_icons_have_no_timer_text",function()
    local f=ns.CreatePlate(NewFrame("Frame"))
    eq(#f.auras,12,"aura frames")
    for i,a in ipairs(f.auras) do
        eq(rawget(a,"timer"),nil,"aura "..i.." timer")
        if not a.cooldown then error("aura "..i.." has no cooldown") end
        eq(a.cooldown.template,"CooldownFrameTemplate","aura "..i.." cooldown template")
    end
end)

test("fallback_icons_show_cooldown_numbers",function()
    local f=ns.CreatePlate(NewFrame("Frame"))
    for i,a in ipairs(f.auras) do eq(LastHide(a.cooldown),false,"aura "..i.." SetHideCountdownNumbers") end
end)

test("native_button_uses_cooldown_numbers_only",function()
    local initialize
    containerStub=NewFrame("AuraContainer")
    function containerStub.AddAuraGroup(_,_,_,options) initialize=options.initializeFrame end
    local plate=NewFrame("Frame")
    ns.db.enabled=false
    eq(ns.UseNativeAuras(plate),true,"native container used")
    if type(initialize)~="function" then error("AddAuraGroup got no initializeFrame") end
    created={}
    local button=NewFrame("Button")
    initialize(button)
    eq(button.calls.SetDurationText,nil,"SetDurationText calls")
    local durationCalls=button.calls.SetDurationCooldown
    if not durationCalls then error("SetDurationCooldown not called") end
    eq(#durationCalls,1,"SetDurationCooldown calls")
    local cooldown=durationCalls[1][1]
    eq(cooldown and cooldown.kind,"Cooldown","duration cooldown kind")
    eq(cooldown.template,"CooldownFrameTemplate","duration cooldown template")
    eq(LastHide(cooldown),false,"SetHideCountdownNumbers")
end)

print(string.format("%d/%d passed",count-failures,count))
if failures>0 then os.exit(1) end
