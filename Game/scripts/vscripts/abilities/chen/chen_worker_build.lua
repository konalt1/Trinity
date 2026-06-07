require("abilities/chen/chen_sub_barrack")

chen_worker_build_tower = class({})
chen_worker_build_thunderhide_barrack = class({})
chen_worker_build_dragon_barrack = class({})
chen_building_tower_attack = class({})
modifier_chen_worker_build_runner = class({})
modifier_chen_building_construction = class({})
modifier_chen_building_tower_active = class({})

local SCRIPT_PATH = "abilities/chen/chen_worker_build"
local REPAIR_PARTICLE = "particles/items5_fx/repair_kit.vpcf"
local CONSTRUCTION_RING_PARTICLE = "particles/generic_gameplay/launchpad_progress_ring.vpcf"
local TOWER_ATTACK_PROJECTILE_GOOD = "particles/base_attacks/ranged_tower_good.vpcf"
local TOWER_ATTACK_PROJECTILE_BAD = "particles/base_attacks/ranged_tower_bad.vpcf"
local TOWER_PROJECTILE_SPEED = 750

LinkLuaModifier("modifier_chen_worker_build_runner", SCRIPT_PATH, LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_chen_building_construction", SCRIPT_PATH, LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_chen_building_tower_active", SCRIPT_PATH, LUA_MODIFIER_MOTION_NONE)

ChenWorkerBuild = ChenWorkerBuild or {}

local CHEN_WORKER_BUILD_DEBUG = true

