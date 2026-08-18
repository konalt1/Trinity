LinkLuaModifier(
    "modifier_tinker_laser_custom_blind",
    "abilities/tinker/tinker_laser_custom",
    LUA_MODIFIER_MOTION_NONE
)

tinker_laser_custom = class({})

local function IsValidUnit(unit)
    return unit and not unit:IsNull()
end

local function GetAttachmentOrigin(unit, attachment_name)
    if IsValidUnit(unit) and unit.ScriptLookupAttachment and unit.GetAttachmentOrigin then
        local attachment = unit:ScriptLookupAttachment(attachment_name)
        if attachment and attachment > 0 then
            return unit:GetAttachmentOrigin(attachment)
        end
    end

    return unit:GetAbsOrigin()
end

function tinker_laser_custom:Precache(context)
    PrecacheResource("particle", "particles/units/heroes/hero_tinker/tinker_laser.vpcf", context)
    PrecacheResource("particle", "particles/status_fx/status_effect_tinker_laser.vpcf", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_tinker.vsndevts", context)
end

function tinker_laser_custom:GetMindScaledDamage()
    local caster = self:GetCaster()
    local base = self:GetSpecialValueFor("laser_damage")
    local multiplier = self:GetSpecialValueFor("mind_power_multiplier")
    local mind_power = GetHeroMindPower and (GetHeroMindPower(caster) or 0) or 0
    return math.max(0, base + mind_power * multiplier)
end

function tinker_laser_custom:OnSpellStart()
    if not IsServer() then
        return
    end

    local caster = self:GetCaster()
    local target = self:GetCursorTarget()
    if not IsValidUnit(target) then
        return
    end

    local start_origin = GetAttachmentOrigin(caster, "attach_attack2")
    if start_origin == caster:GetAbsOrigin() then
        start_origin = GetAttachmentOrigin(caster, "attach_attack1")
    end
    local end_origin = GetAttachmentOrigin(target, "attach_hitloc")

    local particle = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_tinker/tinker_laser.vpcf",
        PATTACH_WORLDORIGIN,
        caster
    )
    ParticleManager:SetParticleControl(particle, 0, start_origin)
    ParticleManager:SetParticleControl(particle, 1, end_origin)
    ParticleManager:SetParticleControl(particle, 3, start_origin)
    ParticleManager:SetParticleControl(particle, 9, start_origin)
    ParticleManager:ReleaseParticleIndex(particle)

    caster:EmitSound("Hero_Tinker.Laser")
    target:EmitSound("Hero_Tinker.LaserImpact")

    if target:TriggerSpellAbsorb(self) then
        return
    end

    target:AddNewModifier(caster, self, "modifier_tinker_laser_custom_blind", {
        duration = self:GetSpecialValueFor("blind_duration") * (1 - target:GetStatusResistance()),
    })

    ApplyDamage({
        attacker = caster,
        victim = target,
        damage = self:GetMindScaledDamage(),
        damage_type = self:GetAbilityDamageType(),
        ability = self,
    })
end

modifier_tinker_laser_custom_blind = class({})

function modifier_tinker_laser_custom_blind:IsHidden()
    return false
end

function modifier_tinker_laser_custom_blind:IsDebuff()
    return true
end

function modifier_tinker_laser_custom_blind:IsPurgable()
    return true
end

function modifier_tinker_laser_custom_blind:OnCreated()
    local ability = self:GetAbility()
    self.miss_rate = ability and ability:GetSpecialValueFor("miss_rate") or 100
end

function modifier_tinker_laser_custom_blind:OnRefresh()
    self:OnCreated()
end

function modifier_tinker_laser_custom_blind:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_MISS_PERCENTAGE,
    }
end

function modifier_tinker_laser_custom_blind:GetModifierMiss_Percentage()
    return self.miss_rate
end

function modifier_tinker_laser_custom_blind:GetStatusEffectName()
    return "particles/status_fx/status_effect_tinker_laser.vpcf"
end

function modifier_tinker_laser_custom_blind:StatusEffectPriority()
    return MODIFIER_PRIORITY_NORMAL
end

function modifier_tinker_laser_custom_blind:GetTexture()
    return "tinker_laser"
end
