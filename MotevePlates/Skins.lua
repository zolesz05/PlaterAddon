local _,ns=...
local WHITE=ns.WHITE
ns.Skins={
    minimal={label="Minimal",edge={0.65,0.68,0.72},accent={0.94,0.96,1},bg={0.025,0.027,0.03},dot={1,1,1},texture=WHITE},
    classic={label="Classic",edge={0.57,0.43,0.21},accent={1,0.82,0.38},bg={0.055,0.04,0.025},dot={0.72,0.45,1},texture="Interface\\TargetingFrame\\UI-StatusBar"},
    moteve={label="Moteve",edge={0.43,0.35,0.65},accent={0.5,0.85,1},bg={0.035,0.045,0.10},dot={0.95,0.45,1},texture=WHITE},
}
-- DoT-marker palette; ns.DotColorOrder sets the panel order. "skin" (the default) uses the skin's own dot colour.
ns.DotColors={
    white={1,1,1},purple={0.72,0.45,1},pink={0.95,0.45,1},green={0.45,1,0.55},
    yellow={1,0.95,0.3},cyan={0.3,0.9,1},red={1,0.3,0.3},
}
ns.DotColorOrder={"white","purple","pink","green","yellow","cyan","red"}
function ns.DotColor(skin,choice)
    local c=type(choice)=="string" and ns.DotColors[choice]
    if not c then c=(ns.Skins[skin] or ns.Skins.moteve).dot end
    return c[1],c[2],c[3]
end
-- Level number colour: the client's difficulty colour, red for skull (-1) mobs, otherwise the skin accent.
function ns.LevelColor(level,skin)
    local s=ns.Skins[skin] or ns.Skins.moteve
    level=ns.Number(level)
    if level==-1 then return 1,0.1,0.1 end
    if level and level>0 then
        local c=ns.API(GetQuestDifficultyColor,level)
        if not ns.Secret(c) and type(c)=="table" then
            local r,g,b=ns.Number(c.r),ns.Number(c.g),ns.Number(c.b)
            if r and g and b then return r,g,b end
        end
    end
    return s.accent[1],s.accent[2],s.accent[3]
end
function ns.Font(parent,size,bold)
    local f=parent:CreateFontString(nil,"OVERLAY")
    f:SetFont(ns.MEDIA.."Fonts\\"..(bold and "Barlow-SemiBold.ttf" or "Barlow-Regular.ttf"),size,"")
    f:SetShadowColor(0,0,0,1);f:SetShadowOffset(1,-1);f:SetWordWrap(false)
    f:SetTextColor(0.95,0.95,0.98)
    return f
end
local function Backdrop(frame,skin,target,noFill)
    local s=ns.Skins[skin]
    frame:SetBackdrop({bgFile=WHITE,edgeFile=skin=="classic" and "Interface\\Tooltips\\UI-Tooltip-Border" or WHITE,
        edgeSize=skin=="classic" and 9 or 1,insets={left=1,right=1,top=1,bottom=1}})
    frame:SetBackdropColor(s.bg[1],s.bg[2],s.bg[3],noFill and 0 or 0.96)
    local c=target and s.accent or s.edge
    frame:SetBackdropBorderColor(c[1],c[2],c[3],1)
