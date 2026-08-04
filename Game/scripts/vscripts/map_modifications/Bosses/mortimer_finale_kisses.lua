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
    local attackImmune = building and building.IsAttackImmune and building:IsAttackImmune()
    return IsAlive(building)
        and building:IsBuilding()
        and building:GetTeamNumber() == targetTeam
        and not building:IsInvulnerable()
        and not attackImmune
end

local function GetBuildingTargetPriority(building)
    local entityName = string.lower(building:GetName() or "")
    local unitName = string.lower(building:GetUnitName() or "")

    if string.find(entityName, "tier_1", 1, true) then
        return 1
    end

    if string.find(entityName, "middle_tier_2", 1, true) then
        return 2
    end

    local isSideTier3 = string.find(entityName, "top_tier_2", 1, true)
        or string.find(entityName, "bottom_tier_2", 1, true)
    if isSideTier3 then
        return 3
    end

    if string.find(unitName, "tower1", 1, true) then
        return 1
    end

    if string.find(unitName, "tower3", 1, true)
        and string.find(unitName, "mid", 1, true) then
        return 2
    end

    if string.find(unitName, "tower3", 1, true)
        and (string.find(unitName, "top", 1, true)
            or string.find(unitName, "bot", 1, true)) then
        return 3
    end

    return nil
end

local function FindPriorityBuilding(caster, position, targetTeam, radius)
    local buildings = FindUnitsInRadius(
        caster:GetTeamNumber(),
        position,
        nil,
        radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_BUILDING,
        DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE + DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
        FIND_CLOSEST,
        false
    )

    local bestBuilding = nil
    local bestPriority = math.huge
    for _, building in ipairs(buildings) do
        if caster:CanEntityBeSeenByMyTeam(building)
            and IsVulnerableBuilding(building, targetTeam) then
            local priority = GetBuildingTargetPriority(building)
            if priority and priority < bestPriority then
                bestBuilding = building
                bestPriority = priority
            end
        end
    end

    return bestBuilding
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

function mortimer_finale_kisses:GetCurrentTargetPosition(fallbackPosition, targetTeam)
    if not targetTeam then
        return fallbackPosition
    end

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
            return hero:GetAbsOrigin()
        end
    end

    if not HasLivingPlayerHero(targetTeam) then
        local building = FindPriorityBuilding(
            caster,
            caster:GetAbsOrigin(),
            targetTeam,
            self:GetSpecialValueFor("max_range")
        )
        if building then
            return building:GetAbsOrigin()
        end
    end

    return fallbackPosition
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

    caster:ResetSequence("snapfire_blobs_cast")

    for shot = 1, projectileCount do
        local shotNumber = shot
        Timers:CreateTimer(startAnimationDelay + (shotNumber - 1) * interval, function()
            if not IsAlive(caster) then
                return nil
            end

            local targetPosition = self:GetCurrentTargetPosition(initialTargetPosition, targetTeam)
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
