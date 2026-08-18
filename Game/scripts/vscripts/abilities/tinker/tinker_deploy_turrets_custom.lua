LinkLuaModifier(
    "modifier_tinker_deploy_turrets_custom",
    "abilities/tinker/tinker_deploy_turrets_custom",
    LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
    "modifier_tinker_deploy_turrets_custom_turret",
    "abilities/tinker/tinker_deploy_turrets_custom",
    LUA_MODIFIER_MOTION_NONE
)

tinker_deploy_turrets_custom = class({})

local function IsValidUnit(unit)
    return unit and not unit:IsNull()
end

local function GetMindScaledSpecial(ability, base_key, multiplier_key)
    local caster = ability:GetCaster()
    local base = ability:GetSpecialValueFor(base_key)
    local multiplier = ability:GetSpecialValueFor(multiplier_key)
    local mind_power = GetHeroMindPower and (GetHeroMindPower(caster) or 0) or 0
    return math.max(0, base + mind_power * multiplier)
end

function tinker_deploy_turrets_custom:Precache(context)
    PrecacheResource("model", "models/heroes/tinker/tinker_turret.vmdl", context)
    PrecacheResource("particle", "particles/units/heroes/hero_tinker/tinker_turret_drop.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_tinker/tinker_turret_drop_impact.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_tinker/tinker_turret_spawn.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_tinker/tinker_missile.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_tinker/turret_missile_explosion.vpcf", context)
end

function tinker_deploy_turrets_custom:GetAOERadius()
    return self:GetSpecialValueFor("drop_aoe_radius")
end

function tinker_deploy_turrets_custom:OnSpellStart()
    if not IsServer() then
        return
    end

    local caster = self:GetCaster()
    CreateModifierThinker(
        caster,
        self,
        "modifier_tinker_deploy_turrets_custom",
        {},
        self:GetCursorPosition(),
        caster:GetTeamNumber(),
        false
    )
end

function tinker_deploy_turrets_custom:OnProjectileHit(target)
    if not IsServer() or not IsValidUnit(target) then
        return false
    end

    local caster = self:GetCaster()
    local damage = GetMindScaledSpecial(self, "missile_damage", "missile_mind_power_multiplier")
    local splash_damage = damage * self:GetSpecialValueFor("splash_pct") * 0.01

    ApplyDamage({
        attacker = caster,
        victim = target,
        damage = damage,
        damage_type = DAMAGE_TYPE_MAGICAL,
        ability = self,
    })

    local units = FindUnitsInRadius(
        caster:GetTeamNumber(),
        target:GetAbsOrigin(),
        nil,
        self:GetSpecialValueFor("radius_explosion"),
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
        FIND_ANY_ORDER,
        false
    )

    for _, unit in ipairs(units) do
        if unit ~= target then
            ApplyDamage({
                attacker = caster,
                victim = unit,
                damage = splash_damage,
                damage_type = DAMAGE_TYPE_MAGICAL,
                ability = self,
            })
        end
    end

    target:EmitSound("Hero_TinkerTurret.Missile.Impact")

    local particle = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_tinker/turret_missile_explosion.vpcf",
        PATTACH_CUSTOMORIGIN_FOLLOW,
        target
    )
    ParticleManager:SetParticleControlEnt(
        particle,
        0,
        target,
        PATTACH_POINT_FOLLOW,
        "attach_hitloc",
        target:GetAbsOrigin(),
        true
    )
    ParticleManager:ReleaseParticleIndex(particle)

    return true
end

modifier_tinker_deploy_turrets_custom = class({})

function modifier_tinker_deploy_turrets_custom:IsHidden()
    return true
end

function modifier_tinker_deploy_turrets_custom:IsPurgable()
    return false
end