end
function ns.CreatePlate(parent)
    local f=CreateFrame("Frame",nil,parent)
    f:EnableMouse(false)
    f:SetFrameLevel(parent:GetFrameLevel()+10)
    f.glow=CreateFrame("Frame",nil,f,"BackdropTemplate");f.glow:EnableMouse(false)
    f.glow:SetPoint("TOPLEFT",-3,3);f.glow:SetPoint("BOTTOMRIGHT",3,-3)
    f.glow:SetBackdrop({edgeFile=WHITE,edgeSize=2});f.glow:SetBackdropBorderColor(0.56,0.38,1,0.22)
    f.chrome=CreateFrame("Frame",nil,f,"BackdropTemplate");f.chrome:SetAllPoints();f.chrome:EnableMouse(false)
    f.health=CreateFrame("StatusBar",nil,f);f.health:EnableMouse(false)
    f.health:SetFrameLevel(f.chrome:GetFrameLevel()+1)
    f.health.sheen=f.health:CreateTexture(nil,"OVERLAY");f.health.sheen:SetPoint("TOPLEFT");f.health.sheen:SetPoint("TOPRIGHT");f.health.sheen:SetHeight(1)
    f.health.sheen:SetColorTexture(1,1,1,0.14)
    -- DoT marker: a reverse-fill bar ending at the health fill's end, clipped to the health bar (geometry in StylePlate).
    f.dotClip=CreateFrame("Frame",nil,f.health);f.dotClip:EnableMouse(false)
    f.dotClip:SetFrameLevel(f.health:GetFrameLevel()+1)
    if f.dotClip.SetClipsChildren then f.dotClip:SetClipsChildren(true) end
    f.dot=CreateFrame("StatusBar",nil,f.dotClip);f.dot:EnableMouse(false);f.dot:Hide()
    f.dot.reverseFill=f.dot.SetReverseFill and pcall(f.dot.SetReverseFill,f.dot,true) or false
    f.dot:SetStatusBarTexture(WHITE)
    f.dot.stripe=f.dot:CreateTexture(nil,"ARTWORK",nil,1)
    f.dot.stripe:SetShown(ns.Bool(ns.API(f.dot.stripe.SetTexture,f.dot.stripe,"Interface\\RaidFrame\\Absorb-Overlay","REPEAT","REPEAT"))==true)
    if f.dot.stripe.SetHorizTile then f.dot.stripe:SetHorizTile(true) end
    f.dot.edge=f.dot:CreateTexture(nil,"OVERLAY");f.dot.edge:SetWidth(1)
    f.healthOverlay=CreateFrame("Frame",nil,f.health);f.healthOverlay:SetAllPoints();f.healthOverlay:EnableMouse(false)
    f.healthOverlay:SetFrameLevel(f.health:GetFrameLevel()+3)
    f.healthText=ns.Font(f.healthOverlay,11,true);f.healthText:SetPoint("LEFT",5,0)
    f.healthText:SetJustifyH("LEFT")
    f.healthPct=ns.Font(f.healthOverlay,11,true);f.healthPct:SetPoint("RIGHT",-5,0)
    f.healthPct:SetJustifyH("RIGHT")
    f.name=ns.Font(f,13,true);f.name:SetPoint("BOTTOMLEFT",f,"TOPLEFT",0,4);f.name:SetJustifyH("LEFT")
    f.questBadge=CreateFrame("Frame",nil,f);f.questBadge:EnableMouse(false)
    f.questBadge:SetSize(12,16);f.questBadge:SetPoint("RIGHT",f.name,"LEFT",-3,0)
    f.questBadge.icon=ns.Font(f.questBadge,14,true);f.questBadge.icon:SetText("!")
    f.questBadge.icon:SetPoint("CENTER");f.questBadge.icon:SetTextColor(0.88,0.73,0.40)
    f.questBadge:Hide()
    f.level=ns.Font(f.chrome,10,true);f.level:SetPoint("LEFT",4,0);f.level:SetWidth(19);f.level:SetJustifyH("CENTER")
    f.targetLeft=ns.Font(f,22,true);f.targetLeft:SetText("›");f.targetLeft:SetPoint("RIGHT",f,"LEFT",-4,0)
    f.targetRight=ns.Font(f,22,true);f.targetRight:SetText("‹");f.targetRight:SetPoint("LEFT",f,"RIGHT",4,0)
    f.cast=CreateFrame("StatusBar",nil,f);f.cast:EnableMouse(false)
    f.cast.bg=f.cast:CreateTexture(nil,"BACKGROUND");f.cast.bg:SetAllPoints();f.cast.bg:SetColorTexture(0.025,0.025,0.03,0.94)
    f.cast.edge=CreateFrame("Frame",nil,f.cast,"BackdropTemplate");f.cast.edge:SetAllPoints();f.cast.edge:EnableMouse(false)
    f.cast.name=ns.Font(f.cast,10,true);f.cast.name:SetPoint("LEFT",5,0);f.cast.name:SetJustifyH("LEFT")
    f.cast.time=ns.Font(f.cast,10,true);f.cast.time:SetPoint("RIGHT",-3,0);f.cast.time:SetJustifyH("RIGHT")
    f.cast.icon=f:CreateTexture(nil,"ARTWORK");f.cast.icon:SetTexCoord(0.08,0.92,0.08,0.92)
    f.threatText=ns.Font(f,10,true);f.threatText:SetJustifyH("LEFT")
    f.threatPct=ns.Font(f,10,true);f.threatPct:SetJustifyH("RIGHT")
    f.raid=f:CreateTexture(nil,"OVERLAY");f.raid:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons");f.raid:SetSize(18,18)
    f.raid:SetPoint("BOTTOM",f,"TOP",0,54)
    f.auras={}
    for i=1,12 do
        local a=CreateFrame("Frame",nil,f,"BackdropTemplate");a:SetSize(19,19);a:EnableMouse(false)
        a.icon=a:CreateTexture(nil,"ARTWORK");a.icon:SetAllPoints();a.icon:SetTexCoord(0.08,0.92,0.08,0.92)
        a.cooldown=CreateFrame("Cooldown",nil,a,"CooldownFrameTemplate");a.cooldown:SetAllPoints();a.cooldown:EnableMouse(false)
        if a.cooldown.SetHideCountdownNumbers then a.cooldown:SetHideCountdownNumbers(false) end
        a.count=ns.Font(a,9,true);a.count:SetPoint("TOPRIGHT",1,0)
        a:SetPoint("BOTTOMLEFT",f,"TOPLEFT",((i-1)%6)*23,30+math.floor((i-1)/6)*31);a:Hide()
        f.auras[i]=a
    end
    return f
