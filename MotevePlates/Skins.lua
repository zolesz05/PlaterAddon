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
-- Own-debuff icon layout shared by the fallback icons (StylePlate) and the native AuraContainer (Auras.lua): six icons
-- per row, 4 px between icons and 12 px between rows. Returns icon size, column step, row step and row width.
-- A missing or non-number size falls back to the default (19, the size before auraSize existed).
ns.AURAS_PER_ROW=6
function ns.AuraLayout(size)
    size=ns.Number(size) or (ns.defaults and ns.defaults.auraSize) or 19
    return size,size+4,size+12,ns.AURAS_PER_ROW*size+(ns.AURAS_PER_ROW-1)*4
end
-- The area a custom plate can draw on, for the stacked base plate (ns.ApplyPlateSize). In plate units, around the bar
-- (width x height): above, the name row (4 px gap + 13 px font; combo dots and quest badge fit in it) and, when shown,
-- the debuff rows from y=30 (one row per six icons of maxAuras); below, the cast bar (4 + 13) and the threat text
-- (23 + 10 under a cast, 5 + 10 without); left, the raid marker (18 + 18); right, the target arrow (4 + 12) or the
-- debuff row when it is wider than the bar. Returns the base size (width, height) in base-plate units, centred and
-- times scale, plus |offset| on both sides so the user's vertical offset stays in the slot, and the y shift that
-- puts the frame's visual centre on the base plate's centre (plate units, before the offset).
function ns.PlateFootprint(db)
    local d=db or ns.db
    local width,height,scale=d.width,d.height,d.scale
    local above,below=17,3
    local auraRight=0
    if d.showAuras then
        local size,column,row=ns.AuraLayout(d.auraSize)
        local count=math.max(1,d.maxAuras or 1)
        local rows=math.ceil(count/ns.AURAS_PER_ROW)
        above=math.max(above,30+size+(rows-1)*row)
        local perRow=math.min(count,ns.AURAS_PER_ROW)
        auraRight=perRow*column-4-width/2
    end
    if d.showCast then below=math.max(below,4+13) end
    if d.showAggro or d.showThreatPercent then below=math.max(below,(d.showCast and 23 or 5)+10) end
    local halfWidth=math.max(width/2+36,width/2+16,auraRight)
    local offset=math.abs(d.offset or 0)
    return 2*halfWidth*scale,(above+height+below+2*offset)*scale,(below-above)/2
end
-- The custom frame's y offset from the base plate's centre: the user's offset, plus the footprint's centring shift
-- while the base plate has the footprint's size (stacked).
function ns.PlateAnchorY(db,stacked)
    local d=db or ns.db
    if not stacked then return d.offset end
    local _,_,shift=ns.PlateFootprint(d)
    return d.offset+shift
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
-- Stack count of an own-debuff icon, shared by the fallback icons (CreatePlate) and the native AuraContainer buttons
-- (Auras.lua). A child frame always draws above its parent's regions, so a FontString on the icon frame would sit
-- under the icon's full-size Cooldown child (swipe and countdown). The count lives on an overlay frame, a sibling of
-- the cooldown one level above it (not its child: the fallback hides the cooldown for auras without a duration), in
-- the bottom-right corner like Blizzard's target-frame auras, outlined and sized from the icon size.
function ns.AuraCountSize(size)
    local s=ns.Number(size) or (ns.defaults and ns.defaults.auraSize) or 19
    return math.max(10,math.floor(s*0.55))
end
function ns.SizeAuraCount(count,size)
    count:SetFont(ns.MEDIA.."Fonts\\Barlow-SemiBold.ttf",ns.AuraCountSize(size),"OUTLINE")
end
function ns.CreateAuraCount(icon,cooldown,size)
    local overlay=CreateFrame("Frame",nil,icon)
    overlay:SetAllPoints();overlay:EnableMouse(false)
    overlay:SetFrameLevel(cooldown:GetFrameLevel()+1)
    local count=ns.Font(overlay,9,true);ns.SizeAuraCount(count,size)
    count:SetPoint("BOTTOMRIGHT",1,-1);count:SetJustifyH("RIGHT")
    return count,overlay
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
    -- Raid marker: its own frame left of the plate, outside the target arrow, above every aura layer (native AuraContainer at +5).
    f.raidHolder=CreateFrame("Frame",nil,f);f.raidHolder:EnableMouse(false);f.raidHolder:SetSize(18,18)
    f.raidHolder:SetFrameLevel(f:GetFrameLevel()+10);f.raidHolder:SetPoint("RIGHT",f,"LEFT",-18,0)
    f.raid=f.raidHolder:CreateTexture(nil,"OVERLAY");f.raid:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons");f.raid:SetAllPoints()
    -- Combo points (Combo.lua): five 8 px dots right-aligned in the name row, below the auras (y=30).
    f.combo=CreateFrame("Frame",nil,f);f.combo:EnableMouse(false)
    f.combo:SetSize(48,8);f.combo:SetPoint("BOTTOMRIGHT",f,"TOPRIGHT",0,4)
    for i=1,5 do
        local back=f.combo:CreateTexture(nil,"BACKGROUND");back:SetSize(10,10)
        back:SetPoint("LEFT",(i-1)*10-1,0);back:SetColorTexture(0,0,0,0.7)
        local dot=f.combo:CreateTexture(nil,"ARTWORK");dot:SetSize(8,8);dot:SetPoint("LEFT",(i-1)*10,0)
        f.combo[i]=dot
    end
    f.combo:Hide()
    f.auras={}
    for i=1,12 do
        local a=CreateFrame("Frame",nil,f,"BackdropTemplate");a:EnableMouse(false)
        a.icon=a:CreateTexture(nil,"ARTWORK");a.icon:SetAllPoints();a.icon:SetTexCoord(0.08,0.92,0.08,0.92)
        a.cooldown=CreateFrame("Cooldown",nil,a,"CooldownFrameTemplate");a.cooldown:SetAllPoints();a.cooldown:EnableMouse(false)
        if a.cooldown.SetHideCountdownNumbers then a.cooldown:SetHideCountdownNumbers(false) end
        a.count,a.countFrame=ns.CreateAuraCount(a,a.cooldown)
        a:Hide() -- size and position come from auraSize in StylePlate
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
    for i=1,#f.combo do f.combo[i]:SetColorTexture(s.accent[1],s.accent[2],s.accent[3],1) end
    f.combo.count=nil;f.nameWidth=d.width;f.nameNarrow=false
    f.targetLeft:SetTextColor(s.accent[1],s.accent[2],s.accent[3])
    f.targetRight:SetTextColor(s.accent[1],s.accent[2],s.accent[3])
    local size,column,row=ns.AuraLayout(d.auraSize)
    for i,a in ipairs(f.auras) do
        a:SetSize(size,size);a:ClearAllPoints();ns.SizeAuraCount(a.count,size)
        a:SetPoint("BOTTOMLEFT",f,"TOPLEFT",((i-1)%ns.AURAS_PER_ROW)*column,30+math.floor((i-1)/ns.AURAS_PER_ROW)*row)
    end
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