local function BuildDebug(step, ...)
    if not CHEN_WORKER_BUILD_DEBUG then
        return
    end

    local parts = { "[ChenWorkerBuild]" }
    if step then
        parts[#parts + 1] = tostring(step)
    end
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    print(table.concat(parts, " "))
end

local function DescribeUnit(unit)
    if not IsValidEntity(unit) then
        return "null"
    end
    return string.format(
        "%s#%d pos=(%.0f,%.0f,%.0f) hp=%d/%d",
        unit:GetUnitName() or "?",
        unit:entindex(),
        unit:GetAbsOrigin().x,
        unit:GetAbsOrigin().y,
        unit:GetAbsOrigin().z,
        unit:GetHealth(),
        unit:GetMaxHealth()
    )
end

local function DescribePosition(position)
    if not position then
        return "nil"
    end
    return string.format("(%.0f, %.0f, %.0f)", position.x, position.y, position.z)
end

local function GetWorkerDistanceToBuilding(worker, building)
    if not IsValidEntity(worker) or not IsValidEntity(building) then
        return math.huge
    end

    if building.GetRangeToUnit then
        return building:GetRangeToUnit(worker)
    end

    return (worker:GetAbsOrigin() - building:GetAbsOrigin()):Length2D()
end

local WORKER_BUILD_ABILITIES = {
    "chen_worker_build_tower",
    "chen_worker_build_thunderhide_barrack",
    "chen_worker_build_dragon_barrack",
}

local BUILD_CONFIG = {
    chen_worker_build_tower = {
        unit_name = "npc_chen_building_tower",
        gold_cost_key = "gold_cost",
        max_hp_key = "max_hp",
        is_tower = true,
    },
    chen_worker_build_thunderhide_barrack = {
        unit_name = "npc_chen_building_thunderhide_barrack",
        gold_cost_key = "gold_cost",
        max_hp_key = "max_hp",
        is_sub_barrack = true,
        sub_barrack_type = "thunderhide",
    },
    chen_worker_build_dragon_barrack = {
        unit_name = "npc_chen_building_dragon_barrack",
        gold_cost_key = "gold_cost",
        max_hp_key = "max_hp",
        is_sub_barrack = true,
        sub_barrack_type = "dragon",
    },
}

local function IsValidEntity(entity)
    return entity and not entity:IsNull()
end

local function GetBuildValue(ability, key, fallback)
    if not ability or ability:IsNull() then
        return fallback or 0
    end
    local value = ability:GetSpecialValueFor(key)
    if value == nil then
        return fallback or 0
    end
    return value
end

local function GetBuildConfig(ability)
    if not ability or ability:IsNull() then
        return nil
    end
    return BUILD_CONFIG[ability:GetAbilityName()]
end

function ChenWorkerBuild.IsWorkerBusy(worker)
    if not IsValidEntity(worker) then
        return false
    end
    if worker:HasModifier("modifier_chen_worker_build_runner") then
        return true
    end
    return worker.chen_build_assignment_entindex ~= nil
end

local function GetWorkerHomeBarrack(worker)
    if ChenBarrackGold and ChenBarrackGold.GetHomeBarrack then
        return ChenBarrackGold.GetHomeBarrack(worker)
    end
    return nil
end

local function GetOwnerHeroFromWorker(worker)
    if GetBarrackOwnerHero then
        return GetBarrackOwnerHero(worker)
    end
    return nil
end

local function IsPassableBuildPosition(position)
    if not position then
        return false
    end

    local ground = GetGroundPosition(position, nil)
    if GridNav.IsBlocked and GridNav:IsBlocked(ground) then
        return false
    end
    if GridNav.IsTraversable and not GridNav:IsTraversable(ground) then
        return false
    end
    return true
end

local function ClearWorkerAssignment(worker)
    if not IsValidEntity(worker) then
        return
    end
    worker.chen_build_assignment_entindex = nil
end

local function AssignWorkerToBuilding(worker, building)
    if not IsValidEntity(worker) or not IsValidEntity(building) then
        return
    end
    worker.chen_build_assignment_entindex = building:entindex()
    building.chen_build_worker_entindex = worker:entindex()
end

function ChenWorkerBuild.ReleaseWorker(worker)
    ClearWorkerAssignment(worker)
end

function ChenWorkerBuild.PauseGatherForWorker(worker)
    if RefreshWorkerGatherPause then
        RefreshWorkerGatherPause(worker)
    end
end

function ChenWorkerBuild.IsGatherBlocked(worker)
    if not IsValidEntity(worker) then
        return false
    end
    return worker:HasModifier("modifier_chen_worker_build_runner")
        or worker.chen_build_assignment_entindex ~= nil
end

local function HideBuildAbility(ability, hidden)
    if not ability or ability:IsNull() then
        return
    end
    ability:SetHidden(hidden)
    ability:SetActivated(not hidden)
    if hidden then
        ability:SetLevel(0)
    else
        ability:SetLevel(1)
    end
end

function ChenWorkerBuild.ApplyScepterToWorker(worker, ownerHero)
    if not IsValidEntity(worker) or not IsChenBarrackWorker or not IsChenBarrackWorker(worker) then
        return
    end

    ownerHero = ownerHero or GetOwnerHeroFromWorker(worker)
    local hasScepter = ChenBarrackHasScepterUpgrade and ChenBarrackHasScepterUpgrade(ownerHero)

    for _, abilityName in ipairs(WORKER_BUILD_ABILITIES) do
        local ability = worker:FindAbilityByName(abilityName)
        if not ability or ability:IsNull() then
            ability = worker:AddAbility(abilityName)
        end
        if ability and not ability:IsNull() then
            HideBuildAbility(ability, not hasScepter)
        end
    end
end

function ChenWorkerBuild.SyncScepterForHero(hero)
    if not IsValidEntity(hero) or hero:GetUnitName() ~= "npc_dota_hero_chen" then
        return
    end

    local hasScepter = ChenBarrackHasScepterUpgrade and ChenBarrackHasScepterUpgrade(hero)
    local units = FindUnitsInRadius(
        hero:GetTeamNumber(),
        hero:GetAbsOrigin(),
        nil,
        FIND_UNITS_EVERYWHERE,
        DOTA_UNIT_TARGET_TEAM_FRIENDLY,
        DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )

    for _, unit in pairs(units) do
        if IsChenBarrackWorker and IsChenBarrackWorker(unit) and GetOwnerHeroFromWorker(unit) == hero then
            ChenWorkerBuild.ApplyScepterToWorker(unit, hero)
            if not hasScepter then
                unit:RemoveModifierByName("modifier_chen_worker_build_runner")
            end
        end
    end

    local unitsAll = FindUnitsInRadius(
        hero:GetTeamNumber(),
        hero:GetAbsOrigin(),
        nil,
        FIND_UNITS_EVERYWHERE,
        DOTA_UNIT_TARGET_TEAM_FRIENDLY,
        DOTA_UNIT_TARGET_ALL,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )

    for _, unit in pairs(unitsAll) do
        if unit:HasModifier("modifier_chen_building_construction") then
            local modifier = unit:FindModifierByName("modifier_chen_building_construction")
            if modifier and modifier.owner_hero == hero then
                modifier.scepter_stopped = not hasScepter
            end
        end
    end

    if not hasScepter then
        ChenWorkerBuild.StopAllConstructionsForHero(hero)
    end
end

function ChenWorkerBuild.StopAllConstructionsForHero(hero)
    if not IsValidEntity(hero) then
        return
    end

    local units = FindUnitsInRadius(
        hero:GetTeamNumber(),
        hero:GetAbsOrigin(),
        nil,
        FIND_UNITS_EVERYWHERE,
        DOTA_UNIT_TARGET_TEAM_FRIENDLY,
        DOTA_UNIT_TARGET_ALL,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )

    for _, unit in pairs(units) do
        if unit.chen_build_owner_hero == hero or GetOwnerHeroFromWorker(unit) == hero then
            unit:RemoveModifierByName("modifier_chen_worker_build_runner")
        end
    end
end

function ChenWorkerBuild.ForEachWorkerOwnedByHero(hero, fn)
    if not IsValidEntity(hero) or not fn then
        return
    end

    local units = FindUnitsInRadius(
        hero:GetTeamNumber(),
        hero:GetAbsOrigin(),
        nil,
        FIND_UNITS_EVERYWHERE,
        DOTA_UNIT_TARGET_TEAM_FRIENDLY,
        DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )

    for _, unit in pairs(units) do
        if IsChenBarrackWorker and IsChenBarrackWorker(unit) and GetOwnerHeroFromWorker(unit) == hero then
            fn(unit)
        end
    end
end

local function SharedBuildValidate(self, targetPosition)
    local worker = self:GetCaster()
    local ownerHero = GetOwnerHeroFromWorker(worker)
    if not ownerHero then
        return "#dota_hud_error_chen_barrack_no_owner"
    end

    if not ChenBarrackHasScepterUpgrade or not ChenBarrackHasScepterUpgrade(ownerHero) then
        return "#dota_hud_error_chen_worker_build_no_scepter"
    end

    if ChenWorkerBuild.IsWorkerBusy(worker) then
        return "#dota_hud_error_chen_worker_build_busy"
    end

    local barrack = GetWorkerHomeBarrack(worker)
    if not barrack or not barrack:IsAlive() then
        return "#dota_hud_error_chen_barrack_no_owner"
    end

    local goldCost = GetBuildValue(self, "gold_cost", 10)
    if not ChenBarrackGold.Has(barrack, goldCost) then
        return "#dota_hud_error_chen_barrack_not_enough_gold"
    end

    if targetPosition and not IsPassableBuildPosition(targetPosition) then
        return "#dota_hud_error_chen_worker_build_invalid_position"
    end

    return nil
end

function ChenWorkerBuild.NotifyPlayerError(worker, errorKey)
    if not errorKey or errorKey == "" or not IsServer() then
        return
    end

    local ownerHero = GetOwnerHeroFromWorker(worker)
    if not ownerHero then
        return
    end

    local playerID = ownerHero:GetPlayerOwnerID()
    if playerID == nil or playerID < 0 then
        return
    end

    local player = PlayerResource:GetPlayer(playerID)
    if not player then
        return
    end

    CustomGameEventManager:Send_ServerToPlayer(player, "dota_hud_error_message", {
        message = errorKey,
        reason = 80,
        sequenceNumber = 0,
    })
end

local function SharedBuildCastFilter(self, targetPosition)
    if not IsServer() then
        return UF_SUCCESS
    end

    local worker = self:GetCaster()
    local target = targetPosition or self:GetCursorPosition()
    local errorKey = SharedBuildValidate(self, target)
    if errorKey then
        BuildDebug("FAIL) Каст отклонён:", errorKey, DescribeUnit(worker), DescribePosition(target))
        return UF_FAIL_CUSTOM
    end

    return UF_SUCCESS
end

local function SharedBuildCastError(self, targetPosition)
    if not IsServer() then
        return ""
    end

    return SharedBuildValidate(self, targetPosition or self:GetCursorPosition()) or ""
end

local function SharedBuildOnSpellStart(self)
    if not IsServer() then
        return
    end

    local worker = self:GetCaster()
    local target = self:GetCursorPosition()
    BuildDebug(
        "1) Команда на постройку получена, координаты:",
        DescribePosition(target),
        "ability=",
        self:GetAbilityName(),
        "worker=",
        DescribeUnit(worker)
    )

    local errorKey = SharedBuildValidate(self, target)
    if errorKey then
        BuildDebug("FAIL) Каст отменён:", errorKey, DescribePosition(target))
        ChenWorkerBuild.NotifyPlayerError(worker, errorKey)
        return
    end

    ChenWorkerBuild.PauseGatherForWorker(worker)
    worker:AddNewModifier(worker, self, "modifier_chen_worker_build_runner", {
        target_x = target.x,
        target_y = target.y,
        target_z = target.z,
        build_ability = self:GetAbilityName(),
    })
end

local function SharedBuildCastFilterLocation(self, location)
    return SharedBuildCastFilter(self, location)
end

local function SharedBuildCastErrorLocation(self, location)
    return SharedBuildCastError(self, location)
end

function chen_worker_build_tower:CastFilterResult()
    return SharedBuildCastFilter(self)
end

function chen_worker_build_tower:CastFilterResultLocation(location)
    return SharedBuildCastFilterLocation(self, location)
end

function chen_worker_build_tower:GetCustomCastError()
    return SharedBuildCastError(self)
end

function chen_worker_build_tower:GetCustomCastErrorLocation(location)
    return SharedBuildCastErrorLocation(self, location)
end

function chen_worker_build_tower:OnSpellStart()
    SharedBuildOnSpellStart(self)
end

function chen_worker_build_thunderhide_barrack:CastFilterResult()
    return SharedBuildCastFilter(self)
end

function chen_worker_build_thunderhide_barrack:CastFilterResultLocation(location)
    return SharedBuildCastFilterLocation(self, location)
end

function chen_worker_build_thunderhide_barrack:GetCustomCastError()
    return SharedBuildCastError(self)
end

function chen_worker_build_thunderhide_barrack:GetCustomCastErrorLocation(location)
    return SharedBuildCastErrorLocation(self, location)
end

function chen_worker_build_thunderhide_barrack:OnSpellStart()
    SharedBuildOnSpellStart(self)
end

function chen_worker_build_dragon_barrack:CastFilterResult()
    return SharedBuildCastFilter(self)
end

function chen_worker_build_dragon_barrack:CastFilterResultLocation(location)
    return SharedBuildCastFilterLocation(self, location)
end

function chen_worker_build_dragon_barrack:GetCustomCastError()
    return SharedBuildCastError(self)
end

function chen_worker_build_dragon_barrack:GetCustomCastErrorLocation(location)
    return SharedBuildCastErrorLocation(self, location)
end

function chen_worker_build_dragon_barrack:OnSpellStart()
    SharedBuildOnSpellStart(self)
end

function modifier_chen_worker_build_runner:IsHidden()
    return true
end

function modifier_chen_worker_build_runner:IsPurgable()
    return false
end

function modifier_chen_worker_build_runner:OnCreated(kv)
    if not IsServer() then
        return
    end

    self.target = Vector(tonumber(kv.target_x) or 0, tonumber(kv.target_y) or 0, tonumber(kv.target_z) or 0)
    self.build_ability_name = kv.build_ability
    self.arrive_radius = GetBuildValue(self:GetAbility(), "arrive_radius", 80)
    self.move_logged = false
    self:StartIntervalThink(0.1)
    self:IssueMove()
    BuildDebug(
        "2) Юнит идёт к точке",
        DescribeUnit(self:GetParent()),
        "target=",
        DescribePosition(self.target),
        "arrive_radius=",
        self.arrive_radius
    )
end

function modifier_chen_worker_build_runner:IssueMove()
    local parent = self:GetParent()
    parent.chen_worker_ai_order = true
    ExecuteOrderFromTable({
        UnitIndex = parent:entindex(),
        OrderType = DOTA_UNIT_ORDER_MOVE_TO_POSITION,
        Position = self.target,
    })
    parent.chen_worker_ai_order = nil
end

function modifier_chen_worker_build_runner:OnIntervalThink()
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if not parent:IsAlive() then
        self:Destroy()
        return
    end

    local ownerHero = GetOwnerHeroFromWorker(parent)
    if not ownerHero or not ChenBarrackHasScepterUpgrade(ownerHero) then
        BuildDebug("FAIL) Бегун остановлен: нет героя или скипетра", DescribeUnit(parent))
        self:Destroy()
        return
    end

    local distance = (parent:GetAbsOrigin() - self.target):Length2D()
    if not self.move_logged and distance > self.arrive_radius then
        self.move_logged = true
    end

    if distance <= self.arrive_radius then
        if self.began_construction then
            return
        end
        self.began_construction = true
        self.arrived = true
        BuildDebug(
            "3) Юнит дошёл до точки",
            DescribeUnit(parent),
            "distance=",
            string.format("%.0f", distance)
        )
        self:BeginConstruction()
        self:Destroy()
    end
end

function modifier_chen_worker_build_runner:BeginConstruction()
    local worker = self:GetParent()
    local ability = worker:FindAbilityByName(self.build_ability_name)
    local config = GetBuildConfig(ability)
    if not config then
        BuildDebug("FAIL) Нет конфига постройки", "ability=", tostring(self.build_ability_name))
        return
    end

    local ownerHero = GetOwnerHeroFromWorker(worker)
    local barrack = GetWorkerHomeBarrack(worker)
    if not ownerHero or not barrack or not barrack:IsAlive() then
        BuildDebug(
            "FAIL) Нет героя или барака",
            "hero=",
            tostring(ownerHero ~= nil),
            "barrack=",
            DescribeUnit(barrack)
        )
        return
    end

    if not IsPassableBuildPosition(self.target) then
        BuildDebug("FAIL) Точка стала непроходимой:", DescribePosition(self.target))
        return
    end

    local goldCost = GetBuildValue(ability, config.gold_cost_key, 10)
    local maxHp = GetBuildValue(ability, config.max_hp_key, 2000)
    if not ChenBarrackGold.Has(barrack, goldCost) then
        BuildDebug("FAIL) Недостаточно золота", "need=", goldCost, "have=", ChenBarrackGold.Get(barrack))
        ChenWorkerBuild.NotifyPlayerError(worker, "#dota_hud_error_chen_barrack_not_enough_gold")
        return
    end
    if not ChenBarrackGold.Spend(barrack, goldCost, "worker_build") then
        BuildDebug("FAIL) Списание золота не удалось", "cost=", goldCost)
        ChenWorkerBuild.NotifyPlayerError(worker, "#dota_hud_error_chen_barrack_not_enough_gold")
        return
    end

    local teamNumber = ownerHero:GetTeamNumber()
    local building = CreateUnitByName(config.unit_name, self.target, false, ownerHero, ownerHero, teamNumber)
    if not building or building:IsNull() then
        ChenBarrackGold.Add(barrack, goldCost, "worker_build_refund")
        BuildDebug("FAIL) CreateUnitByName не создал юнит", config.unit_name)
        return
    end

    FindClearSpaceForUnit(building, self.target, true)
    building:SetBaseMaxHealth(maxHp)
    building:SetMaxHealth(maxHp)
    building:SetHealth(1)

    building:SetOwner(ownerHero)
    building:SetControllableByPlayer(ownerHero:GetPlayerOwnerID(), true)
    building.chen_barrack_owner_entindex = ownerHero:entindex()
    building.chen_build_owner_hero = ownerHero
    building.chen_home_barrack = barrack
    building.chen_home_barrack_entindex = barrack:entindex()

    if config.is_sub_barrack then
        building.chen_sub_barrack_home_entindex = barrack:entindex()
        building.chen_sub_barrack_type = config.sub_barrack_type
    end

    if config.is_tower then
        building:SetAttackCapability(DOTA_UNIT_CAP_NO_ATTACK)
    end

    building:RemoveModifierByName("modifier_invulnerable")

    BuildDebug("4) Модель постройки создана", DescribeUnit(building), "unit=", config.unit_name)

    AssignWorkerToBuilding(worker, building)
    ChenWorkerBuild.PauseGatherForWorker(worker)

    building:AddNewModifier(worker, ability, "modifier_chen_building_construction", {
        max_hp = maxHp,
        worker_entindex = worker:entindex(),
        gold_cost = goldCost,
        build_rate = GetBuildValue(ability, "build_rate", 70),
        worker_radius = GetBuildValue(ability, "worker_radius", 100),
        is_tower = config.is_tower and 1 or 0,
        is_sub_barrack = config.is_sub_barrack and 1 or 0,
    })

    BuildDebug(
        "6) Стройка началась",
        "building=",
        DescribeUnit(building),
        "worker=",
        DescribeUnit(worker),
        "gold_spent=",
        goldCost
    )
end

function modifier_chen_worker_build_runner:OnDestroy()
    if not IsServer() then
        return
    end

    if not self.arrived then
        BuildDebug("FAIL) Бегун снят до прибытия", DescribeUnit(self:GetParent()))
    end
end

function modifier_chen_building_construction:IsHidden()
    return false
end

function modifier_chen_building_construction:IsPurgable()
    return false
end

function modifier_chen_building_construction:GetTexture()
    return "chen_hand_of_god"
end

function modifier_chen_building_construction:OnCreated(kv)
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    local workerEntindex = tonumber(kv.worker_entindex)
    local worker = nil
    if workerEntindex then
        local ok, entity = pcall(EntIndexToHScript, workerEntindex)
        if ok and IsValidEntity(entity) then
            worker = entity
        end
    end

    self.owner_hero = parent.chen_build_owner_hero
        or (worker and GetOwnerHeroFromWorker(worker))
        or GetOwnerHeroFromWorker(parent)
    self.max_hp = math.max(2, tonumber(kv.max_hp) or 2000)
    self.build_rate = tonumber(kv.build_rate) or 70
    self.worker_radius = tonumber(kv.worker_radius) or 100
    self.worker_entindex = tonumber(kv.worker_entindex)
    self.gold_cost = tonumber(kv.gold_cost) or 0
    self.completed = false
    self.scepter_stopped = false
    self.is_tower = tonumber(kv.is_tower) == 1
    self.is_sub_barrack = tonumber(kv.is_sub_barrack) == 1
    self.last_reported_pct = -1
    self.last_building_health = parent:GetHealth()
    self.last_worker_health = worker and worker:GetHealth() or nil

    parent:SetBaseMaxHealth(self.max_hp)
    parent:SetMaxHealth(self.max_hp)
    parent:SetHealth(1)

    if self.is_tower then
        parent:SetAttackCapability(DOTA_UNIT_CAP_NO_ATTACK)
    end

    parent:RemoveModifierByName("modifier_invulnerable")

    if self.is_sub_barrack and ChenSubBarrack and ChenSubBarrack.DisableProduction then
        ChenSubBarrack.DisableProduction(parent)
    end

    local origin = parent:GetAbsOrigin()
    self.repair_particle = ParticleManager:CreateParticle(REPAIR_PARTICLE, PATTACH_WORLDORIGIN, nil)
    ParticleManager:SetParticleControl(self.repair_particle, 0, origin)
    ParticleManager:SetParticleControl(self.repair_particle, 1, origin)

    self.ring_particle = ParticleManager:CreateParticle(CONSTRUCTION_RING_PARTICLE, PATTACH_WORLDORIGIN, nil)
    ParticleManager:SetParticleControl(self.ring_particle, 0, origin)
    ParticleManager:SetParticleControl(self.ring_particle, 1, Vector(120, 0, 0))

    if self.repair_particle then
        BuildDebug("5) Партикл стройки создан", "particle=", REPAIR_PARTICLE, "building=", DescribeUnit(parent))
    else
        BuildDebug("FAIL) Партикл стройки не создан", REPAIR_PARTICLE)
    end
    self:StartIntervalThink(0.1)
end

local function UpdateConstructionParticles(modifier)
    if not modifier then
        return
    end

    local parent = modifier:GetParent()
    if not IsValidEntity(parent) then
        return
    end

    local origin = parent:GetAbsOrigin()
    if modifier.repair_particle then
        ParticleManager:SetParticleControl(modifier.repair_particle, 0, origin)
        ParticleManager:SetParticleControl(modifier.repair_particle, 1, origin)
    end
    if modifier.ring_particle then
        ParticleManager:SetParticleControl(modifier.ring_particle, 0, origin)
        local progress = math.min(1, parent:GetHealth() / math.max(1, modifier.max_hp or 1))
        ParticleManager:SetParticleControl(modifier.ring_particle, 1, Vector(120, 120 * progress, 0))
    end
end

function modifier_chen_building_construction:GetAssignedWorker()
    if not self.worker_entindex then
        return nil
    end
    local ok, worker = pcall(EntIndexToHScript, self.worker_entindex)
    if ok and IsValidEntity(worker) then
        return worker
    end
    return nil
end

function modifier_chen_building_construction:CanProgress()
    if self.completed or self.scepter_stopped then
        return false
    end
    if not self.owner_hero or not ChenBarrackHasScepterUpgrade(self.owner_hero) then
        return false
    end

    local worker = self:GetAssignedWorker()
    if not worker or not worker:IsAlive() then
        return false
    end

    local parent = self:GetParent()
    return GetWorkerDistanceToBuilding(worker, parent) <= self.worker_radius
end

function modifier_chen_building_construction:OnIntervalThink()
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if not parent:IsAlive() then
        return
    end

    if self.completed then
        return
    end

    local worker = self:GetAssignedWorker()
    local buildingHealth = parent:GetHealth()

    if buildingHealth < (self.last_building_health or buildingHealth) then
        BuildDebug(
            "8) Стройка атакована",
            DescribeUnit(parent),
            "hp=",
            buildingHealth,
            "was=",
            self.last_building_health
        )
    end
    self.last_building_health = buildingHealth

    if worker and worker:IsAlive() then
        local workerHealth = worker:GetHealth()
        if self.last_worker_health and workerHealth < self.last_worker_health then
            BuildDebug(
                "9) Строитель атакован",
                DescribeUnit(worker),
                "hp=",
                workerHealth,
                "was=",
                self.last_worker_health
            )
        end
        self.last_worker_health = workerHealth
    end

    UpdateConstructionParticles(self)

    if not self:CanProgress() then
        return
    end

    local newHealth = math.min(self.max_hp, parent:GetHealth() + self.build_rate * 0.1)
    parent:SetHealth(newHealth)
    self.last_building_health = newHealth

    local pct = math.floor(newHealth / self.max_hp * 100)
    if pct ~= self.last_reported_pct then
        self.last_reported_pct = pct
        BuildDebug("7) Стройка выполнена на", pct .. "%", DescribeUnit(parent))
    end

    if newHealth >= self.max_hp then
        self:CompleteConstruction()
    end
end

function modifier_chen_building_construction:CompleteConstruction()
    if self.completed then
        return
    end

    self.completed = true
    local parent = self:GetParent()
    parent:SetHealth(self.max_hp)

    if self.is_tower then
        ChenWorkerBuild.ActivateTower(parent)
    end

    if self.is_sub_barrack and ChenSubBarrack and ChenSubBarrack.EnableProduction then
        ChenSubBarrack.EnableProduction(parent)
    end

    local worker = self:GetAssignedWorker()
    if worker then
        ChenWorkerBuild.ReleaseWorker(worker)
    end

    if self.repair_particle then
        ParticleManager:DestroyParticle(self.repair_particle, true)
        ParticleManager:ReleaseParticleIndex(self.repair_particle)
        self.repair_particle = nil
    end
    if self.ring_particle then
        ParticleManager:DestroyParticle(self.ring_particle, true)
        ParticleManager:ReleaseParticleIndex(self.ring_particle)
        self.ring_particle = nil
    end

    BuildDebug("10) Стройка завершилась", DescribeUnit(parent))
    self:Destroy()
end

function modifier_chen_building_construction:OnDestroy()
    if not IsServer() then
        return
    end

    if self.repair_particle then
        ParticleManager:DestroyParticle(self.repair_particle, true)
        ParticleManager:ReleaseParticleIndex(self.repair_particle)
        self.repair_particle = nil
    end
    if self.ring_particle then
        ParticleManager:DestroyParticle(self.ring_particle, true)
        ParticleManager:ReleaseParticleIndex(self.ring_particle)
        self.ring_particle = nil
    end

    if self.completed then
        return
    end

    local worker = self:GetAssignedWorker()
    if worker then
        ChenWorkerBuild.ReleaseWorker(worker)
    end

    BuildDebug("FAIL) Стройка прервана", DescribeUnit(self:GetParent()), "completed=", tostring(self.completed))
end

function modifier_chen_building_construction:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_DEATH,
    }