end
function ns.StylePlate(f,skin,options)
    local d=options or ns.db
    local s=ns.Skins[skin]
    f.skin=skin
    f:SetSize(d.width,d.height)
    f.name:SetWidth(d.width)
    f.name:SetFont(ns.MEDIA.."Fonts\\"..(skin=="classic" and "Marcellus-Regular.ttf" or "Barlow-SemiBold.ttf"),13,"")
    f.level:SetShown(d.showLevel)
    f.level:SetTextColor(s.accent[1],s.accent[2],s.accent[3])
    local left=d.showLevel and 25 or 2
    f.health:ClearAllPoints();f.health:SetPoint("TOPLEFT",left,-2);f.health:SetPoint("BOTTOMRIGHT",-2,2)
    f.health:SetStatusBarTexture(s.texture)
    f.dotClip:ClearAllPoints();f.dotClip:SetPoint("TOPLEFT",f.health,"TOPLEFT");f.dotClip:SetPoint("BOTTOMRIGHT",f.health,"BOTTOMRIGHT")
    f.dot:SetSize(d.width-left-2,d.height-4)
    f.dot:ClearAllPoints();f.dot:SetPoint("RIGHT",f.health:GetStatusBarTexture(),"RIGHT")
    local fill=f.dot:GetStatusBarTexture()
    local dr,dg,db=ns.DotColor(skin,d.dotColor)
    f.dot:SetStatusBarColor(dr,dg,db,0.55)
    f.dot.stripe:ClearAllPoints();f.dot.stripe:SetAllPoints(fill);f.dot.stripe:SetVertexColor(dr,dg,db,0.6)
    f.dot.edge:ClearAllPoints();f.dot.edge:SetPoint("TOPLEFT",fill,"TOPLEFT");f.dot.edge:SetPoint("BOTTOMLEFT",fill,"BOTTOMLEFT")
    f.dot.edge:SetColorTexture(dr,dg,db,1)
    f.healthText:SetWidth((d.width-left)*0.57)
    f.healthPct:SetWidth((d.width-left)*0.35)
    f.cast:ClearAllPoints();f.cast:SetPoint("TOPLEFT",f,"BOTTOMLEFT",19,-4)
    f.cast:SetPoint("TOPRIGHT",f,"BOTTOMRIGHT",0,-4);f.cast:SetHeight(13)
    f.cast:SetStatusBarTexture(s.texture)
    f.cast.name:SetWidth(d.width-65);f.cast.time:SetWidth(40)
    f.cast.icon:SetSize(15,15);f.cast.icon:ClearAllPoints();f.cast.icon:SetPoint("RIGHT",f.cast,"LEFT",-3,0)
    Backdrop(f.chrome,skin,false);Backdrop(f.cast.edge,skin,false,true)
    f.lastTarget=nil
    f.targetLeft:SetTextColor(s.accent[1],s.accent[2],s.accent[3])
    f.targetRight:SetTextColor(s.accent[1],s.accent[2],s.accent[3])
end
function ns.TargetStyle(f,target,hasTarget)
    if f.lastTarget~=target then Backdrop(f.chrome,f.skin,target);f.lastTarget=target end
    f.targetLeft:SetShown(target);f.targetRight:SetShown(target)
    f.glow:SetShown(target and f.skin=="moteve")
    f:SetAlpha(ns.db.dimOthers and hasTarget and not target and 0.72 or 1)
    f:SetScale(ns.db.scale*(target and 1.05 or 1))
end
function ns.PlaceThreatText(f,visible,options)
    local d=options or ns.db
    f.threatText:ClearAllPoints();f.threatPct:ClearAllPoints()
    local y=f.cast:IsShown() and -23 or -5
    f.threatText:SetPoint("TOPLEFT",f,"BOTTOMLEFT",0,y);f.threatText:SetWidth(d.width-58)
    f.threatPct:SetPoint("TOPRIGHT",f,"BOTTOMRIGHT",0,y);f.threatPct:SetWidth(56)
    f.threatText:SetShown(visible and d.showAggro);f.threatPct:SetShown(visible and d.showThreatPercent)
end