function modifier_tinker_deploy_turrets_custom:OnCreated()
    if not IsServer() then
        return
    end

    local ability = self:GetAbility()
    self.point = self:GetParent():GetAbsOrigin()
    self.drop_aoe_radius = ability:GetSpecialValueFor("drop_aoe_radius")
    self.turret_placement_radius = ability:GetSpecialValueFor("turret_placement_radius")
    self.missile_target_range = ability:GetSpecialValueFor("missile_target_range")
    self.attack_interval = ability:GetSpecialValueFor("missile_spawn_interval")
    self.projectile_speed = ability:GetSpecialValueFor("missile_speed")
    self.missile_width = ability:GetSpecialValueFor("missile_width")
    self.drop_delay = ability:GetSpecialValueFor("drop_delay")
    self.turrets = {}

    self.drop_particle = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_tinker/tinker_turret_drop.vpcf",
        PATTACH_WORLDORIGIN,
        nil
    )
    ParticleManager:SetParticleControl(self.drop_particle, 0, self.point)
    ParticleManager:SetParticleControl(self.drop_particle, 1, Vector(self.drop_aoe_radius, 1, 1))
    ParticleManager:SetParticleControl(self.drop_particle, 3, Vector(self.turret_placement_radius, 1, 1))

    self:GetParent():EmitSound("Hero_TinkerTurret.Drop.Falling")
    self:StartIntervalThink(self.drop_delay)
end

function modifier_tinker_deploy_turrets_custom:OnIntervalThink()
    if not IsServer() then
        return
    end

    if not self.deployed then
        self:DeployTurrets()
        self.deployed = true
        self:StartIntervalThink(FrameTime())
        return
    end

    local has_live_turret = false
    local frame_time = FrameTime()

    for turret, state in pairs(self.turrets) do
        if IsValidUnit(turret) and turret:IsAlive() then
            has_live_turret = true
            state.time_until_attack = state.time_until_attack - frame_time

            self:UpdateTurretTarget(turret, state)

            if IsValidUnit(state.target) then
                turret:FaceTowards(state.target:GetAbsOrigin())

                if state.time_until_attack <= 0 then
                    self:FireTurret(turret, state.target)
                    state.time_until_attack = self.attack_interval
                end
            end
        end
    end

    if not has_live_turret then
        self:Destroy()
    end
end

function modifier_tinker_deploy_turrets_custom:DeployTurrets()
    local caster = self:GetCaster()
    local ability = self:GetAbility()

    self:GetParent():EmitSound("Hero_TinkerTurret.Drop.Impact")
    self:DestroyDropParticle()
    GridNav:DestroyTreesAroundPoint(self.point, self.drop_aoe_radius, false)

    local impact_particle = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_tinker/tinker_turret_drop_impact.vpcf",
        PATTACH_WORLDORIGIN,
        nil
    )
    ParticleManager:SetParticleControl(impact_particle, 0, self.point)
    ParticleManager:ReleaseParticleIndex(impact_particle)

    local targets = FindUnitsInRadius(
        caster:GetTeamNumber(),
        self.point,
        nil,
        self.drop_aoe_radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
        FIND_ANY_ORDER,
        false
    )

    if (caster:GetAbsOrigin() - self.point):Length2D() <= self.drop_aoe_radius then
        table.insert(targets, caster)
    end

    for _, target in ipairs(targets) do
        self:ApplyImpact(target)
    end

    local turret_count = ability:GetSpecialValueFor("turrets_per_drop")
    local turret_duration = ability:GetSpecialValueFor("turret_duration")
    local position = self.point + self.turret_placement_radius * Vector(0, 1, 0)

    for index = 1, turret_count do
        position = RotatePosition(self.point, QAngle(0, 360 / turret_count, 0), position)

        local spawn_particle = ParticleManager:CreateParticle(
            "particles/units/heroes/hero_tinker/tinker_turret_spawn.vpcf",
            PATTACH_WORLDORIGIN,
            nil
        )
        ParticleManager:SetParticleControl(spawn_particle, 0, position)
        ParticleManager:ReleaseParticleIndex(spawn_particle)

        local turret = CreateUnitByName(
            "npc_dota_tinker_turret" .. ability:GetLevel(),
            position,
            true,
            caster,
            caster,
            caster:GetTeamNumber()
        )

        if IsValidUnit(turret) then
            turret:SetOwner(caster)
            turret:SetForwardVector((self.point - position):Normalized())
            turret:AddNewModifier(caster, ability, "modifier_tinker_deploy_turrets_custom_turret", {})
            -- The extra second covers the deployment animation before the configured active lifetime.
            turret:AddNewModifier(caster, ability, "modifier_kill", { duration = turret_duration + 1 })

            self.turrets[turret] = {
                target = nil,
                time_until_attack = self.attack_interval,
            }
        end
    end