end

function modifier_chen_building_construction:OnDeath(event)
    if not IsServer() or self.completed then
        return
    end

    if event.unit ~= self:GetParent() then
        return
    end

    BuildDebug("FAIL) Стройка уничтожена", DescribeUnit(self:GetParent()))

    local worker = self:GetAssignedWorker()
    if worker then
        ChenWorkerBuild.ReleaseWorker(worker)
    end
end

local function GetTowerAttackProjectile(tower)
    if not IsValidEntity(tower) then
        return TOWER_ATTACK_PROJECTILE_GOOD
    end

    if tower:GetTeamNumber() == DOTA_TEAM_BADGUYS then
        return TOWER_ATTACK_PROJECTILE_BAD
    end

    return TOWER_ATTACK_PROJECTILE_GOOD
end

function ChenWorkerBuild.GetTowerAttackAbility(tower)
    if not IsValidEntity(tower) then
        return nil
    end

    local ability = tower:FindAbilityByName("chen_building_tower_attack")
    if not ability or ability:IsNull() then
        ability = tower:AddAbility("chen_building_tower_attack")
    end

    if ability and not ability:IsNull() and ability:GetLevel() < 1 then
        ability:SetLevel(1)
    end

    return ability
end

function ChenWorkerBuild.SpawnTowerAttackProjectile(tower, target)
    if not IsValidEntity(tower) or not IsValidEntity(target) then
        return
    end

    local ability = ChenWorkerBuild.GetTowerAttackAbility(tower)
    if not ability or ability:IsNull() then
        return
    end

    local sourceLoc = tower:GetAbsOrigin()
    if tower.GetAttackPosition then
        sourceLoc = tower:GetAttackPosition()
    end

    ProjectileManager:CreateTrackingProjectile({
        EffectName = GetTowerAttackProjectile(tower),
        Ability = ability,
        Source = tower,
        vSourceLoc = sourceLoc,
        Target = target,
        iMoveSpeed = TOWER_PROJECTILE_SPEED,
        bDodgeable = false,
        bVisibleToEnemies = true,
        bProvidesVision = false,
    })
