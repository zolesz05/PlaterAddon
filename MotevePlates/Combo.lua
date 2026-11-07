local _,ns=...
-- Combo points on the target's plate for Rogues and Druids: five dots in the name row (built in ns.CreatePlate,
-- coloured in ns.StylePlate), earned points in the skin accent, free slots dimmed.
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
function ns.ReadComboPoints()
    local points=ns.Number(ns.API(GetComboPoints,"player","target"))
    if points==nil then points=ns.Number(ns.API(UnitPower,"player",4)) end
    if points==nil then return nil end
    return math.max(0,math.min(MAX,math.floor(points)))
end
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
-- Called from ns.UpdatePlate; only the target's plate of a Rogue or Druid with the setting on reads the client.
function ns.UpdateComboPoints(f,target)
    local count=0
    if ns.db and ns.db.showComboPoints and ns.ComboClass() and target then count=ns.ReadComboPoints() or 0 end
    ns.ShowComboPoints(f,count)
end
