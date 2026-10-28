local _,ns=...
local P=CreateFrame("Frame","MotevePlatesOptions",UIParent)
P.name="Moteve Plates";P:SetSize(660,650);P:Hide()
P:EnableMouse(true)
local floatingBackground=P:CreateTexture(nil,"BACKGROUND")
floatingBackground:SetAllPoints();floatingBackground:SetColorTexture(0.035,0.04,0.075,0.97);floatingBackground:Hide()
ns.Options=P
local scroll=CreateFrame("ScrollFrame",nil,P,"UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT",0,0);scroll:SetPoint("BOTTOMRIGHT",-28,0)
local body=CreateFrame("Frame",nil,scroll);body:SetSize(620,765);scroll:SetScrollChild(body)
local function Text(parent,x,y,text,size,color)
    local t=ns.Font(parent,size or 13,false);t:SetPoint("TOPLEFT",x,y);t:SetJustifyH("LEFT");t:SetText(text)
    if color then t:SetTextColor(color[1],color[2],color[3]) end
    return t
end
Text(body,20,-14,"Moteve Plates",23,{0.66,0.55,1})
Text(body,20,-44,"Válassz skint – a változások azonnal érvényesek.",13)
local function Button(parent,x,y,w,label,fn)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:SetSize(w,26);b:SetPoint("TOPLEFT",x,y)
    b:SetBackdrop({bgFile=ns.WHITE,edgeFile=ns.WHITE,edgeSize=1})
    b:SetBackdropColor(0.055,0.065,0.12,0.98);b:SetBackdropBorderColor(0.40,0.36,0.57,1)
    b.text=ns.Font(b,12,true);b.text:SetPoint("CENTER");b.text:SetText(label)
    b:SetScript("OnClick",fn)
    return b
end
ns.previewPlates={}
local skinButtons={}
for i,key in ipairs({"minimal","classic","moteve"}) do
    local skin=key
    local b=Button(body,20+(i-1)*195,-68,185,ns.Skins[skin].label,function() ns.SetOption("skin",skin) end)
    b:SetHeight(150);b.text:ClearAllPoints();b.text:SetPoint("TOP",0,-9)
    local demo=ns.CreatePlate(b)
    demo:SetPoint("CENTER",b,"CENTER",0,-10);demo:SetScale(0.85)
    ns.previewPlates[i]=demo;skinButtons[skin]=b
end
local roleLabel=Text(body,20,-233,"Aggro szerepkör",13)
local roleButtons={}
for i,role in ipairs({"auto","tank","dps"}) do
    local r=role
    local b=Button(body,158+(i-1)*143,-228,135,"",function() ns.SetOption("role",r) end)
    roleButtons[r]=b
end
local checks={}
local definitions={
    {"enabled","Addon bekapcsolva"},{"showAggro","Aggro szöveges jelzése"},
    {"colorThreat","Életerősáv színezése aggro szerint"},{"showThreatPercent","Fenyegetettségi százalék"},
    {"showCast","Cast / channel sáv"},{"showAuras","Saját debuffok megjelenítése"},
    {"healthText","Életerő értéke"},{"healthPercent","Életerő százaléka"},
    {"showLevel","Szint és elit jelzés"},{"dimOthers","Nem célzott ellenfelek halványítása"},
    {"showDotPrediction","DoT-sebzés előrejelzése"},{"showQuest","Küldetésmobok kiemelése"},
}
for i,definition in ipairs(definitions) do
    local key,label=definition[1],definition[2]
    local cb=CreateFrame("CheckButton",nil,body,"UICheckButtonTemplate")
    cb:SetSize(24,24)
    if key=="showQuest" then cb:SetPoint("TOPLEFT",320,-734)
    else cb:SetPoint("TOPLEFT",20+((i-1)%2)*300,-268-math.floor((i-1)/2)*30) end
    local stock=cb.Text or cb.text;if stock and stock.SetText then stock:SetText("") end
    local t=ns.Font(cb,12,false);t:SetPoint("LEFT",cb,"RIGHT",3,0);t:SetWidth(260);t:SetText(label);t:SetJustifyH("LEFT")
    cb:SetHitRectInsets(0,-260,-2,-2)
    cb:SetScript("OnClick",function(self) ns.SetOption(key,self:GetChecked() and true or false) end)
    checks[key]=cb
