LinkLuaModifier("modifier_lion_impale_custom_stun", "abilities/lion/lion_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_lion_impale_knockup", "abilities/lion/lion_abilities", LUA_MODIFIER_MOTION_VERTICAL)
LinkLuaModifier("modifier_lion_soul_collector_tracker", "abilities/lion/lion_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_lion_soul_collector_temp", "abilities/lion/lion_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_lion_soul_collector_permanent", "abilities/lion/lion_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_lion_spirit_siphon_custom", "abilities/lion/lion_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_lion_finger_rebirth", "abilities/lion/lion_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_lion_finger_kill_marker", "abilities/lion/lion_abilities", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_lion_finger_scepter_claw", "abilities/lion/lion_abilities", LUA_MODIFIER_MOTION_NONE)

local function LionGetMindPower(unit)
    if GetHeroMindPower then
        return GetHeroMindPower(unit) or 0
    end
    if unit and not unit:IsNull() and unit.GetIntellect then
        return unit:GetIntellect(false) or 0
    end
    return 0
end

local function LionAddStackedModifier(parent, ability, modifier_name, amount)
    if not parent or parent:IsNull() or amount <= 0 then
        return nil
    end

    local modifier = parent:FindModifierByName(modifier_name)
    if not modifier then
        modifier = parent:AddNewModifier(parent, ability, modifier_name, {})
    end
    if modifier and not modifier:IsNull() then
        modifier:SetStackCount(modifier:GetStackCount() + amount)
        modifier:ForceRefresh()
    end

    return modifier
end

local LION_SPIRIT_SIPHON_PARTICLE = "particles/units/heroes/hero_death_prophet/death_prophet_spiritsiphon.vpcf"

local function LionCreateSiphonParticle(caster, target)
    if not caster or caster:IsNull() or not target or target:IsNull() then
        return nil
    end

    local particle = ParticleManager:CreateParticle(LION_SPIRIT_SIPHON_PARTICLE, PATTACH_ABSORIGIN_FOLLOW, target)
    ParticleManager:SetParticleControlEnt(particle, 0, caster, PATTACH_POINT_FOLLOW, "attach_hitloc", caster:GetAbsOrigin(), true)
    ParticleManager:SetParticleControlEnt(particle, 1, target, PATTACH_POINT_FOLLOW, "attach_hitloc", target:GetAbsOrigin(), true)
    return particle
end

local function LionHasShard(unit)
    if not unit or unit:IsNull() then
        return false
    end
    if HasShard then
        return HasShard(unit)
    end
    return unit:HasModifier("modifier_item_aghanims_shard")
end

local function LionHasScepter(unit)
    if not unit or unit:IsNull() then
        return false
    end
    if unit.HasScepter and unit:HasScepter() then
        return true
    end
    return unit:HasModifier("modifier_item_ultimate_scepter") or unit:HasModifier("modifier_item_ultimate_scepter_consumed")
end

local function LionRotateDirection2D(direction, degrees)
    local radians = math.rad(degrees)
    local cos = math.cos(radians)
    local sin = math.sin(radians)
    return Vector(
        direction.x * cos - direction.y * sin,
        direction.x * sin + direction.y * cos,
        0
    ):Normalized()
end

lion_impale_custom = class({})

function lion_impale_custom:GetAOERadius()
    return self:GetSpecialValueFor("width")
end

function lion_impale_custom:GetMindScaledDamage()
    local caster = self:GetCaster()
    local base = self:GetSpecialValueFor("damage")
    local multiplier = self:GetSpecialValueFor("mind_power_multiplier")
    return math.max(0, base + LionGetMindPower(caster) * multiplier)
end

function lion_impale_custom:CreateImpaleProjectile(origin, direction, length, width, speed)
    local caster = self:GetCaster()

    ProjectileManager:CreateLinearProjectile({
        Ability = self,
        EffectName = "particles/units/heroes/hero_lion/lion_spell_impale.vpcf",
        vSpawnOrigin = origin,
        fDistance = length,
        fStartRadius = width,
        fEndRadius = width,
        Source = caster,
        bHasFrontalCone = false,
        bReplaceExisting = false,
        iUnitTargetTeam = DOTA_UNIT_TARGET_TEAM_ENEMY,
        iUnitTargetFlags = DOTA_UNIT_TARGET_FLAG_NONE,
        iUnitTargetType = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        fExpireTime = GameRules:GetGameTime() + length / speed + 0.5,
        bDeleteOnHit = false,
        vVelocity = direction * speed,
        bProvidesVision = true,
        iVisionRadius = width,
        iVisionTeamNumber = caster:GetTeamNumber(),
    })
end

function lion_impale_custom:OnSpellStart()
    local caster = self:GetCaster()
    local target = self:GetCursorTarget()
    local point = self:GetCursorPosition()
    local origin = caster:GetAbsOrigin()

    if target and not target:IsNull() then
        point = target:GetAbsOrigin()
    end

    local direction = point - origin
    direction.z = 0
    if direction:Length2D() < 1 then
        direction = caster:GetForwardVector()
    else
        direction = direction:Normalized()
    end

    local length = self:GetSpecialValueFor("length")
    local width = self:GetSpecialValueFor("width")
    local speed = self:GetSpecialValueFor("speed")
    self.impale_hit_targets = {}

    local has_shard = LionHasShard(caster)
    local spike_count = has_shard and math.max(1, self:GetSpecialValueFor("shard_spike_count")) or 1
    local cone_angle = has_shard and self:GetSpecialValueFor("shard_cone_angle") or 0

    if spike_count <= 1 or cone_angle <= 0 then
        self:CreateImpaleProjectile(origin, direction, length, width, speed)
    else
        for i = 1, spike_count do
            local t = (i - 1) / math.max(1, spike_count - 1)
            local angle_offset = -cone_angle / 2 + cone_angle * t
            self:CreateImpaleProjectile(origin, LionRotateDirection2D(direction, angle_offset), length, width, speed)
        end
    end

    Timers:CreateTimer(length / speed + 0.6, function()
        if self and not self:IsNull() then
            self.impale_hit_targets = nil
        end
        return nil
    end)

    EmitSoundOn("Hero_Lion.Impale", caster)
end

function lion_impale_custom:OnProjectileHit(target, location)
    if not target or target:IsNull() then
        return false
    end

    local caster = self:GetCaster()
    self.impale_hit_targets = self.impale_hit_targets or {}
    local target_index = target:entindex()
    if self.impale_hit_targets[target_index] then
        return false
    end
    self.impale_hit_targets[target_index] = true

    if target:TriggerSpellAbsorb(self) then
        return false
    end

    ApplyDamage({
        victim = target,
        attacker = caster,
        damage = self:GetMindScaledDamage(),
        damage_type = self:GetAbilityDamageType(),
        ability = self,
    })

    local stun_duration = self:GetSpecialValueFor("stun_duration") * (1 - target:GetStatusResistance())
    target:AddNewModifier(caster, self, "modifier_lion_impale_custom_stun", {
        duration = stun_duration,
    })
    target:AddNewModifier(caster, self, "modifier_lion_impale_knockup", {
        duration = self:GetSpecialValueFor("knockup_duration"),
        height = self:GetSpecialValueFor("knockup_height"),
    })

    return false
end

modifier_lion_impale_custom_stun = class({})

function modifier_lion_impale_custom_stun:IsHidden() return false end
function modifier_lion_impale_custom_stun:IsDebuff() return true end
function modifier_lion_impale_custom_stun:IsPurgable() return true end
function modifier_lion_impale_custom_stun:CheckState()
    return {
        [MODIFIER_STATE_STUNNED] = true,
    }
end
function modifier_lion_impale_custom_stun:GetEffectName()
    return "particles/generic_gameplay/generic_stunned.vpcf"
end
function modifier_lion_impale_custom_stun:GetEffectAttachType()
    return PATTACH_OVERHEAD_FOLLOW
end

modifier_lion_impale_knockup = class({})

function modifier_lion_impale_knockup:IsHidden() return true end
function modifier_lion_impale_knockup:IsPurgable() return false end
function modifier_lion_impale_knockup:IsDebuff() return true end
function modifier_lion_impale_knockup:GetAttributes() return MODIFIER_ATTRIBUTE_MULTIPLE end

function modifier_lion_impale_knockup:OnCreated(kv)
    if not IsServer() then
        return
    end

    self.duration = math.max(0.03, tonumber(kv.duration) or 0.45)
    self.height = math.max(0, tonumber(kv.height) or 220)
    self.elapsed = 0

    if not self:ApplyVerticalMotionController() then
        self:Destroy()
    end
end

function modifier_lion_impale_knockup:OnDestroy()
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if parent and not parent:IsNull() then
        local position = parent:GetAbsOrigin()
        position.z = GetGroundHeight(position, parent)
        parent:SetAbsOrigin(position)
        parent:RemoveVerticalMotionController(self)
    end
end

function modifier_lion_impale_knockup:UpdateVerticalMotion(parent, dt)
    if not IsServer() then
        return
    end
    if not parent or parent:IsNull() then
        self:Destroy()
        return
    end

    self.elapsed = math.min(self.duration, (self.elapsed or 0) + dt)
    local progress = self.elapsed / self.duration
    local lift = 4 * self.height * progress * (1 - progress)
    local position = parent:GetAbsOrigin()
    position.z = GetGroundHeight(position, parent) + lift
    parent:SetAbsOrigin(position)

    if self.elapsed >= self.duration then
        self:Destroy()
    end
end

function modifier_lion_impale_knockup:OnVerticalMotionInterrupted()
    if not IsServer() then
        return
    end

    self:Destroy()
end

lion_soul_collector = class({})

function lion_soul_collector:GetIntrinsicModifierName()
    return "modifier_lion_soul_collector_tracker"
end

modifier_lion_soul_collector_tracker = class({})

function modifier_lion_soul_collector_tracker:IsHidden() return true end
function modifier_lion_soul_collector_tracker:IsPurgable() return false end
function modifier_lion_soul_collector_tracker:RemoveOnDeath() return false end
function modifier_lion_soul_collector_tracker:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_DEATH,
    }