end

function chen_building_tower_attack:OnProjectileHit(target, location)
    if not target or target:IsNull() or not target:IsAlive() then
        return true
    end

    local tower = self:GetCaster()
    if not IsValidEntity(tower) or not tower:IsAlive() then
        return true
    end

    if target:IsInvulnerable() then
        return true
    end

    ApplyDamage({
        victim = target,
        attacker = tower,
        damage = tower:GetAttackDamage(),
        damage_type = DAMAGE_TYPE_PHYSICAL,
        ability = self,
    })

    return true
end

function ChenWorkerBuild.ActivateTower(tower)
    if not IsValidEntity(tower) then
        return
    end

    tower:RemoveModifierByName("modifier_invulnerable")
    tower:SetAttackCapability(DOTA_UNIT_CAP_RANGED_ATTACK)
    ChenWorkerBuild.GetTowerAttackAbility(tower)

    if tower.SetAcquisitionRange then
        tower:SetAcquisitionRange(700)
    end

    if not tower:HasModifier("modifier_chen_building_tower_active") then
        tower:AddNewModifier(tower, nil, "modifier_chen_building_tower_active", {
            radius = 700,
        })
    end

    BuildDebug("Tower activated", DescribeUnit(tower))
end

modifier_chen_building_tower_active = class({})

