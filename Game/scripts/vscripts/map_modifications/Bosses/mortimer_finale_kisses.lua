require("map_modifications/Bosses/mortimer_level_scaling")

LinkLuaModifier(
    "modifier_mortimer_finale_kisses_target",
    "map_modifications/Bosses/mortimer_finale_kisses",
    LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
    "modifier_mortimer_finale_kisses_burn",
    "map_modifications/Bosses/mortimer_finale_kisses",
    LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
    "modifier_mortimer_finale_kisses_burn_debuff",
    "map_modifications/Bosses/mortimer_finale_kisses",
    LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
    "modifier_mortimer_finale_kisses_building_no_heal",
    "map_modifications/Bosses/mortimer_finale_kisses",
    LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
    "modifier_mortimer_finale_kisses_tower3_armor",
    "map_modifications/Bosses/mortimer_finale_kisses",
    LUA_MODIFIER_MOTION_NONE
)

mortimer_finale_kisses = class({})

local function IsAlive(unit)
    return unit and not unit:IsNull() and unit:IsAlive()
end

local function HasLivingPlayerHero(team)
    for _, hero in ipairs(HeroList:GetAllHeroes()) do
        if IsAlive(hero) and hero:IsRealHero() and hero:GetTeamNumber() == team then
            return true
        end
    end

    return false
end

local function IsVulnerableBuilding(building, targetTeam)
    return IsAlive(building)
        and building.IsBuilding
        and building:IsBuilding()
        and building:GetTeamNumber() == targetTeam
        and not building:IsInvulnerable()
end

local TIER3_ARMOR_REDUCTION = 8

local function IsTier3Building(building)
    if not building or building:IsNull() then
        return false
    end

    local towers = GameMode and GameMode.towers
    if towers then
        local entindex = building:entindex()
        for _, towerInfo in ipairs(towers) do
            if towerInfo.entindex == entindex or towerInfo.entity == building then
                return tonumber(towerInfo.tier) == 3
            end
        end
    end

    return string.find(string.lower(building:GetUnitName() or ""), "tower3", 1, true) ~= nil
end

local function IsThroneBuilding(building)
    if not building or building:IsNull() then
        return false
    end

    local ancients = GameMode and GameMode.ancients
    if ancients then
        local entindex = building:entindex()
        for _, ancientInfo in ipairs(ancients) do
            if ancientInfo.entindex == entindex or ancientInfo.entity == building then
                return true
            end
        end
    end

    local unitName = string.lower(building:GetUnitName() or "")
    if string.find(unitName, "fort", 1, true) then
        return true
    end

    return building.GetClassname and building:GetClassname() == "npc_dota_fort"
end

local function GetBuildingTargetPriority(building, towerInfo)
    local entityName = string.lower((building and building.GetName and building:GetName()) or "")
    local unitName = string.lower((building and building.GetUnitName and building:GetUnitName()) or "")
    local tier = towerInfo and tonumber(towerInfo.tier)
    local lane = string.lower(tostring((towerInfo and towerInfo.lane) or ""))

    if lane ~= "top" and lane ~= "mid" and lane ~= "bot" then
        if string.find(unitName, "mid", 1, true) or string.find(entityName, "middle_", 1, true) then
            lane = "mid"
        elseif string.find(unitName, "top", 1, true) or string.find(entityName, "top_", 1, true) then
            lane = "top"
        elseif string.find(unitName, "bot", 1, true) or string.find(entityName, "bottom_", 1, true) then
            lane = "bot"
        end
    end

    if not tier then
        if string.find(entityName, "tier_1", 1, true) or string.find(unitName, "tower1", 1, true) then
            tier = 1
        elseif string.find(unitName, "tower2", 1, true) or string.find(entityName, "middle_tier_2", 1, true) then
            tier = 2
        elseif string.find(unitName, "tower3", 1, true)
            or string.find(entityName, "top_tier_2", 1, true)
            or string.find(entityName, "bottom_tier_2", 1, true) then
            tier = 3
        end
    end

    if tier == 1 then
        return 1
    end

    if lane == "mid" and (tier == 2 or tier == 3) then
        return 2
    end

    if tier == 2 then
        return 3
    end

    if tier == 3 then
        return 4
    end

    if IsThroneBuilding(building) then
        return 5
    end

    return nil