end

function modifier_tinker_deploy_turrets_custom:ApplyImpact(target)
    local caster = self:GetCaster()
    local ability = self:GetAbility()
    local is_caster = target == caster
    local distance_key = is_caster and "drop_knockback_distance_tinker" or "drop_knockback_distance"
    local duration_key = is_caster and "drop_knockback_duration_tinker" or "drop_knockback_duration"
    local knockback_center = self.point

    if (target:GetAbsOrigin() - knockback_center):Length2D() < 1 then
        knockback_center = knockback_center - target:GetForwardVector()
    end

    if not is_caster and ability and not ability:IsNull() then
        ApplyDamage({
            attacker = caster,
            victim = target,
            damage = GetMindScaledSpecial(ability, "drop_damage", "drop_mind_power_multiplier"),
            damage_type = DAMAGE_TYPE_MAGICAL,
            ability = ability,
        })
    end

    local duration = ability:GetSpecialValueFor(duration_key)
    target:AddNewModifier(caster, ability, "modifier_knockback", {
        center_x = knockback_center.x,
        center_y = knockback_center.y,
        center_z = knockback_center.z,
        duration = duration,
        knockback_duration = duration,
        knockback_distance = ability:GetSpecialValueFor(distance_key),
        knockback_height = 0,
        should_stun = 0,
    })
end

function modifier_tinker_deploy_turrets_custom:UpdateTurretTarget(turret, state)
    if IsValidUnit(state.target)
        and state.target:IsAlive()
        and not state.target:IsInvulnerable()
        and not state.target:IsOutOfGame()
        and turret:CanEntityBeSeenByMyTeam(state.target)
        and (state.target:GetAbsOrigin() - turret:GetAbsOrigin()):Length2D() <= self.missile_target_range then
        return
    end

    local targets = FindUnitsInRadius(
        self:GetCaster():GetTeamNumber(),
        turret:GetAbsOrigin(),
        nil,
        self.missile_target_range,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO,
        DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE + DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
        FIND_CLOSEST,
        false
    )

    state.target = targets[1]
end

function modifier_tinker_deploy_turrets_custom:DestroyDropParticle()
    if not self.drop_particle then
        return
    end

    ParticleManager:DestroyParticle(self.drop_particle, true)
    ParticleManager:ReleaseParticleIndex(self.drop_particle)
    self.drop_particle = nil
end

function modifier_tinker_deploy_turrets_custom:OnDestroy()
    if IsServer() then
        self:DestroyDropParticle()
    end
end

function modifier_tinker_deploy_turrets_custom:FireTurret(turret, target)
    turret:StartGestureWithPlaybackRate(ACT_DOTA_ATTACK, 1 / self.attack_interval)
    turret:EmitSound("Hero_TinkerTurret.Missile.Spawn")

    local attachment = turret:ScriptLookupAttachment("attach_attack1")

    ProjectileManager:CreateTrackingProjectile({
        Ability = self:GetAbility(),
        EffectName = "particles/units/heroes/hero_tinker/tinker_missile.vpcf",
        Source = turret,
        Target = target,
        vSourceLoc = turret:GetAttachmentOrigin(attachment),
        iMoveSpeed = self.projectile_speed,
        bDodgeable = true,
        bProvidesVision = true,
        iVisionTeamNumber = self:GetCaster():GetTeamNumber(),
        iVisionRadius = self.missile_width * 2,
    })
end

modifier_tinker_deploy_turrets_custom_turret = class({})

function modifier_tinker_deploy_turrets_custom_turret:IsHidden()
    return true
end

function modifier_tinker_deploy_turrets_custom_turret:IsPurgable()
    return false
end

function modifier_tinker_deploy_turrets_custom_turret:OnCreated()
    if IsServer() then
        self:GetParent():StartGesture(ACT_DOTA_SPAWN)
    end
end

function modifier_tinker_deploy_turrets_custom_turret:CheckState()
    return {
        [MODIFIER_STATE_DEBUFF_IMMUNE] = true,
        [MODIFIER_STATE_DISARMED] = true,
        [MODIFIER_STATE_MAGIC_IMMUNE] = true,
        [MODIFIER_STATE_ROOTED] = true,
    }
end
