LinkLuaModifier('modifier_ability_ice_phylactery', 'lich/ability_ice_phylactery', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_ability_ice_phylactery_buff', 'lich/ability_ice_phylactery', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_spell_lifesteal_custom', 'lich/ability_ice_phylactery', LUA_MODIFIER_MOTION_NONE)
  
ability_ice_phylactery = ability_ice_phylactery or class({})

function ability_ice_phylactery:OnSpellStart(event)
    CreateUnitByNameAsync(
        "npc_dota_lich_ice_spire",
        self:GetCursorPosition(),
        true,
        self:GetCaster(),
        self:GetCaster(),
        self:GetCaster():GetTeam(),
        function (unit)
            self:OnIceSpireCreated(unit)
        end
    )
end

function ability_ice_phylactery:OnIceSpireCreated(unit)
    unit:EmitSound("Hero_Lich.IceSpire")
    unit:AddNewModifier(unit, self, "modifier_kill", {duration = self:GetSpecialValueFor("duration")})
    unit:AddNewModifier(unit, self, "modifier_ability_ice_phylactery", {duration = self:GetSpecialValueFor("duration")})
end


modifier_ability_ice_phylactery = class({
    IsHidden                = function(self) return true end,
    IsPurgable              = function(self) return false end,
    IsPurgeException        = function(self) return false end,
    IsDebuff                = function(self) return false end,
    RemoveOnDeath                = function(self) return true end,
    IsAura                  = function(self) return true end,
    GetModifierAura         = function(self) return "modifier_ability_ice_phylactery_buff" end,
    GetAuraSearchTeam       = function(self) return DOTA_UNIT_TARGET_TEAM_BOTH end,
    GetAuraRadius           = function(self) return self:GetAbility():GetSpecialValueFor("aura_radius") end,
    GetAuraDuration         = function(self) return self:GetAbility():GetSpecialValueFor("slow_duration") end,
    GetAuraSearchType       = function(self) return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC end,
    DeclareFunctions        = function(self)
        return {
            MODIFIER_PROPERTY_HEALTHBAR_PIPS,
            MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_MAGICAL,
            MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PHYSICAL,
            MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PURE,
            MODIFIER_EVENT_ON_ATTACKED
        }
    end,
    GetAbsoluteNoDamageMagical  = function(self) return 1 end,
    GetAbsoluteNoDamagePhysical  = function(self) return 1 end,
    GetAbsoluteNoDamagePure  = function(self) return 1 end,
})

function modifier_ability_ice_phylactery:OnCreated()
    local ability = self:GetAbility()
    local parent = self:GetParent()
    local radius = ability:GetSpecialValueFor("aura_radius")
    local origin = parent:GetAbsOrigin()

    self.effect_cast = ParticleManager:CreateParticle( "particles/units/heroes/hero_lich/lich_ice_spire.vpcf", PATTACH_ABSORIGIN_FOLLOW, parent )
    ParticleManager:SetParticleControl(self.effect_cast, 0, origin)
    ParticleManager:SetParticleControl(self.effect_cast, 1, origin)
    ParticleManager:SetParticleControl(self.effect_cast, 2, origin)
    ParticleManager:SetParticleControl(self.effect_cast, 3, Vector(origin.x, origin.y, origin.z + 10))
    ParticleManager:SetParticleControl(self.effect_cast, 4, parent:GetAbsOrigin())
    ParticleManager:SetParticleControl(self.effect_cast, 5, Vector(radius,radius,radius))  

    self.Pips = ability:GetSpecialValueFor("max_hero_attacks")

    self.AttacksToDestroy = ability:GetSpecialValueFor("max_creep_attacks")

    if IsServer() then 
        parent:SetMaxHealth(self.AttacksToDestroy)
    end
    
    self.HeroesAttacksMult = 2
    self.HealthPerPips = self:GetParent():GetMaxHealth() / self.AttacksToDestroy
end

function modifier_ability_ice_phylactery:OnDestroy()
    if IsServer() then 
        self:GetParent():EmitSound("Hero_Lich.IceSpire.Destroy")
    end
    ParticleManager:DestroyParticle(self.effect_cast, false)
    ParticleManager:ReleaseParticleIndex(self.effect_cast)
end
 
function modifier_ability_ice_phylactery:OnAttacked(keys)
    if not IsServer() then return end
    local target = keys.target
    local attacker = keys.attacker
    local parent = self:GetParent()
    if target and attacker and target == parent then
        local HealthsDiff = math.floor(parent:GetHealth() - (self.HealthPerPips * (attacker:IsRealHero() and self.HeroesAttacksMult or 1)))
        print(HealthsDiff,  self.HealthPerPips, self.HealthPerPips * (attacker:IsRealHero() and self.HeroesAttacksMult or 1))
        if HealthsDiff <= 0 then
            parent:Kill(nil, attacker)
            self:Destroy()
        else 
            parent:SetHealth(HealthsDiff)
        end
    end