end

local function ConsiderBuildingTarget(building, towerInfo, targetTeam, position, best)
    if not IsVulnerableBuilding(building, targetTeam) then
        return
    end

    local priority = GetBuildingTargetPriority(building, towerInfo)
    if not priority then
        return
    end

    local distance = (building:GetAbsOrigin() - position):Length2D()
    if priority < best.priority or (priority == best.priority and distance < best.distance) then
        best.building = building
        best.priority = priority
        best.distance = distance
    end
end

local function FindPriorityBuilding(position, targetTeam)
    local best = {
        building = nil,
        priority = math.huge,
        distance = math.huge,
    }

    local towers = GameMode and GameMode.towers
    if towers then
        for _, towerInfo in ipairs(towers) do
            ConsiderBuildingTarget(towerInfo.entity, towerInfo, targetTeam, position, best)
        end
    end

    local ancients = GameMode and GameMode.ancients
    if ancients then
        for _, ancientInfo in ipairs(ancients) do
            ConsiderBuildingTarget(ancientInfo.entity, nil, targetTeam, position, best)
        end
    end

    if not best.building then
        local buildings = FindUnitsInRadius(
            DOTA_TEAM_NEUTRALS,
            position,
            nil,
            FIND_UNITS_EVERYWHERE,
            DOTA_UNIT_TARGET_TEAM_ENEMY,
            DOTA_UNIT_TARGET_BUILDING,
            DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
            FIND_ANY_ORDER,
            false
        )

        for _, building in ipairs(buildings) do
            ConsiderBuildingTarget(building, nil, targetTeam, position, best)
        end
    end

    return best.building, best.priority
end

local function IsKissesDebugEnabled()
    return MortimerBoss and MortimerBoss.kissesDebugEnabled
end

local function FormatVector(position)
    if not position then
        return "nil"
    end

    return string.format("%.0f,%.0f,%.0f", position.x, position.y, position.z)
end

local function DescribeKissesUnit(unit)
    if not unit or unit:IsNull() then
        return "none"
    end

    return string.format(
        "%s[%d] entity=%s team=%s alive=%s invuln=%s pos=%s",
        unit:GetUnitName() or "unknown",
        unit:entindex(),
        unit:GetName() or "",
        tostring(unit:GetTeamNumber()),
        tostring(unit:IsAlive()),
        tostring(unit:IsInvulnerable()),
        FormatVector(unit:GetAbsOrigin())
    )
end

local function KissesDebug(message, ...)
    if not IsKissesDebugEnabled() then
        return
    end

    print("[MortimerKissesDebug] " .. string.format(message, ...))
end

local function LogTowerSnapshot(targetTeam)
    if not IsKissesDebugEnabled() then
        return
    end

    local towers = GameMode and GameMode.towers
    if not towers then
        KissesDebug("towers=missing")
        return
    end

    for _, towerInfo in ipairs(towers) do
        local building = towerInfo.entity
        if building and not building:IsNull() and building:GetTeamNumber() == targetTeam then
            KissesDebug(
                "tower %s tier=%s lane=%s priority=%s vulnerable=%s",
                DescribeKissesUnit(building),
                tostring(towerInfo.tier),
                tostring(towerInfo.lane),
                tostring(GetBuildingTargetPriority(building, towerInfo) or "none"),
                tostring(IsVulnerableBuilding(building, targetTeam))
            )
        end
    end

    local ancients = GameMode and GameMode.ancients
    if not ancients then
        return
    end

    for _, ancientInfo in ipairs(ancients) do
        local building = ancientInfo.entity
        if building and not building:IsNull() and building:GetTeamNumber() == targetTeam then
            KissesDebug(
                "ancient %s priority=%s vulnerable=%s",
                DescribeKissesUnit(building),
                tostring(GetBuildingTargetPriority(building, nil) or "none"),
                tostring(IsVulnerableBuilding(building, targetTeam))
            )
        end
    end
end

function mortimer_finale_kisses:Precache(context)
    PrecacheResource("particle", "particles/units/heroes/hero_snapfire/snapfire_lizard_blobs_arced.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_snapfire/hero_snapfire_ultimate_calldown.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_snapfire/hero_snapfire_ultimate_impact.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_snapfire/hero_snapfire_ultimate_linger.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_snapfire/hero_snapfire_burn_debuff.vpcf", context)
