-- Trinity: Cloak of Flames (Lua-версия ванильной нейтралки).
--   * Пассив: сопротивление магии и урон (от Cloak и Mithril Hammer).
--   * Переключение: пока предмет включён, жжёт врагов вокруг владельца.
-- Значения берутся из KV (npc_items_custom.txt, "item_cloak_of_flames").

LinkLuaModifier("modifier_item_cloak_of_flames_trinity", "items/item_cloak_of_flames_trinity", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_cloak_of_flames_trinity_burn", "items/item_cloak_of_flames_trinity", LUA_MODIFIER_MOTION_NONE)

local PARTICLE_OWNER = "particles/items5_fx/cloak_of_flames.vpcf"
local PARTICLE_BURN  = "particles/items5_fx/cloak_of_flames_debuff.vpcf"

item_cloak_of_flames = class({})

function item_cloak_of_flames:Precache(context)
    PrecacheResource("particle", PARTICLE_OWNER, context)
    PrecacheResource("particle", PARTICLE_BURN, context)
end

function item_cloak_of_flames:GetIntrinsicModifierName()
    return "modifier_item_cloak_of_flames_trinity"
end

function item_cloak_of_flames:OnToggle()
    -- Всё состояние читается из GetToggleState() в модификаторе.
end

-- ============================================================
-- Пассив владельца: сопротивление магии + аура горения (пока включён)
-- ============================================================
modifier_item_cloak_of_flames_trinity = class({
    IsHidden      = function(self) return true end,
    IsPurgable    = function(self) return false end,
    RemoveOnDeath = function(self) return false end,
    GetAttributes = function(self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
})

function modifier_item_cloak_of_flames_trinity:OnCreated()
    local ability = self:GetAbility()
    if not ability then return end
    self.magic_resistance = ability:GetSpecialValueFor("magic_resistance")
    self.armor = ability:GetSpecialValueFor("armor")
    self.bonus_damage = ability:GetSpecialValueFor("bonus_damage")

    if not IsServer() then return end

    -- Новый плащ сразу включён, как ванильный пассив.
    if not ability.trinity_initialized then
        ability.trinity_initialized = true
        if not ability:GetToggleState() and not self:GetParent():IsIllusion() then
            ability:ToggleAbility()
        end
    end

    self.aura_active = false
    self:StartIntervalThink(0.1)
    self:OnIntervalThink()
end

function modifier_item_cloak_of_flames_trinity:OnRefresh()
    self:OnCreated()
end

function modifier_item_cloak_of_flames_trinity:RefreshAuraState()
    local ability = self:GetAbility()
    local parent = self:GetParent()
    local active = false
    if ability and not ability:IsNull() and ability:GetToggleState() and parent then
        local ok, alive = pcall(function()
            if parent:IsNull() then
                return false
            end
            return parent:IsAlive()
        end)
        active = ok and alive == true
    end
    self.aura_active = active
    return active
end

function modifier_item_cloak_of_flames_trinity:OnIntervalThink()
    local active = self:RefreshAuraState()
    if not IsServer() then return end

    if active and not self.owner_fx then
        local parent = self:GetParent()
        if parent and not parent:IsNull() then
            self.owner_fx = ParticleManager:CreateParticle(PARTICLE_OWNER, PATTACH_ABSORIGIN_FOLLOW, parent)
        end
    elseif not active and self.owner_fx then
        ParticleManager:DestroyParticle(self.owner_fx, false)
        ParticleManager:ReleaseParticleIndex(self.owner_fx)
        self.owner_fx = nil
    end
end

function modifier_item_cloak_of_flames_trinity:OnDestroy()
    if IsServer() and self.owner_fx then
        ParticleManager:DestroyParticle(self.owner_fx, false)
        ParticleManager:ReleaseParticleIndex(self.owner_fx)
        self.owner_fx = nil
    end
end

function modifier_item_cloak_of_flames_trinity:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS,
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
        MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
    }
end

function modifier_item_cloak_of_flames_trinity:GetModifierMagicalResistanceBonus()
    return self.magic_resistance or 0
end

function modifier_item_cloak_of_flames_trinity:GetModifierPreAttack_BonusDamage()
    return self.bonus_damage or 0
end

function modifier_item_cloak_of_flames_trinity:GetModifierPhysicalArmorBonus()
    return self.armor or 0
end

function modifier_item_cloak_of_flames_trinity:IsAura()
    return self.aura_active == true
end

function modifier_item_cloak_of_flames_trinity:GetModifierAura()
    return "modifier_item_cloak_of_flames_trinity_burn"
end

function modifier_item_cloak_of_flames_trinity:GetAuraRadius()
    local ability = self:GetAbility()
    return ability and ability:GetSpecialValueFor("radius") or 0
end

function modifier_item_cloak_of_flames_trinity:GetAuraSearchTeam()
    return DOTA_UNIT_TARGET_TEAM_ENEMY
end

function modifier_item_cloak_of_flames_trinity:GetAuraSearchType()
    return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC
end

function modifier_item_cloak_of_flames_trinity:GetAuraSearchFlags()
    return DOTA_UNIT_TARGET_FLAG_NONE
end

function modifier_item_cloak_of_flames_trinity:GetAuraDuration()
    return 0.5
end

-- ============================================================
-- Горение от ауры
-- ============================================================
modifier_item_cloak_of_flames_trinity_burn = class({
    IsHidden   = function(self) return false end,
    IsDebuff   = function(self) return true end,
    IsPurgable = function(self) return false end,
    GetTexture = function(self) return "item_cloak_of_flames" end,
})

function modifier_item_cloak_of_flames_trinity_burn:OnCreated()
    if not IsServer() then return end
    self.fx = ParticleManager:CreateParticle(PARTICLE_BURN, PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
    self:StartIntervalThink(1.0)
end

function modifier_item_cloak_of_flames_trinity_burn:OnIntervalThink()
    local caster = self:GetCaster()
    local ability = self:GetAbility()
    if not caster or caster:IsNull() or not ability or ability:IsNull() then return end

    local damage = caster:IsIllusion()
        and ability:GetSpecialValueFor("damage_illusions")
        or ability:GetSpecialValueFor("damage")

    ApplyDamage({
        victim = self:GetParent(),
        attacker = caster,
        damage = damage,
        damage_type = DAMAGE_TYPE_MAGICAL,
        damage_flags = DOTA_DAMAGE_FLAG_NO_SPELL_AMPLIFICATION,
        ability = ability,
    })
end

function modifier_item_cloak_of_flames_trinity_burn:OnDestroy()
    if IsServer() and self.fx then
        ParticleManager:DestroyParticle(self.fx, false)
        ParticleManager:ReleaseParticleIndex(self.fx)
        self.fx = nil
    end
end
