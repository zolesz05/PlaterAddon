-- Blizzard owns live aura data and updates these registered display elements.
-- Do not inspect or retain the managed buttons after their initialization.
local _,ns=...
ns:On("MP_INIT",function()
    ns.API(C_AddOns and C_AddOns.LoadAddOn or LoadAddOn,"Blizzard_AuraContainer")
end)
local function InitializeButton(button)
    button:SetSize(19,19);button:EnableMouse(false)
    local icon=button:CreateTexture(nil,"ARTWORK")
    icon:SetAllPoints();icon:SetTexCoord(0.08,0.92,0.08,0.92)
    local cooldown=CreateFrame("Cooldown",nil,button,"CooldownFrameTemplate")
    cooldown:SetAllPoints();cooldown:EnableMouse(false)
    if cooldown.SetHideCountdownNumbers then cooldown:SetHideCountdownNumbers(false) end
    local count=ns.Font(button,9,true);count:SetPoint("TOPRIGHT",1,0)
    button:SetIcon(icon)
    button:SetDurationCooldown(cooldown)
    button:SetApplicationCount(count)
end
local function CreateContainer(f)
    local ok,c=pcall(CreateFrame,"AuraContainer",nil,f,"CustomAuraContainerTemplate")
    if not ok or not c then return end
    if type(c.AddAuraGroup)~="function" then c:Hide();return end
    c:SetEnabled(false);c:Hide()
    local configured=ns.Safe("native aura setup",function()
        c:EnableMouse(false)
        c:SetFrameLevel(f:GetFrameLevel()+5)
        c:SetPoint("BOTTOMLEFT",f,"TOPLEFT",0,30)
        if c.SetEditModePreviewEnabled then c:SetEditModePreviewEnabled(false) end
        local anchor=c.SetFlowLayoutAnchorPoint or c.SetAuraLayoutAnchorPoint
        local lineWidth=c.SetFlowLayoutMaximumLineSize or c.SetAuraLayoutRowWidth
        if anchor then anchor(c,"BOTTOMLEFT") end
        if lineWidth then lineWidth(c,134) end
        local growth=c.SetFlowLayoutGrowthDirection or c.SetAuraLayoutGrowthDirection
        if growth and AnchorUtil and AnchorUtil.FlowDirection then
            growth(c,AnchorUtil.FlowDirection.Right,AnchorUtil.FlowDirection.Up)
        end
        c:AddAuraGroup("ownDebuffs","HARMFUL|PLAYER",{
            maxFrameCount=ns.db.maxAuras,initializeFrame=InitializeButton,
            layout={elementSpacing=4,lineSpacing=12},
        })
    end)
    if not configured then c:SetEnabled(false);c:Hide();return end
    f.auraLimit=ns.db.maxAuras
    return c
end
function ns.StopNativeAuras(f)
    if f.auraContainer then
        f.auraContainer:SetEnabled(false)
        f.auraContainer:SetUnit("none")
        f.auraContainer:Hide()
        f.auraUnit=nil;f.auraEnabled=false
    end
end
function ns.UseNativeAuras(f)
    if not f.auraAttempted then
        f.auraAttempted=true
        f.auraContainer=CreateContainer(f)
    end
    local c=f.auraContainer
    if not c then return false end
    if f.auraLimit~=ns.db.maxAuras then
        c:SetAuraGroupMaxFrameCount("ownDebuffs",ns.db.maxAuras)
        f.auraLimit=ns.db.maxAuras
    end
    local enabled=ns.db.enabled and ns.db.showAuras and f.unit~=nil
    if not enabled then ns.StopNativeAuras(f);return true end
    if f.auraUnit~=f.unit then
        c:SetEnabled(false);c:SetUnit(f.unit);f.auraUnit=f.unit
        f.auraEnabled=false
    end
    if not f.auraEnabled then c:Show();c:SetEnabled(true);f.auraEnabled=true end
    return true
end