end
Text(body,20,-458,"Zöld: rendben  •  Sárga: bizonytalan  •  Piros: veszély  •  Szürke / ?: nincs biztos adat",12,{0.75,0.79,0.89})
Text(body,20,-476,"DPS/heal: rád kerülő aggro veszélyes. Tank: az elvesztett aggro veszélyes.",12,{0.75,0.79,0.89})
local values={}
local function Adjust(x,y,key,label,step,formatValue)
    Text(body,x,y-5,label,12)
    Button(body,x+116,y,26,"-",function() ns.SetOption(key,ns.db[key]-step) end)
    local value=ns.Font(body,12,true);value:SetPoint("TOPLEFT",x+150,y-6);value:SetWidth(54);value:SetJustifyH("CENTER")
    Button(body,x+210,y,26,"+",function() ns.SetOption(key,ns.db[key]+step) end)
    values[key]={text=value,format=formatValue}
end
Adjust(20,-505,"scale","Méretarány",0.05,function(v) return string.format("%d%%",math.floor(v*100+0.5)) end)
Adjust(320,-505,"width","Szélesség",10,function(v) return tostring(math.floor(v)) end)
Adjust(20,-539,"height","Sávmagasság",1,function(v) return tostring(math.floor(v)) end)
Adjust(320,-539,"warningAt","DPS figyelmeztetés",5,function(v) return tostring(math.floor(v)).."%" end)
Adjust(20,-573,"offset","Függőleges eltolás",2,function(v) return tostring(math.floor(v)) end)
Adjust(20,-607,"distance","Látótáv (yd)",5,function(v) return string.format("%g",v) end)
Adjust(320,-607,"maxAuras","Debuffok száma",1,function(v) return tostring(v) end)
local distanceStatus=Text(body,20,-643,"",11,{0.75,0.79,0.89})
distanceStatus:SetWidth(575);distanceStatus:SetHeight(32)
Text(body,20,-680,"A kért látótáv 5–100 yd; a játék saját határa továbbra is érvényes.",11,{0.65,0.68,0.79})
Button(body,320,-573,236,"Ellenséges névtáblák bekapcsolása",function()
    if InCombatLockdown and InCombatLockdown() then ns.Print("A névtáblákat harc után kapcsold be, vagy nyomj V-t.");return end
    local fn=C_CVar and C_CVar.SetCVar or SetCVar
    if fn then
        local ok=pcall(fn,"nameplateShowEnemies",1)
        if ok then ns.Print("Ellenséges névtáblák bekapcsolva.") end
    end
end)
Text(body,20,-697,"Ha az automatikus felismerés nem talál tank szerepet, válaszd kézzel a Tank módot.",11,{0.65,0.68,0.79})
Text(body,20,-714,"A százalék és az aggro állapota a kliens által hozzáférhető adatoktól függ.",11,{0.65,0.68,0.79})
Button(body,20,-734,160,"Alapbeállítások",function()
    for key,value in pairs(ns.defaults) do ns.db[key]=value end
    ns.ApplyDistance()
    ns.ApplyOptions();ns.UpdateOptions()
end)
local function Demo(f,skin)
    local d={};for key,value in pairs(ns.db) do d[key]=value end
    d.width=170;d.height=17;d.showLevel=true
    ns.StylePlate(f,skin,d);f:SetScale(0.85);f:SetAlpha(1)
    f.name:SetText("Kolkar Stormer");f.level:SetText("16")
    f.health:SetMinMaxValues(0,3500);f.health:SetValue(2450)
    f.dot:SetMinMaxValues(0,3500);f.dot:SetValue(900);f.dot:SetShown(d.showDotPrediction and f.dot.reverseFill)
    f.healthText:SetText("2.45k");f.healthText:SetShown(d.healthText)
    f.healthPct:SetText("70%");f.healthPct:SetShown(d.healthPercent)
    f.targetLeft:Show();f.targetRight:Show();f.raid:Hide();f.glow:SetShown(skin=="moteve")
    f.cast:SetMinMaxValues(0,3);f.cast:SetValue(1.8);f.cast:SetStatusBarColor(0.95,0.7,0.12)
    f.cast.name:SetText("Lightning Bolt");f.cast.time:SetText("1.2s")
    f.cast.icon:SetTexture("Interface\\Icons\\Spell_Nature_Lightning")
    f.cast:SetShown(d.showCast);f.cast.icon:SetShown(d.showCast)
    local icons={"Ability_Warrior_Rend","Spell_Shadow_ShadowWordPain","Spell_Fire_Fireball"}
    for i,a in ipairs(f.auras) do
        a.icon:SetTexture("Interface\\Icons\\"..icons[(i-1)%3+1]);a.cooldown:SetCooldown(GetTime()-2,30+i*10);a.cooldown:Show();a.count:SetText("");a:SetShown(d.showAuras and i<=math.min(3,d.maxAuras))
    end
    local role=ns.GetRole()
    local state=ns.ClassifyThreat(role,{inCombat=true,status=3,tanking=true,percent=100},d.warningAt)
    local color=d.colorThreat and state.color or ns.ThreatStates.neutral.color
    f.health:SetStatusBarColor(color[1],color[2],color[3])
    f.threatText:SetText(ns.ThreatLabel(state,role));f.threatPct:SetText("100%")
    f.threatText:SetTextColor(state.color[1],state.color[2],state.color[3]);f.threatPct:SetTextColor(state.color[1],state.color[2],state.color[3])
    ns.PlaceThreatText(f,true,d)