end

function mortimer_finale_kisses:GetBehavior()
    return DOTA_ABILITY_BEHAVIOR_PASSIVE + DOTA_ABILITY_BEHAVIOR_HIDDEN
end

function mortimer_finale_kisses:GetSourcePosition()
    local caster = self:GetCaster()
    local attachment = caster:ScriptLookupAttachment("attach_mount_head")
    if attachment and attachment > 0 then
        return caster:GetAttachmentOrigin(attachment) + Vector(0, 0, 50)
    end

    return caster:GetAbsOrigin() + Vector(0, 0, 200)
end

function mortimer_finale_kisses:ClampTargetPosition(position)
    local caster = self:GetCaster()
    local origin = caster:GetAbsOrigin()
    local offset = position - origin
    offset.z = 0

    local distance = offset:Length2D()
    local direction = distance > 0 and offset:Normalized() or caster:GetForwardVector()
    local minRange = self:GetSpecialValueFor("min_range")
    local maxRange = self:GetSpecialValueFor("max_range")
    distance = math.max(minRange, math.min(maxRange, distance))

    return GetGroundPosition(origin + direction * distance, caster), distance
end

function mortimer_finale_kisses:ResolveTarget(fallbackPosition, targetTeam)
    local result = {
        position = fallbackPosition,
        reason = "fallback",
        target = nil,
        priority = nil,
        livingHeroes = false,
        targetTeam = targetTeam,
    }

    if not targetTeam then
        result.reason = "no_target_team"
        return result
    end

    result.livingHeroes = HasLivingPlayerHero(targetTeam)

    local caster = self:GetCaster()
    local heroes = FindUnitsInRadius(
        caster:GetTeamNumber(),
        caster:GetAbsOrigin(),
        nil,
        self:GetSpecialValueFor("max_range"),
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO,
        DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE + DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
        FIND_CLOSEST,
        false
    )

    for _, hero in ipairs(heroes) do
        if IsAlive(hero)
            and hero:IsRealHero()
            and hero:GetTeamNumber() == targetTeam
            and caster:CanEntityBeSeenByMyTeam(hero) then
            result.position = hero:GetAbsOrigin()
            result.reason = "hero"
            result.target = hero
            return result
        end
    end

    if not result.livingHeroes then
        local building, priority = FindPriorityBuilding(caster:GetAbsOrigin(), targetTeam)
        if building then
            result.position = building:GetAbsOrigin()
            result.reason = "building"
            result.target = building
            result.priority = priority
            return result
        end

        result.position = nil
        result.reason = "no_building"
        return result
    end

    result.reason = "heroes_alive_out_of_vision"
    return result
end

function mortimer_finale_kisses:GetCurrentTargetPosition(fallbackPosition, targetTeam)
    return self:ResolveTarget(fallbackPosition, targetTeam).position
end

function mortimer_finale_kisses:LogDecision(stage, decision, extra)
    if not IsKissesDebugEnabled() or not decision then
        return
    end

    extra = extra or {}
    KissesDebug(
        "%s team=%s living_heroes=%s reason=%s priority=%s target=%s pos=%s%s",
        stage,
        tostring(decision.targetTeam),
        tostring(decision.livingHeroes),
        tostring(decision.reason),
        tostring(decision.priority or "none"),
        DescribeKissesUnit(decision.target),
        FormatVector(decision.position),
        extra.suffix or ""
    )

    if extra.snapshot then
        LogTowerSnapshot(decision.targetTeam)
    end
end

