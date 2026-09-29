-- Trinity: Spider Legs — развитие Phase Boots (рецепт пока не задан, в магазине не продаётся).
--   * Пассив: статы Phase Boots (скорость бега сапог, урон ближнего/дальнего боя, броня).
--   * Активация «Паучий бег»: фаза (проход сквозь юнитов) + беспрепятственное перемещение
--     (деревья и обрывы не мешают) + рубка деревьев на пути + бонус скорости.
--     По окончании герой выталкивается в свободную точку.
-- Значения берутся из KV (npc_items_custom.txt, "item_spider_legs").

LinkLuaModifier("modifier_item_spider_legs_trinity", "items/item_spider_legs_trinity", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_spider_legs_trinity_active", "items/item_spider_legs_trinity", LUA_MODIFIER_MOTION_NONE)

local PARTICLE_ACTIVE = "particles/items5_fx/spider_legs_buff.vpcf"
local PARTICLE_PHASE  = "particles/items2_fx/phase_boots.vpcf"

item_spider_legs = class({})

function item_spider_legs:Precache(context)
    PrecacheResource("particle", PARTICLE_ACTIVE, context)
    PrecacheResource("particle", PARTICLE_PHASE, context)
end

function item_spider_legs:GetIntrinsicModifierName()
    return "modifier_item_spider_legs_trinity"
end

function item_spider_legs:OnSpellStart()
    local caster = self:GetCaster()
    caster:AddNewModifier(caster, self, "modifier_item_spider_legs_trinity_active", {
        duration = self:GetSpecialValueFor("duration"),
    })
    EmitSoundOn("DOTA_Item.PhaseBoots.Activate", caster)
    EmitSoundOn("DOTA_Item.SpiderLegs.Cast", caster)
end

-- ============================================================
-- Пассив: статы Phase Boots
-- ============================================================
modifier_item_spider_legs_trinity = class({
    IsHidden      = function(self) return true end,
    IsPurgable    = function(self) return false end,
    RemoveOnDeath = function(self) return false end,
    GetAttributes = function(self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
})

function modifier_item_spider_legs_trinity:OnCreated()
    local ability = self:GetAbility()
    if not ability then return end
    self.move_speed = ability:GetSpecialValueFor("bonus_movement_speed")
    self.damage_melee = ability:GetSpecialValueFor("bonus_damage_melee")
    self.damage_range = ability:GetSpecialValueFor("bonus_damage_range")
    self.armor = ability:GetSpecialValueFor("bonus_armor")
end

function modifier_item_spider_legs_trinity:OnRefresh()
    self:OnCreated()
end

function modifier_item_spider_legs_trinity:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_MOVESPEED_BONUS_UNIQUE,
        MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
    }
end

function modifier_item_spider_legs_trinity:GetModifierMoveSpeedBonus_Special_Boots()
    return self.move_speed
end

function modifier_item_spider_legs_trinity:GetModifierPreAttack_BonusDamage()
    return self:GetParent():IsRangedAttacker() and self.damage_range or self.damage_melee
end

function modifier_item_spider_legs_trinity:GetModifierPhysicalArmorBonus()
    return self.armor
end

-- ============================================================
-- Активация «Паучий бег»
-- ============================================================
modifier_item_spider_legs_trinity_active = class({
    IsHidden   = function(self) return false end,
    IsDebuff   = function(self) return false end,
    IsPurgable = function(self) return true end,
    GetTexture = function(self) return "item_spider_legs" end,
})

function modifier_item_spider_legs_trinity_active:OnCreated()
    local ability = self:GetAbility()
    local parent = self:GetParent()
    self.move_speed = 0
    self.tree_radius = 150
    if ability then
        self.move_speed = parent:IsRangedAttacker()
            and ability:GetSpecialValueFor("bonus_movement_speed_active_ranged")
            or ability:GetSpecialValueFor("bonus_movement_speed_active")
        self.tree_radius = ability:GetSpecialValueFor("tree_radius")
    end
    if not IsServer() then return end

    local fx = ParticleManager:CreateParticle(PARTICLE_ACTIVE, PATTACH_CUSTOMORIGIN, parent)
    ParticleManager:SetParticleControlEnt(fx, 0, parent, PATTACH_POINT_FOLLOW, nil, parent:GetAbsOrigin(), true)
    ParticleManager:SetParticleControlEnt(fx, 1, parent, PATTACH_POINT_FOLLOW, nil, parent:GetAbsOrigin(), true)
    self:AddParticle(fx, false, false, -1, false, false)

    local phase = ParticleManager:CreateParticle(PARTICLE_PHASE, PATTACH_ABSORIGIN_FOLLOW, parent)
    self:AddParticle(phase, false, false, -1, false, false)

    self:OnIntervalThink()
    self:StartIntervalThink(0.1)
end

function modifier_item_spider_legs_trinity_active:OnRefresh()
    self:OnCreated()
end

function modifier_item_spider_legs_trinity_active:OnIntervalThink()
    local parent = self:GetParent()
    GridNav:DestroyTreesAroundPoint(parent:GetAbsOrigin(), self.tree_radius, true)
end

function modifier_item_spider_legs_trinity_active:OnDestroy()
    if not IsServer() then return end
    local parent = self:GetParent()
    if not parent or parent:IsNull() or not parent:IsAlive() then return end
    GridNav:DestroyTreesAroundPoint(parent:GetAbsOrigin(), self.tree_radius, true)
    FindClearSpaceForUnit(parent, parent:GetAbsOrigin(), true)
end

function modifier_item_spider_legs_trinity_active:CheckState()
    return {
        [MODIFIER_STATE_NO_UNIT_COLLISION] = true,
        [MODIFIER_STATE_FLYING_FOR_PATHING_PURPOSES_ONLY] = true,
    }
end

function modifier_item_spider_legs_trinity_active:DeclareFunctions()
    return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE }
end

function modifier_item_spider_legs_trinity_active:GetModifierMoveSpeedBonus_Percentage()
    return self.move_speed
end
