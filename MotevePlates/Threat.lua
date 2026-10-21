local _,ns=...
local states={
    neutral={key="neutral",color={0.72,0.16,0.13},label=""},
    safe={key="safe",color={0.20,0.75,0.36},label=""},
    held={key="safe",color={0.20,0.75,0.36},label="RAJTAD AZ AGGRO"},
    warning={key="warning",color={1,0.67,0.08},label="MAGAS AGGRO"},
    danger={key="danger",color={0.95,0.14,0.12},label=""},
    unknown={key="unknown",color={0.57,0.59,0.65},label="AGGRO: ?"},
    tapped={key="tapped",color={0.45,0.45,0.45},label=""},
}
ns.ThreatStates=states
-- Pure classification: receives only readable values, never makes decisions on concealed data.
function ns.ClassifyThreat(role,d,threshold)
    if not d.inCombat or d.isPlayer then return d.tapped and states.tapped or states.neutral end
    local status,percent=ns.Number(d.status),ns.Number(d.percent)
    local owner=ns.Bool(d.tanking)
    if status and status>=2 then owner=true end
    if ns.Bool(d.targetPlayer)==true then owner=true end
    if d.tapped and owner~=true then return states.tapped end
    if owner==nil and ns.Bool(d.hasTarget)==true and ns.Bool(d.targetPlayer)==false then owner=false end
    if role=="tank" then
        if owner==true then
            if status==2 then return states.warning end
            return status==3 and states.safe or states.held
        end
        if owner==false or status~=nil then return states.danger end
    else
        if owner==true then return states.danger end
        if status==1 or (percent and percent>=(threshold or 85)) then return states.warning end
        if owner==false or status~=nil or percent~=nil then return states.safe end
    end
    return states.unknown
end
function ns.ThreatLabel(state,role)
    if state.key=="safe" then
        if role=="tank" and state.label~="" then return state.label end
        return role=="tank" and "STABIL AGGRO" or "AGGRO MÁSON"
    end
    if state.key=="danger" then return role=="tank" and "ELVESZTETT AGGRO" or "TÉGED TÁMAD" end
    if state.key=="warning" and role=="tank" then return "INOG AZ AGGRO" end
    return state.label
end
function ns.ReadThreat(unit)
    local tanking,status,percentage=ns.API(UnitDetailedThreatSituation,"player",unit)
    if not ns.Number(status) then status=ns.API(UnitThreatSituation,"player",unit) end
    local own=ns.Bool(tanking)
    local targetPlayer=ns.Bool(ns.API(UnitIsUnit,unit.."target","player"))
    local mobCombat=ns.Bool(ns.API(UnitAffectingCombat,unit))
    local playerCombat=ns.Bool(ns.API(UnitAffectingCombat,"player"))
    local readableStatus,readablePct=ns.Number(status),ns.Number(percentage)
    local engaged=mobCombat and (playerCombat or own==true or targetPlayer==true or (readableStatus and readableStatus>0) or (readablePct and readablePct>0))
    local data={status=readableStatus,percent=readablePct,tanking=own,targetPlayer=targetPlayer,
        hasTarget=ns.Bool(ns.API(UnitExists,unit.."target")),inCombat=not not engaged,
        tapped=ns.Bool(ns.API(UnitIsTapDenied,unit)),isPlayer=ns.Bool(ns.API(UnitIsPlayer,unit))}
    return ns.ClassifyThreat(ns.GetRole(),data,ns.db.warningAt),percentage
end