end

function modifier_lion_soul_collector_tracker:OnDeath(params)
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    local ability = self:GetAbility()
    local victim = params.unit
    local attacker = params.attacker

    if not parent or parent:IsNull() or parent:IsIllusion() then return end
    if not ability or ability:IsNull() then return end
    if not victim or victim:IsNull() or victim == parent then return end
    if not attacker or attacker:IsNull() or attacker ~= parent then return end
    if victim:GetTeamNumber() == parent:GetTeamNumber() then return end

    if victim:IsRealHero() then
        local bonus = ability:GetSpecialValueFor("hero_mind_power")
        LionAddStackedModifier(parent, ability, "modifier_lion_soul_collector_permanent", bonus)
        return
    end

    if victim:IsCreep() or victim:IsNeutralUnitType() then
        local bonus = ability:GetSpecialValueFor("creep_mind_power")
        local duration = ability:GetSpecialValueFor("creep_duration")
        local modifier = LionAddStackedModifier(parent, ability, "modifier_lion_soul_collector_temp", bonus)

        if modifier and duration > 0 then
            Timers:CreateTimer(duration, function()
                if not parent or parent:IsNull() then
                    return nil
                end

                local current = parent:FindModifierByName("modifier_lion_soul_collector_temp")
                if not current or current:IsNull() then
                    return nil
                end

                local next_stack = math.max(0, current:GetStackCount() - bonus)
                current:SetStackCount(next_stack)
                current:ForceRefresh()
                if next_stack <= 0 then
                    current:Destroy()
                end

                return nil
            end)
        end
    end