function modifier_chen_building_tower_active:IsHidden()
    return true
end

function modifier_chen_building_tower_active:IsPurgable()
    return false
end

function modifier_chen_building_tower_active:OnCreated(kv)
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    self.radius = tonumber(kv.radius) or 700
    self.attack_interval = parent:GetSecondsPerAttack(false) or 0.9
    self.next_attack_time = GameRules:GetGameTime()
    self:StartIntervalThink(0.25)
end

function modifier_chen_building_tower_active:FindAttackTarget(parent)
    local enemies = FindUnitsInRadius(
        parent:GetTeamNumber(),
        parent:GetAbsOrigin(),
        nil,
        self.radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
        FIND_CLOSEST,
        false
    )

    for _, enemy in pairs(enemies) do
        if enemy and not enemy:IsNull() and enemy:IsAlive() and not enemy:IsInvulnerable() then
            return enemy
        end
    end

    return nil
end

function modifier_chen_building_tower_active:OnIntervalThink()
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if not parent:IsAlive() then
        return
    end

    if parent:GetAttackCapability() == DOTA_UNIT_CAP_NO_ATTACK then
        parent:SetAttackCapability(DOTA_UNIT_CAP_RANGED_ATTACK)
    end

    local now = GameRules:GetGameTime()
    if now < self.next_attack_time then
        return
    end

    local enemy = self:FindAttackTarget(parent)
    if not enemy then
        return
    end

    parent:FaceTowards(enemy:GetAbsOrigin())
    parent:StartGesture(ACT_DOTA_ATTACK)
    ChenWorkerBuild.SpawnTowerAttackProjectile(parent, enemy)
    self.next_attack_time = now + (parent:GetSecondsPerAttack(false) or self.attack_interval)
