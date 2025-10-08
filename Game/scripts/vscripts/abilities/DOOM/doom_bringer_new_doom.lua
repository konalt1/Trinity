-- LinkLuaModifier
LinkLuaModifier("new_doom_aura", "abilities/new_doom", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("new_doom_aura_modifier", "abilities/new_doom", LUA_MODIFIER_MOTION_NONE)

-- new_doom
new_doom = class({})

function new_doom:OnSpellStart()
    local caster = self:GetCaster() 
    caster:AddNewModifier(caster, self, "new_doom_aura", {duration = self:GetSpecialValueFor("duration")})
end

-- new_doom_aura
new_doom_aura = class({})

function new_doom_aura:GetAuraSearchTeam()
    return DOTA_UNIT_TARGET_TEAM_ENEMY -- на кого действует (какая тима)
end

function new_doom_aura:GetAuraSearchType()
    return DOTA_UNIT_TARGET_BASIC + DOTA_UNIT_TARGET_HERO -- на кого действует (какой юнит)
end

function new_doom_aura:GetEffectName()
    return "particles/units/heroes/hero_doom_bringer/doom_bringer_doom_ring.vpcf"   -- эфект как заглушка
end
function new_doom_aura:IsHidden()
    return false
end

function new_doom_aura:GetAuraDuration()
    return 0.1
end

function new_doom_aura:IsAura()
    return true
end

function new_doom_aura:IsDebuff()
    return false
end

function new_doom_aura:IsPurgable()
    return false
end

function new_doom_aura:GetAuraRadius()
    return self:GetAbility():GetSpecialValueFor("radius")
end

function new_doom_aura:GetModifierAura()
    return "new_doom_aura_modifier"
end

function new_doom_aura:GetAuraSearchFlags()
    return DOTA_UNIT_TARGET_FLAG_INVULNERABLE
end

-- new_doom_aura_modifier
new_doom_aura_modifier = class({})

function new_doom_aura_modifier:IsHidden()
    return true
end

function new_doom_aura_modifier:OnCreated()
    self:StartIntervalThink(1)
end

function new_doom_aura_modifier:OnIntervalThink()
    ApplyDamage({ -- нанесение урона
        victim = self:GetParent(),
        attacker = self:GetCaster(), 
        damage = self:GetAbility():GetSpecialValueFor("damage"),
        damage_type = DAMAGE_TYPE_PURE, 
        ability = self:GetAbility()
    })
end

function new_doom_aura_modifier:CheckState()
    return {
        [MODIFIER_STATE_MUTED] = true, -- дебафы (мут и сайленс)
        [MODIFIER_STATE_SILENCED] = true
    }
end

function new_doom_aura_modifier:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_DISABLE_HEALING -- минус реген
    }
end

function new_doom_aura_modifier:GetDisableHealing()
    return 1
end