end

modifier_lion_soul_collector_temp = class({})

function modifier_lion_soul_collector_temp:IsHidden() return false end
function modifier_lion_soul_collector_temp:IsPurgable() return false end
function modifier_lion_soul_collector_temp:IsBuff() return true end
function modifier_lion_soul_collector_temp:RemoveOnDeath() return false end
function modifier_lion_soul_collector_temp:GetTexture() return "lion_soul_collector" end

modifier_lion_soul_collector_permanent = class({})

function modifier_lion_soul_collector_permanent:IsHidden() return false end
function modifier_lion_soul_collector_permanent:IsPurgable() return false end
function modifier_lion_soul_collector_permanent:IsBuff() return true end
function modifier_lion_soul_collector_permanent:RemoveOnDeath() return false end
function modifier_lion_soul_collector_permanent:IsPermanent() return true end
function modifier_lion_soul_collector_permanent:GetTexture() return "lion_soul_collector" end

lion_spirit_siphon_custom = class({})

function lion_spirit_siphon_custom:CastFilterResultTarget(target)
    if not target or target:IsNull() then
        return UF_FAIL_CUSTOM
    end
    if target and not target:IsNull() and target:GetMaxMana() <= 0 then
        return UF_FAIL_CUSTOM
    end
    return UnitFilter(
        target,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE,
        self:GetCaster():GetTeamNumber()
    )
