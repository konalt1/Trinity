LinkLuaModifier("modifier_doom_ultimate_aura", "DOOM/doom_ultimate_aura.lua", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_doom_ultimate_aura_debuff", "DOOM/doom_ultimate_aura.lua", LUA_MODIFIER_MOTION_NONE)

-- Основная способность

doom_ultimate_aura = class({})

function doom_ultimate_aura:OnSpellStart()
    local caster = self:GetCaster()
    local duration = self:GetSpecialValueFor("duration")
    caster:AddNewModifier(caster, self, "modifier_doom_ultimate_aura", {duration = duration})
    caster:EmitSound("Hero_DoomBringer.Doom")
    
    -- Ограничиваем длительность звука временем действия способности
    Timers:CreateTimer(duration, function()
        if caster and IsValidEntity(caster) then
            caster:StopSound("Hero_DoomBringer.Doom")
        end
    end)
end

-- Модификатор ауры на Думе
modifier_doom_ultimate_aura = class({})

function modifier_doom_ultimate_aura:IsAura() return true end
function modifier_doom_ultimate_aura:IsPurgable() return false end
function modifier_doom_ultimate_aura:IsBuff() return true end
function modifier_doom_ultimate_aura:GetAuraRadius() 
    return self:GetAbility():GetSpecialValueFor("aura_radius") 
end
function modifier_doom_ultimate_aura:GetAuraSearchTeam() return DOTA_UNIT_TARGET_TEAM_ENEMY end
function modifier_doom_ultimate_aura:GetAuraSearchType() return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC end
function modifier_doom_ultimate_aura:GetModifierAura() return "modifier_doom_ultimate_aura_debuff" end
function modifier_doom_ultimate_aura:GetEffectName() 
    return "particles/units/heroes/hero_doom_bringer/doom_bringer_doom_aura.vpcf" 
end
function modifier_doom_ultimate_aura:GetEffectAttachType() 
    return PATTACH_ABSORIGIN_FOLLOW 
end

function modifier_doom_ultimate_aura:OnCreated()
    if not IsServer() then return end
    self:GetParent():EmitSound("Hero_DoomBringer.ScorchedEarth")
end

function modifier_doom_ultimate_aura:OnDestroy()
    if not IsServer() then return end
    local parent = self:GetParent()
    if parent then
        parent:StopSound("Hero_DoomBringer.ScorchedEarth")
    end
end

-- Модификатор дебаффа на врагах
modifier_doom_ultimate_aura_debuff = class({})

function modifier_doom_ultimate_aura_debuff:IsPurgable() return false end
function modifier_doom_ultimate_aura_debuff:IsDebuff() return true end

function modifier_doom_ultimate_aura_debuff:OnCreated()
    if not IsServer() then return end
    self:StartIntervalThink(1.0)
end

function modifier_doom_ultimate_aura_debuff:OnIntervalThink()
    if not IsServer() then return end
    local parent = self:GetParent()
    local caster = self:GetCaster()
    local ability = self:GetAbility()
    
    if parent and caster and ability then
        -- Пересчитываем урон каждый тик для учета изменений mind power
        local base_damage = ability:GetSpecialValueFor("damage_per_second")
        local mind_power_multiplier = ability:GetSpecialValueFor("mind_power_multiplier")
        local mind_power = GetHeroMindPower(caster)
        local current_damage = base_damage + (mind_power * mind_power_multiplier)
        
        local damageTable = {
            victim = parent,
            attacker = caster,
            damage = current_damage,
            damage_type = DAMAGE_TYPE_PURE,
            ability = ability,
        }
        ApplyDamage(damageTable)
    end
end

function modifier_doom_ultimate_aura_debuff:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
        MODIFIER_PROPERTY_HEALTH_REGEN_PERCENTAGE,
        MODIFIER_PROPERTY_HP_REGEN_AMPLIFY_PERCENTAGE,
    }
end

function modifier_doom_ultimate_aura_debuff:GetModifierConstantHealthRegen()
    return -10000
end

function modifier_doom_ultimate_aura_debuff:GetModifierHealthRegenPercentage()
    return -100
end

function modifier_doom_ultimate_aura_debuff:GetModifierHPRegenAmplify_Percentage()
    return -100
end

function modifier_doom_ultimate_aura_debuff:CheckState()
    return {
        [MODIFIER_STATE_SILENCED] = true,
        [MODIFIER_STATE_PASSIVES_DISABLED] = true,
        [MODIFIER_STATE_CANNOT_BE_HEALED] = true,
    }
end

function modifier_doom_ultimate_aura_debuff:GetStatusEffectName()
    return "particles/status_fx/status_effect_doom.vpcf"
end

function modifier_doom_ultimate_aura_debuff:StatusEffectPriority()
    return 10
end

function modifier_doom_ultimate_aura_debuff:GetTexture()
    return "doom_bringer_doom"
end 