end

function ChenWorkerBuild.Precache(context)
    PrecacheResource("particle", REPAIR_PARTICLE, context)
    PrecacheResource("particle", CONSTRUCTION_RING_PARTICLE, context)
    PrecacheResource("particle", TOWER_ATTACK_PROJECTILE_GOOD, context)
    PrecacheResource("particle", TOWER_ATTACK_PROJECTILE_BAD, context)
    PrecacheResource("particle", "particles/neutral_fx/black_dragon_attack.vpcf", context)

    PrecacheResource("model", "models/props_structures/tower_good.vmdl", context)
    PrecacheResource("model", "models/props_structures/good_barracks_melee001.vmdl", context)
    PrecacheResource("model", "models/creeps/neutral_creeps/n_creep_centaur_lrg/n_creep_centaur_lrg.vmdl", context)
    PrecacheResource("model", "models/creeps/neutral_creeps/n_creep_black_dragon/n_creep_black_dragon.vmdl", context)

    PrecacheResource("soundfile", "soundevents/game_sounds_creeps.vsndevts", context)

    PrecacheUnitByNameSync("npc_chen_building_tower", context)
    PrecacheUnitByNameSync("npc_chen_building_thunderhide_barrack", context)
    PrecacheUnitByNameSync("npc_chen_building_dragon_barrack", context)
    PrecacheUnitByNameSync("npc_chen_ancient_thunderhide", context)
    PrecacheUnitByNameSync("npc_chen_ancient_black_dragon", context)
end

function chen_worker_build_tower:Precache(context)
    ChenWorkerBuild.Precache(context)
end

function chen_worker_build_thunderhide_barrack:Precache(context)
    ChenWorkerBuild.Precache(context)
end

function chen_worker_build_dragon_barrack:Precache(context)
    ChenWorkerBuild.Precache(context)
end