end

function lion_spirit_siphon_custom:GetCustomCastErrorTarget(target)
    if not target or target:IsNull() then
        return ""
    end
    if target and not target:IsNull() and target:GetMaxMana() <= 0 then
        return "#dota_hud_error_target_has_no_mana"
    end
    return ""
end

function lion_spirit_siphon_custom:OnSpellStart()
    local caster = self:GetCaster()
    local target = self:GetCursorTarget()
    if not target or target:IsNull() then
        return
    end

    if target:TriggerSpellAbsorb(self) then
        return
    end

    target:AddNewModifier(caster, self, "modifier_lion_spirit_siphon_custom", {
        duration = self:GetSpecialValueFor("duration"),
    })

    EmitSoundOn("Hero_DeathProphet.SpiritSiphon.Cast", caster)
    EmitSoundOn("Hero_DeathProphet.SpiritSiphon.Target", target)
end

modifier_lion_spirit_siphon_custom = class({})

function modifier_lion_spirit_siphon_custom:IsHidden() return false end
function modifier_lion_spirit_siphon_custom:IsDebuff() return true end
function modifier_lion_spirit_siphon_custom:IsPurgable() return true end
function modifier_lion_spirit_siphon_custom:GetTexture() return "lion_mana_drain" end

function modifier_lion_spirit_siphon_custom:OnCreated()
    local ability = self:GetAbility()
    self.tick_interval = ability:GetSpecialValueFor("tick_interval")
    self.break_distance = ability:GetSpecialValueFor("break_distance")
    self.health_drain_pct = ability:GetSpecialValueFor("health_drain_pct") / 100

    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    local caster = self:GetCaster()
    if not parent or parent:IsNull() or not caster or caster:IsNull() then
        self:Destroy()
        return
    end

    self.particle = LionCreateSiphonParticle(caster, parent)
    if self.particle then
        self:AddParticle(self.particle, false, false, -1, false, false)
    end

    self:StartIntervalThink(self.tick_interval)
end

function modifier_lion_spirit_siphon_custom:OnRefresh()
    local ability = self:GetAbility()
    self.tick_interval = ability:GetSpecialValueFor("tick_interval")
    self.break_distance = ability:GetSpecialValueFor("break_distance")
    self.health_drain_pct = ability:GetSpecialValueFor("health_drain_pct") / 100
end

function modifier_lion_spirit_siphon_custom:OnDestroy()
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if parent and not parent:IsNull() then
        StopSoundOn("Hero_DeathProphet.SpiritSiphon.Target", parent)
    end
end

function modifier_lion_spirit_siphon_custom:OnIntervalThink()
    local parent = self:GetParent()
    local caster = self:GetCaster()
    local ability = self:GetAbility()

    if not parent or parent:IsNull() or not caster or caster:IsNull() or not ability or ability:IsNull() then
        self:Destroy()
        return
    end
    if not caster:IsAlive() or not parent:IsAlive() then
        self:Destroy()
        return
    end
    if (caster:GetAbsOrigin() - parent:GetAbsOrigin()):Length2D() > self.break_distance then
        self:Destroy()
        return
    end

    local mana_per_second = ability:GetSpecialValueFor("mana_drain_per_second")
        + LionGetMindPower(caster) * ability:GetSpecialValueFor("mind_power_multiplier")
    local mana_to_drain = math.max(0, mana_per_second * self.tick_interval)
    local mana_before = parent:GetMana()

    if parent.Script_ReduceMana then
        parent:Script_ReduceMana(mana_to_drain, ability)
    elseif parent.ReduceMana then
        parent:ReduceMana(mana_to_drain)
    end

    local mana_drained = math.max(0, mana_before - parent:GetMana())
    if mana_drained <= 0 then
        return
    end

    caster:GiveMana(mana_drained)

    local health_damage = mana_drained * self.health_drain_pct
    ApplyDamage({
        victim = parent,
        attacker = caster,
        damage = health_damage,
        damage_type = ability:GetAbilityDamageType(),
        ability = ability,
    })
    caster:Heal(health_damage, ability)

    SendOverheadEventMessage(nil, OVERHEAD_ALERT_MANA_LOSS, parent, math.floor(mana_drained), nil)
    SendOverheadEventMessage(nil, OVERHEAD_ALERT_HEAL, caster, math.floor(health_damage), nil)