function mortimer_finale_kisses:FireVolley(initialTargetPosition, targetTeam, onFinished)
    if not IsServer() then
        return
    end

    local caster = self:GetCaster()
    self.volleyTargetTeam = targetTeam
    local projectileCount = MortimerLevelScaling:GetKissesProjectileCount(self)
    local volleyDuration = MortimerLevelScaling:GetKissesDuration(self)
    local startAnimationDelay = self:GetSpecialValueFor("start_animation_delay")
    local interval = projectileCount > 1 and volleyDuration / (projectileCount - 1) or 0

    KissesDebug(
        "volley shots=%d duration=%.1f team=%s initial_pos=%s",
        projectileCount,
        volleyDuration,
        tostring(targetTeam),
        FormatVector(initialTargetPosition)
    )

    caster:ResetSequence("snapfire_blobs_cast")

    for shot = 1, projectileCount do
        local shotNumber = shot
        Timers:CreateTimer(startAnimationDelay + (shotNumber - 1) * interval, function()
            if not IsAlive(caster) then
                KissesDebug("shot=%d/%d skip caster_dead", shotNumber, projectileCount)
                return nil
            end

            local decision = self:ResolveTarget(initialTargetPosition, targetTeam)
            self:LogDecision(
                "shot",
                decision,
                { suffix = string.format(" shot=%d/%d", shotNumber, projectileCount) }
            )
            local targetPosition = decision.position
            if not targetPosition then
                return nil
            end

            local spread = self:GetSpecialValueFor("target_spread")
            targetPosition = targetPosition + RandomVector(RandomFloat(0, spread))
            targetPosition = self:ClampTargetPosition(targetPosition)

            local facing = targetPosition - caster:GetAbsOrigin()
            facing.z = 0
            if facing:Length2D() > 0 then
                caster:SetForwardVector(facing:Normalized())
            end

            self:LaunchProjectile(targetPosition)
            caster:ResetSequence("snapfire_blobs_fast")
            return nil
        end)
    end

    if onFinished then
        Timers:CreateTimer(startAnimationDelay + volleyDuration + 0.55, function()
            if IsAlive(caster) then
                onFinished()
            end
            return nil
        end)
    end
end

function mortimer_finale_kisses:LaunchProjectile(position)
    local caster = self:GetCaster()
    local targetPosition, distance = self:ClampTargetPosition(position)
    local minRange = self:GetSpecialValueFor("min_range")
    local maxRange = self:GetSpecialValueFor("max_range")
    local minTravelTime = self:GetSpecialValueFor("min_lob_travel_time")
    local maxTravelTime = self:GetSpecialValueFor("max_lob_travel_time")
    local rangeFraction = (distance - minRange) / math.max(1, maxRange - minRange)
    local travelTime = minTravelTime + rangeFraction * (maxTravelTime - minTravelTime)

    local target = CreateModifierThinker(
        caster,
        self,
        "modifier_mortimer_finale_kisses_target",
        { duration = travelTime + 0.5, travel_time = travelTime },
        targetPosition,
        caster:GetTeamNumber(),
        false
    )
    if not target then
        return
    end

    local sourcePosition = self:GetSourcePosition()
    local speed = distance / math.max(0.01, travelTime)
    local particle = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_snapfire/snapfire_lizard_blobs_arced.vpcf",
        PATTACH_WORLDORIGIN,
        nil
    )
    ParticleManager:SetParticleControl(particle, 0, sourcePosition)
    ParticleManager:SetParticleControl(particle, 1, targetPosition)
    ParticleManager:SetParticleControl(particle, 2, Vector(speed, 0, 0))

    ProjectileManager:CreateTrackingProjectile({
        Source = caster,
        Target = target,
        Ability = self,
        vSourceLoc = caster:GetAbsOrigin(),
        iMoveSpeed = speed,
        bDodgeable = false,
        bVisibleToEnemies = true,
        bDrawsOnMinimap = false,
        bProvidesVision = true,
        iVisionRadius = self:GetSpecialValueFor("projectile_vision"),
        iVisionTeamNumber = caster:GetTeamNumber(),
        ExtraData = {
            particle = particle,
        },
    })

    caster:EmitSound("Hero_Snapfire.MortimerBlob.Launch")
end

