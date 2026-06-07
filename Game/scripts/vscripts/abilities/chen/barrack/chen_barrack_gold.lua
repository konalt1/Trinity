if ChenBarrackGold then
    return ChenBarrackGold
end

ChenBarrackGold = {}

local CARRIER_MODIFIER = "modifier_chen_barrack_carrier"
local GOLD_DISPLAY_MODIFIER = "modifier_chen_barrack_gold_display"
local UNIT_MARKER_MODIFIER = "modifier_chen_barrack_unit"

local DEFAULT_DELIVERY_RADIUS = 300
local DEFAULT_DESTROYED_GOLD_PERCENT = 50

local function IsValidUnit(unit)
    return unit and not unit:IsNull()
end

local function GetBarrackGoldReason()
    return DOTA_ModifyGold_PurchaseItem or DOTA_ModifyGold_Unspecified or 0
end

function ChenBarrackGold.GetDeliveryRadius(barrack)
    if not IsValidUnit(barrack) then
        return DEFAULT_DELIVERY_RADIUS
    end

    local ownerHero = ChenBarrackGold.GetOwnerHero(barrack)
    if not ownerHero then
        return DEFAULT_DELIVERY_RADIUS
    end

    local ult = ownerHero:FindAbilityByName("chen_barrack")
    if ult and not ult:IsNull() then
        return ult:GetSpecialValueFor("delivery_radius") or DEFAULT_DELIVERY_RADIUS
    end

    return DEFAULT_DELIVERY_RADIUS
end

function ChenBarrackGold.GetDestroyedGoldPercent(barrack)
    if not IsValidUnit(barrack) then
        return DEFAULT_DESTROYED_GOLD_PERCENT
    end

    local ownerHero = ChenBarrackGold.GetOwnerHero(barrack)
    if not ownerHero then
        return DEFAULT_DESTROYED_GOLD_PERCENT
    end

    local ult = ownerHero:FindAbilityByName("chen_barrack")
    if ult and not ult:IsNull() then
        return ult:GetSpecialValueFor("destroyed_gold_percent") or DEFAULT_DESTROYED_GOLD_PERCENT
    end

    return DEFAULT_DESTROYED_GOLD_PERCENT
end

function ChenBarrackGold.GetOwnerHero(unit)
    if ChenBarrackGold.GetBarrackOwnerHero then
        return ChenBarrackGold.GetBarrackOwnerHero(unit)
    end
    return nil
end

function ChenBarrackGold.Get(barrack)
    if not IsValidUnit(barrack) then
        return 0
    end
    return math.max(0, math.floor(tonumber(barrack.chen_barrack_gold) or 0))
end

function ChenBarrackGold.SyncDisplay(barrack)
    if not IsValidUnit(barrack) then
        return
    end

    local gold = ChenBarrackGold.Get(barrack)
    local modifier = barrack:FindModifierByName(GOLD_DISPLAY_MODIFIER)
    if not modifier then
        modifier = barrack:AddNewModifier(barrack, nil, GOLD_DISPLAY_MODIFIER, {})
    end

    if modifier then
        modifier:SetStackCount(gold)
    end
end

function ChenBarrackGold.Add(barrack, amount, source)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or not IsValidUnit(barrack) then
        return false
    end

    barrack.chen_barrack_gold = ChenBarrackGold.Get(barrack) + amount
    ChenBarrackGold.SyncDisplay(barrack)
    return true
end

