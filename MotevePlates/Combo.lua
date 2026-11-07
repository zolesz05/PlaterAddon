local _,ns=...
-- Combo points for Rogues and Druids on the plate of the mob they were built on (the owner): five dots in the name row
-- (built in ns.CreatePlate, coloured in ns.StylePlate), earned points in the skin accent, free slots dimmed.
local MAX=5
local DIM=0.25
-- Room the name gives up while the dots show: five 8 px dots, four 2 px gaps and a 6 px margin.
local NAME_GAP=54
ns.COMBO_MAX,ns.COMBO_NAME_GAP=MAX,NAME_GAP
local COMBO_CLASSES={ROGUE=true,DRUID=true}
local playerClass
-- Whether the player's class (locale-independent class file, cached once readable) builds combo points.
function ns.ComboClass()
    if not playerClass then
        local _,file=ns.API(UnitClass,"player")
        if not ns.Secret(file) and type(file)=="string" and file~="" then playerClass=file end
    end
    return playerClass~=nil and COMBO_CLASSES[playerClass]==true
end
-- The combo points on the current target, 0–5, or nil when the client gives no readable number.
-- Same order as the DoT tracker: the target-bound GetComboPoints first, the player-level UnitPower only when that is nil.
-- The second value is true when the count came from the target-bound GetComboPoints.
function ns.ReadComboPoints()
    local bound=true
    local points=ns.Number(ns.API(GetComboPoints,"player","target"))
    if points==nil then points=ns.Number(ns.API(UnitPower,"player",4));bound=false end
    if points==nil then return nil,false end
    return math.max(0,math.min(MAX,math.floor(points))),bound
end
-- The one mob that owns the points: its GUID and count. Module-level, so a new owner sends every other plate to 0.
local ownerGUID,ownerCount=nil,0
-- A plate unit's GUID as a plain non-empty string, or nil (missing unit, secret or unreadable value).
local function GUID(unit)
    if ns.Secret(unit) or type(unit)~="string" then return nil end
    local guid=ns.API(UnitGUID,unit)
    if ns.Secret(guid) or type(guid)~="string" or guid=="" then return nil end
    return guid
end
-- The current owner (GUID, count), or nil and 0; read-only, for tests and diagnostics.
function ns.ComboOwner() return ownerGUID,ownerCount end
-- Draws count dots (0 hides the row) and narrows the name while they show; the panel preview calls this directly.
function ns.ShowComboPoints(f,count)
    local combo=f.combo
    if not combo then return end
    count=ns.Number(count) or 0
    count=math.max(0,math.min(MAX,math.floor(count)))
    local shown=count>=1
    if combo.count~=count then
        for i=1,MAX do combo[i]:SetAlpha(i<=count and 1 or DIM) end
        combo.count=count
    end
    if f.nameNarrow~=shown and f.nameWidth then
        f.name:SetWidth(shown and f.nameWidth-NAME_GAP or f.nameWidth)
        f.nameNarrow=shown
    end
    combo:SetShown(shown)
end
-- Called from ns.UpdatePlate on every plate (the 0.1 s ticker and ns.RefreshAll run it on all active plates).
-- Only the target's plate reads the client. Building at least 1 point there (read from GetComboPoints, which is
-- target-bound) makes the target the owner; 0 on the owner means the points were spent and clears it. A plate that is
-- not the target shows the owner's count when its GUID is the owner's, otherwise nothing.
function ns.UpdateComboPoints(f,target)
    if not (ns.db and ns.db.showComboPoints and ns.ComboClass()) then
        ownerGUID,ownerCount=nil,0
        ns.ShowComboPoints(f,0)
        return
    end
    local guid=GUID(f.unit)
    if not target then
        ns.ShowComboPoints(f,(guid and guid==ownerGUID) and ownerCount or 0)
        return
    end
    local count,bound=ns.ReadComboPoints()
    count=count or 0
    -- The player-level UnitPower fallback cannot tell whose points they are: show them, but leave the owner alone.
    if bound then
        if count>=1 then
            -- Points on a target whose GUID is unreadable still belong to it, not to the old owner.
            ownerGUID,ownerCount=guid,guid and count or 0
        elseif guid and guid==ownerGUID then
            ownerGUID,ownerCount=nil,0
        end
    end
    ns.ShowComboPoints(f,count)
end