end

function modifier_ability_ice_phylactery:GetModifierHealthBarPips()
    return self.Pips or 0
end

modifier_ability_ice_phylactery_buff = class({
    IsHidden                 = function(self) return false end,
    IsPurgable                 = function(self) return false end,
    RemoveOnDeath             = function(self) return true end,
    DeclareFunctions        = function(self) return 
    {
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
        MODIFIER_PROPERTY_COOLDOWN_PERCENTAGE,
        MODIFIER_PROPERTY_SPELL_LIFESTEAL_AMPLIFY_PERCENTAGE,
    } end,
})

function modifier_ability_ice_phylactery_buff:OnCreated()
    local caster = self:GetCaster()
    local parent = self:GetParent()

    self.isBuff = parent:GetTeamNumber() == caster:GetTeamNumber()

    if IsClient() then return end
    if self.isBuff then 
        self.modifier = parent:AddNewModifier(caster, self:GetAbility(), "modifier_spell_lifesteal_custom", {})
    end
end

function modifier_ability_ice_phylactery_buff:OnDestroy()
    if IsClient() then return end

    if self.modifier then 
        self.modifier:Destroy()
    end
end

function modifier_ability_ice_phylactery_buff:isBuff()
    return self.isBuff
end


function modifier_ability_ice_phylactery_buff:GetModifierMoveSpeedBonus_Percentage()
    if not self.isBuff then 
        return self:GetAbility():GetSpecialValueFor("bonus_movespeed")
    end
end

function modifier_ability_ice_phylactery_buff:GetModifierPercentageCooldown()
    if self.isBuff then 
        return self:GetAbility():GetSpecialValueFor("cooldown_reduction")
    end
end
function modifier_ability_ice_phylactery_buff:GetModifierPercentageCooldown()
    if self.isBuff then 
        return self:GetAbility():GetSpecialValueFor("cooldown_reduction")
    end
end

function modifier_ability_ice_phylactery_buff:GetModifierSpellLifestealRegenAmplify_Percentage()
    if self.isBuff then 
        return self:GetAbility():GetSpecialValueFor("spell_lifesteal")
    end
end

modifier_spell_lifesteal_custom = class({
    IsHidden                 = function(self) return true end,
    IsPurgable                 = function(self) return false end,
    IsBuff                  = function(self) return true end,
    RemoveOnDeath             = function(self) return false end,
    DeclareFunctions        = function(self) return 
    {
        MODIFIER_EVENT_ON_TAKEDAMAGE,
    } end,
})

function modifier_spell_lifesteal_custom:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_HEALTH_BONUS,
        MODIFIER_PROPERTY_MANA_BONUS,
        MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,

        MODIFIER_EVENT_ON_TAKEDAMAGE
    }
end
 
 function modifier_spell_lifesteal_custom:OnTakeDamage( keys )
    if keys.attacker == self:GetParent() and not keys.unit:IsBuilding() and not keys.unit:IsOther() then        
        if keys.damage_category == DOTA_DAMAGE_CATEGORY_SPELL and keys.inflictor and bit.band(keys.damage_flags, DOTA_DAMAGE_FLAG_NO_SPELL_LIFESTEAL) ~= DOTA_DAMAGE_FLAG_NO_SPELL_LIFESTEAL then
            self.lifesteal_pfx = ParticleManager:CreateParticle("particles/items3_fx/octarine_core_lifesteal.vpcf", PATTACH_ABSORIGIN_FOLLOW, keys.attacker)
            ParticleManager:SetParticleControl(self.lifesteal_pfx, 0, keys.attacker:GetAbsOrigin())
            ParticleManager:ReleaseParticleIndex(self.lifesteal_pfx)
   
            if keys.unit:IsIllusion() then
                if keys.damage_type == DAMAGE_TYPE_PHYSICAL and keys.unit.GetPhysicalArmorValue and GetReductionFromArmor then
                    keys.damage = keys.original_damage * (1 - GetReductionFromArmor(keys.unit:GetPhysicalArmorValue(false)))
                elseif keys.damage_type == DAMAGE_TYPE_MAGICAL and keys.unit.GetMagicalArmorValue then
                    keys.damage = keys.original_damage * (1 - GetReductionFromArmor(keys.unit:GetMagicalArmorValue()))
                elseif keys.damage_type == DAMAGE_TYPE_PURE then
                    keys.damage = keys.original_damage
                end
            end

            keys.attacker:Heal(math.max(keys.damage, 0) * (self:GetAbility():GetSpecialValueFor("spell_lifesteal") ) * 0.01, keys.attacker)
        end
    end
end