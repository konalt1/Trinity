-- Trinity: Iron Talon (Lua-версия выведенного из игры ванильного предмета).
--   * Пассив: броня.
--   * Активка: по вражескому крипу (не древнему) — урон creep_damage_pct% от его текущего здоровья.
--     Деревья не рубит, героев и зданий не бьёт.
-- Значения берутся из KV (npc_items_custom.txt, "item_iron_talon").

LinkLuaModifier("modifier_item_iron_talon_trinity", "items/item_iron_talon_trinity", LUA_MODIFIER_MOTION_NONE)

local PARTICLE_HIT = "particles/items3_fx/iron_talon_active.vpcf"
local SOUND_HIT    = "DOTA_Item.IronTalon.Activate"

item_iron_talon = class({})

function item_iron_talon:Precache(context)
    PrecacheResource("particle", PARTICLE_HIT, context)
end

function item_iron_talon:GetIntrinsicModifierName()
    return "modifier_item_iron_talon_trinity"
end

function item_iron_talon:CastFilterResultTarget(target)
    if target:IsHero() or target:IsBuilding() or target:IsAncient() or target:IsOther() then
        return UF_FAIL_CUSTOM
    end
    return UnitFilter(target, DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NOT_ANCIENTS + DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
        self:GetCaster():GetTeamNumber())
end

function item_iron_talon:GetCustomCastErrorTarget(target)
    return "#dota_hud_error_iron_talon_creeps_only"
end

function item_iron_talon:OnSpellStart()
    local caster = self:GetCaster()
    local target = self:GetCursorTarget()
    if not target or target:IsNull() or not target:IsAlive() then return end
    if target:TriggerSpellAbsorb(self) then return end

    local pct = self:GetSpecialValueFor("creep_damage_pct")
    local damage = target:GetHealth() * pct / 100

    ApplyDamage({
        victim = target,
        attacker = caster,
        damage = damage,
        damage_type = DAMAGE_TYPE_PURE,
        damage_flags = DOTA_DAMAGE_FLAG_NO_SPELL_AMPLIFICATION,
        ability = self,
    })

    local fx = ParticleManager:CreateParticle(PARTICLE_HIT, PATTACH_ABSORIGIN_FOLLOW, target)
    ParticleManager:SetParticleControlEnt(fx, 0, target, PATTACH_POINT_FOLLOW, "attach_hitloc", target:GetAbsOrigin(), true)
    ParticleManager:ReleaseParticleIndex(fx)
    EmitSoundOn(SOUND_HIT, target)
end

-- ============================================================
-- Пассив владельца: броня
-- ============================================================
modifier_item_iron_talon_trinity = class({
    IsHidden      = function(self) return true end,
    IsPurgable    = function(self) return false end,
    RemoveOnDeath = function(self) return false end,
    GetAttributes = function(self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
})

function modifier_item_iron_talon_trinity:OnCreated()
    local ability = self:GetAbility()
    self.armor = ability and ability:GetSpecialValueFor("bonus_armor") or 0
end

function modifier_item_iron_talon_trinity:OnRefresh()
    self:OnCreated()
end

function modifier_item_iron_talon_trinity:DeclareFunctions()
    return { MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS }
end

function modifier_item_iron_talon_trinity:GetModifierPhysicalArmorBonus()
    return self.armor
end