function mortimer_finale_kisses:OnProjectileHit_ExtraData(target, location, extraData)
    if extraData and extraData.particle then
        ParticleManager:DestroyParticle(extraData.particle, false)
        ParticleManager:ReleaseParticleIndex(extraData.particle)
    end
    if not target then
        return true
    end

    location = GetGroundPosition(location or target:GetAbsOrigin(), self:GetCaster())
    if not target:IsNull() then
        target:RemoveModifierByName("modifier_mortimer_finale_kisses_target")
    end

    local caster = self:GetCaster()
    local radius = self:GetSpecialValueFor("impact_radius")
    local units = FindUnitsInRadius(
        caster:GetTeamNumber(),
        location,
        nil,
        radius,
        DOTA_UNIT_TARGET_TEAM_BOTH,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC + DOTA_UNIT_TARGET_BUILDING,
        DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
        FIND_ANY_ORDER,
        false
    )

    for _, unit in ipairs(units) do
        local vulnerableBuilding = unit:IsBuilding()
            and IsVulnerableBuilding(unit, self.volleyTargetTeam)
        if unit:GetTeamNumber() == self.volleyTargetTeam
            and (not unit:IsBuilding() or vulnerableBuilding) then
            ApplyDamage({
                victim = unit,
                attacker = caster,
                damage = MortimerLevelScaling:GetKissesImpactDamage(self),
                damage_type = unit:IsBuilding() and DAMAGE_TYPE_PHYSICAL or DAMAGE_TYPE_MAGICAL,
                ability = self,
            })
            if vulnerableBuilding then
                local burnDuration = MortimerLevelScaling:GetKissesBurnDuration(self)
                unit:AddNewModifier(caster, self, "modifier_mortimer_finale_kisses_building_no_heal", {
                    duration = burnDuration,
                })
                if IsTier3Building(unit) or IsThroneBuilding(unit) then
                    unit:AddNewModifier(caster, self, "modifier_mortimer_finale_kisses_tower3_armor", {
                        duration = burnDuration,
                    })
                end
            end
        end
    end

    local impact = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_snapfire/hero_snapfire_ultimate_impact.vpcf",
        PATTACH_WORLDORIGIN,
        nil
    )
    ParticleManager:SetParticleControl(impact, 3, location)
    ParticleManager:ReleaseParticleIndex(impact)
    EmitSoundOnLocationWithCaster(location, "Hero_Snapfire.MortimerBlob.Impact", caster)

    CreateModifierThinker(
        caster,
        self,
        "modifier_mortimer_finale_kisses_burn",
        { duration = MortimerLevelScaling:GetKissesBurnDuration(self) },
        location,
        caster:GetTeamNumber(),
        false
    )

    return true
end


modifier_mortimer_finale_kisses_target = class({})

function modifier_mortimer_finale_kisses_target:IsHidden()
    return true
end

function modifier_mortimer_finale_kisses_target:IsPurgable()
    return false
end

function modifier_mortimer_finale_kisses_target:OnCreated(kv)
    if not IsServer() then
        return
    end

    local radius = self:GetAbility():GetSpecialValueFor("impact_radius")
    local maxTravelTime = self:GetAbility():GetSpecialValueFor("max_lob_travel_time")
    local travelTime = tonumber(kv.travel_time) or maxTravelTime
    local warning = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_snapfire/hero_snapfire_ultimate_calldown.vpcf",
        PATTACH_CUSTOMORIGIN,
        self:GetParent()
    )
    ParticleManager:SetParticleControl(warning, 0, self:GetParent():GetAbsOrigin())
    ParticleManager:SetParticleControl(warning, 1, Vector(radius, 0, -radius * (maxTravelTime / travelTime)))
    ParticleManager:SetParticleControl(warning, 2, Vector(travelTime, 0, 0))
    self:AddParticle(warning, false, false, -1, false, false)
end

function modifier_mortimer_finale_kisses_target:CheckState()
    return {
        [MODIFIER_STATE_INVULNERABLE] = true,
        [MODIFIER_STATE_NO_HEALTH_BAR] = true,
        [MODIFIER_STATE_UNSELECTABLE] = true,
        [MODIFIER_STATE_NOT_ON_MINIMAP] = true,
    }
end

function modifier_mortimer_finale_kisses_target:OnDestroy()
    if IsServer() then
        UTIL_Remove(self:GetParent())
    end
end


modifier_mortimer_finale_kisses_burn = class({})

function modifier_mortimer_finale_kisses_burn:IsHidden()
    return true
end

function modifier_mortimer_finale_kisses_burn:IsPurgable()
    return false
end

function modifier_mortimer_finale_kisses_burn:OnCreated()
    if not IsServer() then
        return
    end

    local radius = self:GetAbility():GetSpecialValueFor("impact_radius")
    local particle = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_snapfire/hero_snapfire_ultimate_linger.vpcf",
        PATTACH_WORLDORIGIN,
        nil
    )
    ParticleManager:SetParticleControl(particle, 0, self:GetParent():GetAbsOrigin())
    ParticleManager:SetParticleControl(particle, 1, Vector(radius, 0, 0))
    self:AddParticle(particle, false, false, -1, false, false)
