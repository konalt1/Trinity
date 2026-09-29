-- Trinity: Radiance (Lua-версия ванильного предмета).
--   * Пассив: бонус к урону, уклонение и сопротивление магии (от Cloak of Flames).
--   * Пока предмет включён: аура горения вокруг владельца (как в ванилле).
--   * Включение: из героя выходит огненная волна — урон и ослепление врагам в радиусе ауры.
--   * Выключение: предмет уходит в КД на toggle_off_cooldown секунд.
-- Значения берутся из KV (npc_items_custom.txt, "item_radiance").

LinkLuaModifier("modifier_item_radiance_trinity", "items/item_radiance_trinity", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_radiance_trinity_burn", "items/item_radiance_trinity", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_radiance_trinity_blind", "items/item_radiance_trinity", LUA_MODIFIER_MOTION_NONE)

local PARTICLE_OWNER = "particles/items2_fx/radiance_owner.vpcf"
local PARTICLE_BURN  = "particles/items2_fx/radiance.vpcf"
local PARTICLE_WAVE  = "particles/units/heroes/hero_jakiro/jakiro_liquid_fire_explosion.vpcf"
local SOUND_WAVE     = "Hero_Lina.DragonSlave"

item_radiance = class({})

function item_radiance:Precache(context)
    PrecacheResource("particle", PARTICLE_OWNER, context)
    PrecacheResource("particle", PARTICLE_BURN, context)
    PrecacheResource("particle", PARTICLE_WAVE, context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_lina.vsndevts", context)
end

function item_radiance:GetIntrinsicModifierName()
    return "modifier_item_radiance_trinity"
end

function item_radiance:GetAbilityTextureName()
    if self:GetToggleState() then
        return "item_radiance"
    end
    return "item_radiance_inactive"
end

function item_radiance:OnToggle()
    if not IsServer() then return end
    local caster = self:GetCaster()

    if self:GetToggleState() then
        -- Первое включение при получении предмета — без волны.
        if self.trinity_silent_toggle then
            self.trinity_silent_toggle = nil
            return
        end
        self:ReleaseFireWave()
    else
        self:EndCooldown()
        self:StartCooldown(self:GetSpecialValueFor("toggle_off_cooldown"))
    end
end

function item_radiance:ReleaseFireWave()
    local caster = self:GetCaster()
    if not caster or caster:IsNull() or caster:IsIllusion() then return end

    local origin = caster:GetAbsOrigin()
    local radius = self:GetSpecialValueFor("aura_radius")
    local damage = self:GetSpecialValueFor("wave_damage")
    local blind_duration = self:GetSpecialValueFor("blind_duration")

    local fx = ParticleManager:CreateParticle(PARTICLE_WAVE, PATTACH_ABSORIGIN, caster)
    ParticleManager:SetParticleControl(fx, 0, origin)
    ParticleManager:SetParticleControl(fx, 1, Vector(radius, radius, radius))
    ParticleManager:ReleaseParticleIndex(fx)
    EmitSoundOn(SOUND_WAVE, caster)

    local enemies = FindUnitsInRadius(
        caster:GetTeamNumber(),
        origin,
        nil,
        radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )

    for _, enemy in pairs(enemies) do
        if enemy and not enemy:IsNull() and enemy:IsAlive() then
            ApplyDamage({
                victim = enemy,
                attacker = caster,
                damage = damage,
                damage_type = DAMAGE_TYPE_MAGICAL,
                ability = self,
            })
            if enemy:IsAlive() then
                enemy:AddNewModifier(caster, self, "modifier_item_radiance_trinity_blind", {
                    duration = blind_duration * (1 - enemy:GetStatusResistance()),
                })
            end
        end
    end
end

-- ============================================================
-- Пассив владельца: статы + аура горения (пока предмет включён)
-- ============================================================
modifier_item_radiance_trinity = class({
    IsHidden      = function(self) return true end,
    IsPurgable    = function(self) return false end,
    RemoveOnDeath = function(self) return false end,
    GetAttributes = function(self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
})

function modifier_item_radiance_trinity:OnCreated()
    local ability = self:GetAbility()
    if not ability then return end
    self.bonus_damage = ability:GetSpecialValueFor("bonus_damage")
    self.evasion = ability:GetSpecialValueFor("evasion")
    self.magic_resistance = ability:GetSpecialValueFor("bonus_magic_resistance")

    if not IsServer() then return end

    -- Как в ванилле: новый Радик включён сразу. Включение тихое, без волны.
    if not ability.trinity_initialized then
        ability.trinity_initialized = true
        if not ability:GetToggleState() and not self:GetParent():IsIllusion() then
            ability.trinity_silent_toggle = true
            ability:ToggleAbility()
            ability.trinity_silent_toggle = nil
        end
    end

    self.aura_active = false
    self:StartIntervalThink(0.1)
    self:OnIntervalThink()
end

function modifier_item_radiance_trinity:OnRefresh()
    self:OnCreated()
end

function modifier_item_radiance_trinity:RefreshAuraState()
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

function modifier_item_radiance_trinity:OnIntervalThink()
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

function modifier_item_radiance_trinity:OnDestroy()
    if IsServer() and self.owner_fx then
        ParticleManager:DestroyParticle(self.owner_fx, false)
        ParticleManager:ReleaseParticleIndex(self.owner_fx)
        self.owner_fx = nil
    end
end

function modifier_item_radiance_trinity:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
        MODIFIER_PROPERTY_EVASION_CONSTANT,
        MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS,
    }
end

function modifier_item_radiance_trinity:GetModifierPreAttack_BonusDamage()
    return self.bonus_damage or 0
end

function modifier_item_radiance_trinity:GetModifierMagicalResistanceBonus()
    return self.magic_resistance or 0
end

function modifier_item_radiance_trinity:GetModifierEvasion_Constant()
    return self.evasion or 0
end

function modifier_item_radiance_trinity:IsAura()
    return self.aura_active == true
end

function modifier_item_radiance_trinity:GetModifierAura()
    return "modifier_item_radiance_trinity_burn"
end

function modifier_item_radiance_trinity:GetAuraRadius()
    local ability = self:GetAbility()
    return ability and ability:GetSpecialValueFor("aura_radius") or 0
end

function modifier_item_radiance_trinity:GetAuraSearchTeam()
    return DOTA_UNIT_TARGET_TEAM_ENEMY
end

function modifier_item_radiance_trinity:GetAuraSearchType()
    return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC
end

function modifier_item_radiance_trinity:GetAuraSearchFlags()
    return DOTA_UNIT_TARGET_FLAG_NONE
end

function modifier_item_radiance_trinity:GetAuraDuration()
    return 0.5
end

-- ============================================================
-- Горение от ауры
-- ============================================================
modifier_item_radiance_trinity_burn = class({
    IsHidden   = function(self) return false end,
    IsDebuff   = function(self) return true end,
    IsPurgable = function(self) return false end,
    GetTexture = function(self) return "item_radiance" end,
})

function modifier_item_radiance_trinity_burn:OnCreated()
    if not IsServer() then return end
    local caster = self:GetCaster()
    self.fx = ParticleManager:CreateParticle(PARTICLE_BURN, PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
    if caster then
        ParticleManager:SetParticleControl(self.fx, 1, caster:GetAbsOrigin())
    end
    self:StartIntervalThink(1.0)
end

function modifier_item_radiance_trinity_burn:OnIntervalThink()
    local caster = self:GetCaster()
    local ability = self:GetAbility()
    local parent = self:GetParent()
    if not caster or caster:IsNull() or not ability or ability:IsNull() then return end

    if self.fx then
        ParticleManager:SetParticleControl(self.fx, 1, caster:GetAbsOrigin())
    end

    local damage = caster:IsIllusion()
        and ability:GetSpecialValueFor("aura_damage_illusions")
        or ability:GetSpecialValueFor("aura_damage")

    ApplyDamage({
        victim = parent,
        attacker = caster,
        damage = damage,
        damage_type = DAMAGE_TYPE_MAGICAL,
        damage_flags = DOTA_DAMAGE_FLAG_NO_SPELL_AMPLIFICATION,
        ability = ability,
    })
end

function modifier_item_radiance_trinity_burn:OnDestroy()
    if IsServer() and self.fx then
        ParticleManager:DestroyParticle(self.fx, false)
        ParticleManager:ReleaseParticleIndex(self.fx)
        self.fx = nil
    end
end

-- ============================================================
-- Ослепление от огненной волны
-- ============================================================
modifier_item_radiance_trinity_blind = class({
    IsHidden   = function(self) return false end,
    IsDebuff   = function(self) return true end,
    IsPurgable = function(self) return true end,
    GetTexture = function(self) return "item_radiance" end,
})

function modifier_item_radiance_trinity_blind:OnCreated()
    local ability = self:GetAbility()
    self.miss = ability and ability:GetSpecialValueFor("blind_miss_pct") or 0
end

function modifier_item_radiance_trinity_blind:OnRefresh()
    self:OnCreated()
end

function modifier_item_radiance_trinity_blind:DeclareFunctions()
    return { MODIFIER_PROPERTY_MISS_PERCENTAGE }
end

function modifier_item_radiance_trinity_blind:GetModifierMiss_Percentage()
    return self.miss
end