function ChenBarrackGold.Spend(barrack, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        return true
    end
    if not IsValidUnit(barrack) then
        return false
    end

    local current = ChenBarrackGold.Get(barrack)
    if current < amount then
        return false
    end

    barrack.chen_barrack_gold = current - amount
    barrack.chen_barrack_last_spend_reason = reason or "unknown"
    ChenBarrackGold.SyncDisplay(barrack)
    return true
end

function ChenBarrackGold.Has(barrack, amount)
    return ChenBarrackGold.Get(barrack) >= math.floor(tonumber(amount) or 0)
end

function ChenBarrackGold.GetUnitGoldMode(unitName)
    if not unitName or unitName == "" then
        return "shared"
    end

    if ChenBarrackGold.UNIT_GOLD_MODES and ChenBarrackGold.UNIT_GOLD_MODES[unitName] then
        return ChenBarrackGold.UNIT_GOLD_MODES[unitName]
    end

    if GetUnitKeyValue then
        local ok, kvMode = pcall(GetUnitKeyValue, unitName, "ChenBarrackGoldMode")
        if ok and kvMode and kvMode ~= "" then
            return string.lower(tostring(kvMode))
        end
    end

    return "shared"
end

function ChenBarrackGold.GetHomeBarrack(unit)
    if not IsValidUnit(unit) then
        return nil
    end

    if IsValidUnit(unit.chen_home_barrack) then
        return unit.chen_home_barrack
    end

    if unit.chen_home_barrack_entindex then
        local ok, barrack = pcall(EntIndexToHScript, unit.chen_home_barrack_entindex)
        if ok and IsValidUnit(barrack) then
            unit.chen_home_barrack = barrack
            return barrack
        end
    end

    return nil
end

function ChenBarrackGold.GetCarriedGold(unit)
    if not IsValidUnit(unit) then
        return 0
    end
    return math.max(0, math.floor(tonumber(unit.chen_carried_gold) or 0))
end

function ChenBarrackGold.SetCarriedGold(unit, amount)
    if not IsValidUnit(unit) then
        return
    end

    unit.chen_carried_gold = math.max(0, math.floor(tonumber(amount) or 0))
    local modifier = unit:FindModifierByName(CARRIER_MODIFIER)
    if modifier then
        modifier:SetStackCount(unit.chen_carried_gold)
    end
end

function ChenBarrackGold.AddCarrierGold(unit, baseAmount)
    baseAmount = math.floor(tonumber(baseAmount) or 0)
    if baseAmount <= 0 or not IsValidUnit(unit) then
        return 0
    end

    local carried = ChenBarrackGold.GetCarriedGold(unit)
    local totalGain = baseAmount + carried
    ChenBarrackGold.SetCarriedGold(unit, totalGain)
    return totalGain
end

function ChenBarrackGold.DepositCarrierGold(unit)
    if not IsValidUnit(unit) then
        return 0
    end

    local amount = ChenBarrackGold.GetCarriedGold(unit)
    if amount <= 0 then
        return 0
    end

    local barrack = ChenBarrackGold.GetHomeBarrack(unit)
    if not barrack then
        return 0
    end

    local mode = unit.chen_gold_mode or ChenBarrackGold.GetUnitGoldMode(unit:GetUnitName())
    ChenBarrackGold.SetCarriedGold(unit, 0)
    ChenBarrackGold.Add(barrack, amount, "carrier_delivery")

    if mode == "shared_carrier" then
        local ownerHero = ChenBarrackGold.GetOwnerHero(unit)
        if ownerHero then
            ChenBarrackGold.GiveHeroGold(ownerHero, amount)
        end
    end

    return amount
end

function ChenBarrackGold.RegisterBarrackUnit(unit, barrack, ownerHero, goldMode)
    if not IsValidUnit(unit) or not IsValidUnit(barrack) then
        return
    end

    unit.chen_barrack_spawned = true
    unit.chen_home_barrack = barrack
    unit.chen_home_barrack_entindex = barrack:entindex()
    unit.chen_owner_entindex = ownerHero and ownerHero:entindex() or nil
    unit.chen_gold_mode = goldMode or ChenBarrackGold.GetUnitGoldMode(unit:GetUnitName())

    if unit.chen_gold_mode == "none" or unit.chen_gold_mode == "building" then
        return
    end

    unit:AddNewModifier(unit, nil, UNIT_MARKER_MODIFIER, {
        gold_mode = unit.chen_gold_mode,
    })

    if unit.chen_gold_mode == "carrier" or unit.chen_gold_mode == "shared_carrier" then
        unit:AddNewModifier(unit, nil, CARRIER_MODIFIER, {})
    end
end

function ChenBarrackGold.GrantUnitGold(unit, amount, source)
    if not IsValidUnit(unit) or not unit.chen_barrack_spawned then
        return false
    end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        return false
    end

    local mode = unit.chen_gold_mode or ChenBarrackGold.GetUnitGoldMode(unit:GetUnitName())
    if mode == "carrier" or mode == "shared_carrier" then
        ChenBarrackGold.AddCarrierGold(unit, amount)
        return true
    end

    local ownerHero = ChenBarrackGold.GetOwnerHero(unit)
    local barrack = ChenBarrackGold.GetHomeBarrack(unit)
    if ownerHero then
        local playerID = ownerHero:GetPlayerOwnerID()
        if playerID ~= nil and playerID >= 0 and PlayerResource and PlayerResource.ModifyGold then
            PlayerResource:ModifyGold(playerID, amount, false, GetBarrackGoldReason())
        else
            ownerHero:ModifyGold(amount, false, GetBarrackGoldReason())
        end
    end
    if barrack then
        ChenBarrackGold.Add(barrack, amount, source or "custom_source")
    end
    return true
end

function ChenBarrackGold.GiveHeroGold(hero, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or not IsValidUnit(hero) then
        return
    end

    local playerID = hero:GetPlayerOwnerID()
    if playerID ~= nil and playerID >= 0 and PlayerResource and PlayerResource.ModifyGold then
        PlayerResource:ModifyGold(playerID, amount, false, GetBarrackGoldReason())
        return
    end

    hero:ModifyGold(amount, false, GetBarrackGoldReason())
end

function ChenBarrackGold.TakeHeroGold(hero, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or not IsValidUnit(hero) then
        return
    end

    local playerID = hero:GetPlayerOwnerID()
    if playerID ~= nil and playerID >= 0 and PlayerResource and PlayerResource.ModifyGold then
        PlayerResource:ModifyGold(playerID, -amount, false, GetBarrackGoldReason())
        return
    end

    hero:ModifyGold(-amount, false, GetBarrackGoldReason())
end

function ChenBarrackGold.GetKillBounty(unit)
    if not IsValidUnit(unit) then
        return 0
    end

    if unit.GetGoldBounty then
        local bounty = unit:GetGoldBounty()
        if bounty and bounty > 0 then
            return math.floor(bounty)
        end
    end

    local minBounty = tonumber(GetUnitKeyValue(unit:GetUnitName(), "BountyGoldMin")) or 0
    local maxBounty = tonumber(GetUnitKeyValue(unit:GetUnitName(), "BountyGoldMax")) or minBounty
    if maxBounty < minBounty then
        maxBounty = minBounty
    end

    if maxBounty > minBounty then
        return RandomInt(minBounty, maxBounty)
    end

    return math.floor(minBounty)
end

function ChenBarrackGold.IsBarrackUnit(unit)
    if not IsValidUnit(unit) then
        return false
    end
    return unit.chen_barrack_spawned == true
end

function ChenBarrackGold.OnEntityKilled(event)
    if not IsServer() then
        return
    end

    local killed = EntIndexToHScript(event.entindex_killed)
    local attacker = EntIndexToHScript(event.entindex_attacker)

    if not IsValidUnit(killed) or not IsValidUnit(attacker) then
        return
    end

    if ChenBarrackGold.IsChenBarrackBuilding and ChenBarrackGold.IsChenBarrackBuilding(killed) then
        ChenBarrackGold.OnBarrackDestroyed(killed, attacker)
        return
    end

    if not ChenBarrackGold.IsBarrackUnit(attacker) then
        return
    end

    local bounty = ChenBarrackGold.GetKillBounty(killed)
    if bounty <= 0 then
        return
    end

    local ownerHero = ChenBarrackGold.GetOwnerHero(attacker)
    local barrack = ChenBarrackGold.GetHomeBarrack(attacker)
    local mode = attacker.chen_gold_mode or ChenBarrackGold.GetUnitGoldMode(attacker:GetUnitName())

    if mode == "carrier" or mode == "shared_carrier" then
        ChenBarrackGold.AddCarrierGold(attacker, bounty)
        if ownerHero then
            Timers:CreateTimer(0, function()
                ChenBarrackGold.TakeHeroGold(ownerHero, bounty)
                return nil
            end)
        end
        return
    end

    if barrack then
        ChenBarrackGold.Add(barrack, bounty, "shared_kill")
    end
end

function ChenBarrackGold.OnBarrackDestroyed(barrack, killer)
    if not IsValidUnit(barrack) or barrack.chen_barrack_destroy_handled then
        return
    end

    barrack.chen_barrack_destroy_handled = true
    barrack.chen_is_destroyed = true

    local gold = ChenBarrackGold.Get(barrack)
    local percent = ChenBarrackGold.GetDestroyedGoldPercent(barrack)
    local payout = math.floor(gold * percent / 100)

    if payout > 0 and IsValidUnit(killer) then
        local killerPlayerID = killer:GetPlayerOwnerID()
        if killerPlayerID ~= nil and killerPlayerID >= 0 and PlayerResource and PlayerResource.ModifyGold then
            PlayerResource:ModifyGold(killerPlayerID, payout, false, DOTA_ModifyGold_Unspecified)
            SendOverheadEventMessage(nil, OVERHEAD_ALERT_GOLD, killer, payout, nil)
        end
    end

    barrack.chen_barrack_gold = 0
    ChenBarrackGold.SyncDisplay(barrack)

    if CHEN_BARRACK_REGISTRY then
        CHEN_BARRACK_REGISTRY[barrack:entindex()] = nil
    end
end

function ChenBarrackGold.ModifyGoldFilter(data)
    if not data or data.reason_const ~= DOTA_ModifyGold_CreepKill then
        return true
    end

    if ChenBarrackGold._pendingCarrierBlocks[data.player_id_const] then
        local blockAmount = ChenBarrackGold._pendingCarrierBlocks[data.player_id_const]
        ChenBarrackGold._pendingCarrierBlocks[data.player_id_const] = nil
        data.gold = math.max(0, (data.gold or 0) - blockAmount)
    end

    return true
end

ChenBarrackGold._pendingCarrierBlocks = {}

function ChenBarrackGold.MarkCarrierGoldBlock(playerID, amount)
    if playerID == nil or playerID < 0 then
        return
    end
    ChenBarrackGold._pendingCarrierBlocks[playerID] = (ChenBarrackGold._pendingCarrierBlocks[playerID] or 0) + amount
end

function ChenBarrackGold.Init()
    if ChenBarrackGold._initialized then
        return
    end

    ChenBarrackGold._initialized = true
    ListenToGameEvent("entity_killed", function(event)
        ChenBarrackGold.OnEntityKilled(event)
    end, nil)

    local gameMode = GameRules and GameRules.GetGameModeEntity and GameRules:GetGameModeEntity()
    if gameMode then
        if not gameMode.ChenBarrackOldModifyGoldFilter then
            gameMode.ChenBarrackOldModifyGoldFilter = GameMode and GameMode.ModifyGoldFilter
        end
    end
end

return ChenBarrackGold