end

function modifier_mortimer_finale_kisses_burn:IsAura()
    return true
end

function modifier_mortimer_finale_kisses_burn:GetModifierAura()
    return "modifier_mortimer_finale_kisses_burn_debuff"
end

function modifier_mortimer_finale_kisses_burn:GetAuraRadius()
    return self:GetAbility():GetSpecialValueFor("impact_radius")
end

function modifier_mortimer_finale_kisses_burn:GetAuraDuration()
    return 0.5
end

function modifier_mortimer_finale_kisses_burn:GetAuraSearchTeam()
    return DOTA_UNIT_TARGET_TEAM_BOTH
end

function modifier_mortimer_finale_kisses_burn:GetAuraSearchType()
    return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC
end

function modifier_mortimer_finale_kisses_burn:GetAuraEntityReject(target)
    local ability = self:GetAbility()
    return not ability or target:GetTeamNumber() ~= ability.volleyTargetTeam
end

function modifier_mortimer_finale_kisses_burn:OnDestroy()
    if IsServer() then
        UTIL_Remove(self:GetParent())
    end
end


modifier_mortimer_finale_kisses_burn_debuff = class({})

function modifier_mortimer_finale_kisses_burn_debuff:IsHidden()
    return false
end

function modifier_mortimer_finale_kisses_burn_debuff:IsPurgable()
    return true
end

function modifier_mortimer_finale_kisses_burn_debuff:OnCreated()
    self.slow = -self:GetAbility():GetSpecialValueFor("move_slow_pct")
    self.damage = MortimerLevelScaling:GetKissesBurnDamage(self:GetAbility())
    self.interval = self:GetAbility():GetSpecialValueFor("burn_interval")

    if IsServer() then
        self:StartIntervalThink(self.interval)
    end
end

function modifier_mortimer_finale_kisses_burn_debuff:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
    }
end

function modifier_mortimer_finale_kisses_burn_debuff:GetModifierMoveSpeedBonus_Percentage()
    return self.slow
end

function modifier_mortimer_finale_kisses_burn_debuff:OnIntervalThink()
    if not IsServer() then
        return
    end

    local caster = self:GetCaster()
    if not caster or caster:IsNull() then
        self:Destroy()
        return
    end

    ApplyDamage({
        victim = self:GetParent(),
        attacker = caster,
        damage = self.damage * self.interval,
        damage_type = DAMAGE_TYPE_MAGICAL,
        ability = self:GetAbility(),
    })
end

function modifier_mortimer_finale_kisses_burn_debuff:GetEffectName()
    return "particles/units/heroes/hero_snapfire/hero_snapfire_burn_debuff.vpcf"
end

function modifier_mortimer_finale_kisses_burn_debuff:GetEffectAttachType()
    return PATTACH_ABSORIGIN_FOLLOW
end


modifier_mortimer_finale_kisses_building_no_heal = class({})

function modifier_mortimer_finale_kisses_building_no_heal:IsHidden()
    return true
end

function modifier_mortimer_finale_kisses_building_no_heal:IsPurgable()
    return false
end

function modifier_mortimer_finale_kisses_building_no_heal:IsDebuff()
    return true
end

function modifier_mortimer_finale_kisses_building_no_heal:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_DISABLE_HEALING,
    }
end

function modifier_mortimer_finale_kisses_building_no_heal:GetDisableHealing()
    return 1
end


modifier_mortimer_finale_kisses_tower3_armor = class({})

function modifier_mortimer_finale_kisses_tower3_armor:IsHidden()
    return true
end

function modifier_mortimer_finale_kisses_tower3_armor:IsPurgable()
    return false
end

function modifier_mortimer_finale_kisses_tower3_armor:IsDebuff()
    return true
end

function modifier_mortimer_finale_kisses_tower3_armor:GetAttributes()
    return MODIFIER_ATTRIBUTE_MULTIPLE
end

function modifier_mortimer_finale_kisses_tower3_armor:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
    }
end

function modifier_mortimer_finale_kisses_tower3_armor:GetModifierPhysicalArmorBonus()
    return -TIER3_ARMOR_REDUCTION
end