end
function ns.UpdateOptions()
    if not ns.db then return end
    for i,key in ipairs({"minimal","classic","moteve"}) do
        Demo(ns.previewPlates[i],key)
        local c=ns.db.skin==key and {0.66,0.55,1} or {0.35,0.37,0.43}
        skinButtons[key]:SetBackdropBorderColor(c[1],c[2],c[3],1)
    end
    for key,cb in pairs(checks) do cb:SetChecked(ns.db[key]) end
    roleButtons.auto.text:SetText("Auto: "..(ns.GetRole()=="tank" and "Tank" or "DPS/heal"))
    roleButtons.tank.text:SetText("Tank");roleButtons.dps.text:SetText("DPS / healer")
    for key,b in pairs(roleButtons) do
        local c=ns.db.role==key and {0.66,0.55,1} or {0.35,0.37,0.43}
        b:SetBackdropBorderColor(c[1],c[2],c[3],1)
    end
    for key,v in pairs(values) do v.text:SetText(v.format(ns.db[key])) end
    distanceStatus:SetText(ns.DistanceStatus())
end
P:SetScript("OnShow",function() ns.UpdateOptions() end)
ns:On("MP_INIT",ns.UpdateOptions)
ns:On("PLAYER_LOGIN",function()
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local ok,cat=pcall(Settings.RegisterCanvasLayoutCategory,P,P.name)
        if ok and cat then
            local added=pcall(Settings.RegisterAddOnCategory,cat)
            if added then ns.category=cat end
        end
    elseif InterfaceOptions_AddCategory then pcall(InterfaceOptions_AddCategory,P) end
end)
local close=Button(P,608,-4,24,"×",function() P:Hide() end);close:Hide()
function ns.OpenOptions()
    if Settings and Settings.OpenToCategory and ns.category then
        local id=ns.category.GetID and ns.category:GetID() or ns.category.ID
        if pcall(Settings.OpenToCategory,id) then return end
    elseif InterfaceOptionsFrame_OpenToCategory then
        if pcall(InterfaceOptionsFrame_OpenToCategory,P) then return end
    end
    P:SetParent(UIParent);P:ClearAllPoints();P:SetPoint("CENTER");P:SetFrameStrata("DIALOG")
    floatingBackground:Show()
    close:Show();P:Show()
end
for _,event in ipairs({"PLAYER_ROLES_ASSIGNED","PLAYER_SPECIALIZATION_CHANGED","GROUP_ROSTER_UPDATE"}) do
    ns:On(event,function() if P:IsShown() then ns.UpdateOptions() end end)
end
