local _,ns=...
local function IsQuestObjective(unit)
    if ns.Bool(ns.API(UnitIsPlayer,unit))==true then return false end
    if ns.Bool(ns.API(UnitIsQuestBoss,unit))==true then return true end
    -- Questie also tracks loot objectives, which UnitIsQuestBoss may not flag.
    local guid=ns.API(UnitGUID,unit)
    if ns.Secret(guid) or type(guid)~="string" then return false end
    if not guid:match("^Creature%-") and not guid:match("^Vehicle%-") then return false end
    local loader=QuestieLoader
    local module=loader and ns.API(loader.ImportModule,loader,"QuestieNameplate")
    if ns.Secret(module) or type(module)~="table" then return false end
    local icon=ns.API(module.GetIcon,guid)
    return not ns.Secret(icon) and (type(icon)=="string" or type(icon)=="number")
end
function ns.UpdateQuestMarker(f,force)
    if not f.unit then return end
    local now=GetTime()
    if force or not f.questNextCheck or now>=f.questNextCheck then
        f.questRelevant=IsQuestObjective(f.unit)
        f.questNextCheck=now+1
    end
    local visible=ns.db.showQuest and f.questRelevant==true
    f.questBadge:SetShown(visible)
end
local function RefreshQuestMarkers()
    for _,f in pairs(ns.active or {}) do ns.Safe("quest marker",ns.UpdateQuestMarker,f,true) end
end
for _,event in ipairs({"QUEST_LOG_UPDATE","QUEST_ACCEPTED","QUEST_REMOVED","QUEST_TURNED_IN","PLAYER_ENTERING_WORLD"}) do
    ns:On(event,RefreshQuestMarkers)
end