end

lion_finger_of_death_custom = class({})

function lion_finger_of_death_custom:GetMindScaledDamage()
    local caster = self:GetCaster()
    local base = self:GetSpecialValueFor("damage")
    local multiplier = self:GetSpecialValueFor("mind_power_multiplier")
    return math.max(0, base + LionGetMindPower(caster) * multiplier)
end

function lion_finger_of_death_custom:OnSpellStart()
    local caster = self:GetCaster()
    local target = self:GetCursorTarget()
    if not target or target:IsNull() then
        return
    end

    if target:TriggerSpellAbsorb(self) then
        return
    end

    target:AddNewModifier(caster, self, "modifier_lion_finger_kill_marker", { duration = 3 })

    ApplyDamage({
        victim = target,
        attacker = caster,
        damage = self:GetMindScaledDamage(),
        damage_type = self:GetAbilityDamageType(),
        ability = self,
    })

    if LionHasScepter(caster) then
        caster:AddNewModifier(caster, self, "modifier_lion_finger_scepter_claw", {
            duration = self:GetSpecialValueFor("scepter_buff_duration"),
        })
    end

    local particle = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_lion/lion_spell_finger_of_death.vpcf",
        PATTACH_ABSORIGIN_FOLLOW,
        caster
    )
    ParticleManager:SetParticleControlEnt(particle, 0, caster, PATTACH_POINT_FOLLOW, "attach_attack1", caster:GetAbsOrigin(), true)
    ParticleManager:SetParticleControlEnt(particle, 1, target, PATTACH_POINT_FOLLOW, "attach_hitloc", target:GetAbsOrigin(), true)
    ParticleManager:ReleaseParticleIndex(particle)

    EmitSoundOn("Hero_Lion.FingerOfDeath", target)
end

modifier_lion_finger_scepter_claw = class({})

function modifier_lion_finger_scepter_claw:IsHidden() return false end
function modifier_lion_finger_scepter_claw:IsPurgable() return false end
function modifier_lion_finger_scepter_claw:IsBuff() return true end
function modifier_lion_finger_scepter_claw:RemoveOnDeath() return true end
function modifier_lion_finger_scepter_claw:GetTexture() return "lion_finger_of_death" end

function modifier_lion_finger_scepter_claw:OnCreated()
    local parent = self:GetParent()
    local ability = self:GetAbility()

    self.attack_range = ability and not ability:IsNull() and ability:GetSpecialValueFor("scepter_attack_range") or 250
    self.cleave_damage_pct = ability and not ability:IsNull() and ability:GetSpecialValueFor("scepter_cleave_damage_pct") or 50
    self.cleave_start_width = ability and not ability:IsNull() and ability:GetSpecialValueFor("scepter_cleave_start_width") or 150
    self.cleave_end_width = ability and not ability:IsNull() and ability:GetSpecialValueFor("scepter_cleave_end_width") or 360
    self.cleave_distance = ability and not ability:IsNull() and ability:GetSpecialValueFor("scepter_cleave_distance") or 650

    if IsServer() and parent and not parent:IsNull() then
        self.original_attack_range = self.original_attack_range or parent:Script_GetAttackRange()
        self.original_attack_capability = self.original_attack_capability or parent:GetAttackCapability()
        parent:SetAttackCapability(DOTA_UNIT_CAP_MELEE_ATTACK)
        self:StartIntervalThink(0.5)
    end
end

function modifier_lion_finger_scepter_claw:OnRefresh()
    self:OnCreated()
end

function modifier_lion_finger_scepter_claw:OnDestroy()
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if parent and not parent:IsNull() and self.original_attack_capability then
        parent:SetAttackCapability(self.original_attack_capability)
    end
end

function modifier_lion_finger_scepter_claw:OnIntervalThink()
    local parent = self:GetParent()
    if not LionHasScepter(parent) then
        self:Destroy()
    end
end

function modifier_lion_finger_scepter_claw:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_ATTACK_RANGE_BONUS,
        MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
        MODIFIER_EVENT_ON_ATTACK_START,
        MODIFIER_EVENT_ON_ATTACK_LANDED,
    }
end

function modifier_lion_finger_scepter_claw:GetModifierAttackRangeBonus()
    return self.attack_range - (self.original_attack_range or self.attack_range)
end

function modifier_lion_finger_scepter_claw:GetModifierPreAttack_BonusDamage()
    return LionGetMindPower(self:GetParent())
end

function modifier_lion_finger_scepter_claw:OnAttackStart(params)
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if params.attacker ~= parent then
        return
    end

    parent:FadeGesture(ACT_DOTA_ATTACK)
    if ACT_DOTA_ATTACK_EVENT then
        parent:FadeGesture(ACT_DOTA_ATTACK_EVENT)
    end
    parent:StartGesture(ACT_DOTA_ATTACK2 or ACT_DOTA_ATTACK)
end

function modifier_lion_finger_scepter_claw:OnAttackLanded(params)
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    local ability = self:GetAbility()
    if params.attacker ~= parent or not params.target or params.target:IsNull() then
        return
    end
    if not ability or ability:IsNull() or not LionHasScepter(parent) then
        return
    end

    DoCleaveAttack(
        parent,
        params.target,
        ability,
        params.damage * (self.cleave_damage_pct or 0) / 100,
        self.cleave_start_width or 150,
        self.cleave_end_width or 360,
        self.cleave_distance or 650,
        "particles/items_fx/battlefury_cleave.vpcf"
    )
end

function lion_finger_of_death_custom:AddRebirthStack()
    local caster = self:GetCaster()
    LionAddStackedModifier(caster, self, "modifier_lion_finger_rebirth", 1)
end

modifier_lion_finger_kill_marker = class({})

function modifier_lion_finger_kill_marker:IsHidden() return true end
function modifier_lion_finger_kill_marker:IsPurgable() return false end
function modifier_lion_finger_kill_marker:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_DEATH,
    }
end

function modifier_lion_finger_kill_marker:OnDeath(params)
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    local caster = self:GetCaster()
    local ability = self:GetAbility()

    if not parent or parent:IsNull() or params.unit ~= parent then return end
    if not parent:IsRealHero() then return end
    if not caster or caster:IsNull() or params.attacker ~= caster then return end
    if params.inflictor ~= ability then return end

    if ability and not ability:IsNull() and ability.AddRebirthStack then
        ability:AddRebirthStack()
    end
end

modifier_lion_finger_rebirth = class({})

function modifier_lion_finger_rebirth:IsHidden() return false end
function modifier_lion_finger_rebirth:IsPurgable() return false end
function modifier_lion_finger_rebirth:IsBuff() return true end
function modifier_lion_finger_rebirth:RemoveOnDeath() return false end
function modifier_lion_finger_rebirth:IsPermanent() return true end
function modifier_lion_finger_rebirth:GetTexture() return "lion_finger_of_death" end
function modifier_lion_finger_rebirth:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_DEATH,
    }
end

function modifier_lion_finger_rebirth:OnDeath(params)
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if not parent or parent:IsNull() or params.unit ~= parent then
        return
    end

    local ability = self:GetAbility()
    local reduction = ability and not ability:IsNull() and ability:GetSpecialValueFor("respawn_reduction_pct") or 5
    local multiplier = math.max(0, 1 - self:GetStackCount() * reduction / 100)

    Timers:CreateTimer(0.03, function()
        if parent and not parent:IsNull() and parent.GetTimeUntilRespawn and parent.SetTimeUntilRespawn then
            local remaining = parent:GetTimeUntilRespawn()
            if remaining and remaining > 0 then
                parent:SetTimeUntilRespawn(remaining * multiplier)
            end
        end
        return nil
    end)
end

MIND_POWER_MODIFIER_REGISTRY = MIND_POWER_MODIFIER_REGISTRY or {}
MIND_POWER_MODIFIER_REGISTRY["modifier_lion_soul_collector_temp"] = function(modifier)
    return modifier:GetStackCount()
end
MIND_POWER_MODIFIER_REGISTRY["modifier_lion_soul_collector_permanent"] = function(modifier)
    return modifier:GetStackCount()
end
