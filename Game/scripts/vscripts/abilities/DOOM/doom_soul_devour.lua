-- Doom Soul Devour Ability
-- Позволяет Doom поглощать души крипов, а со скипетром добивать героев.

doom_soul_devour = class({})
LinkLuaModifier("modifier_doom_soul_devour", "abilities/DOOM/doom_soul_devour", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_mind_power_local_buff", "abilities/mind_power_local_buff", LUA_MODIFIER_MOTION_NONE)

local DEVOUR_FAIL_SOUND = "General.CastFail_InvalidTarget_Hero"
local DEVOUR_FAIL_HP_SOUND = "Doom.SoulDevour.FailHP"

--------------------------------------------------------------------------------
-- Ability Start
function doom_soul_devour:OnSpellStart()
    if not IsServer() then
        return
    end

    local caster = self:GetCaster()
    local target = self:GetCursorTarget()

    if not target then
        return
    end

    if not self:IsValidTarget(target) then
        return
    end

    if target:IsHero() and target:TriggerSpellAbsorb(self) then
        return
    end

    if target:IsHero() then
        self:ProcessHeroTarget(caster, target)
        return
    end

    self:ProcessCreepKill(
        caster,
        target,
        self:GetSpecialValueFor("soul_power") or 1,
        self:GetSpecialValueFor("heal_amount") or 0
    )
    self:PlayEffects(target)
end

--------------------------------------------------------------------------------
function doom_soul_devour:CastFilterResultTarget(target)
    local caster = self:GetCaster()
    local result = UnitFilter(
        target,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NOT_ANCIENTS,
        caster:GetTeamNumber()
    )

    if result ~= UF_SUCCESS then
        return result
    end

    if target:IsHero() and not caster:HasScepter() then
        return UF_FAIL_CUSTOM
    end

    if not target:IsHero() and not target:IsCreep() then
        return UF_FAIL_CUSTOM
    end

    return UF_SUCCESS
end

function doom_soul_devour:GetCustomCastErrorTarget(target)
    if target and target:IsHero() and not self:GetCaster():HasScepter() then
        return "#dota_hud_error_doom_devour_scepter_required"
    end

    return ""
end

--------------------------------------------------------------------------------
-- Проверка валидности цели
function doom_soul_devour:IsValidTarget(target)
    if not target or target:IsNull() then
        return false
    end
    
    -- Проверяем команду
    if target:GetTeamNumber() == self:GetCaster():GetTeamNumber() then
        return false
    end
    
    -- Проверяем, что цель жива
    if not target:IsAlive() then
        return false
    end
    
    -- Проверяем, что это крип или герой (с Aghanim's Scepter)
    if target:IsHero() then
        return self:GetCaster():HasScepter()
    else
        return target:IsCreep()
    end
end

--------------------------------------------------------------------------------
-- Обработка применения на героя
function doom_soul_devour:ProcessHeroTarget(caster, target)
    local hp_threshold = self:GetSpecialValueFor("aghanim_hp_threshold") or 666
    local hero_mind_power_bonus = self:GetSpecialValueFor("aghanim_hero_mind_power_bonus") or 10

    if target:GetHealth() > hp_threshold then
        self:PlayFailEffects(caster, DEVOUR_FAIL_HP_SOUND)
        return
    end

    if target:IsMagicImmune() or target:IsIllusion() or not target:IsRealHero() then
        self:PlayFailEffects(caster)
        return
    end

    target:Kill(self, caster)

    if target:IsAlive() then
        self:PlayFailEffects(caster)
        return
    end

    self:IncreaseMindPower(caster, hero_mind_power_bonus)
    self:PlayHeroKillEffects(caster, target)
end

--------------------------------------------------------------------------------
-- Обработка убийства крипа
function doom_soul_devour:ProcessCreepKill(caster, target, soul_power, heal_amount)
    -- Убиваем крипа
    target:Kill(self, caster)

    -- Лечим кастера
    if heal_amount > 0 then
        caster:Heal(heal_amount, self)
    end
    
    -- Увеличиваем Mind Power
    self:IncreaseMindPower(caster, soul_power)
end

--------------------------------------------------------------------------------
-- Увеличение Mind Power
function doom_soul_devour:IncreaseMindPower(caster, soul_power)
    local mind_power_buff = caster:FindModifierByName("modifier_mind_power_local_buff")

    if mind_power_buff then
        mind_power_buff:SetStackCount(mind_power_buff:GetStackCount() + soul_power)
        mind_power_buff:ForceRefresh()
        return
    end

    local new_buff = caster:AddNewModifier(caster, self, "modifier_mind_power_local_buff", {})
    if new_buff then
        new_buff:SetStackCount(soul_power)
        new_buff:ForceRefresh()
    end
end

--------------------------------------------------------------------------------
-- Получение дистанции каста
function doom_soul_devour:GetCastRange(location, target)
    return self:GetSpecialValueFor("cast_range") or 300
end

--------------------------------------------------------------------------------
-- Получение количества поглощенной души
function doom_soul_devour:GetDevouredMindPower(caster)
    local mind_power_buff = caster:FindModifierByName("modifier_mind_power_local_buff")
    if mind_power_buff then
        return mind_power_buff:GetStackCount()
    end
    return 0
end

--------------------------------------------------------------------------------
-- Воспроизведение эффектов
function doom_soul_devour:PlayEffects(target)
    local particle_cast = "particles/units/heroes/hero_doom_bringer/doom_bringer_devour.vpcf"
    local sound_cast = "Hero_DoomBringer.Devour"
    local sound_target = "Hero_DoomBringer.DevourCast"
    
    -- Создаем частицы
    local effect_cast = ParticleManager:CreateParticle(particle_cast, PATTACH_ABSORIGIN_FOLLOW, target)
    ParticleManager:SetParticleControlEnt(
        effect_cast,
        1,
        self:GetCaster(),
        PATTACH_POINT_FOLLOW,
        "attach_hitloc",
        Vector(0,0,0),
        true
    )
    ParticleManager:ReleaseParticleIndex(effect_cast)
    
    -- Воспроизводим звуки
    EmitSoundOn(sound_cast, self:GetCaster())
    EmitSoundOn(sound_target, target)
end

function doom_soul_devour:PlayHeroKillEffects(caster, target)
    self:PlayEffects(target)

    local particle = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_doom_bringer/doom_bringer_doom.vpcf",
        PATTACH_ABSORIGIN_FOLLOW,
        target
    )
    ParticleManager:ReleaseParticleIndex(particle)

    EmitSoundOn("Hero_DoomBringer.Doom", caster)
end

function doom_soul_devour:PlayFailEffects(caster, sound_name)
    local fail_sound = sound_name or DEVOUR_FAIL_SOUND
    local player = caster:GetPlayerOwner()
    if player then
        EmitSoundOnClient(fail_sound, player)
        return
    end

    EmitSoundOn(fail_sound, caster)
end

--------------------------------------------------------------------------------
-- Модификатор для Mind Power
modifier_doom_soul_devour = class({})

function modifier_doom_soul_devour:IsHidden()
    return false
end

function modifier_doom_soul_devour:IsDebuff()
    return false
end

function modifier_doom_soul_devour:IsPurgable()
    return false
end

function modifier_doom_soul_devour:GetAttributes()
    return MODIFIER_ATTRIBUTE_MULTIPLE
end

function modifier_doom_soul_devour:OnCreated(kv)
    if not IsServer() then return end
    
    self.soul_power = kv.soul_power or 1
    self.heal_amount = kv.heal_amount or 0
end

function modifier_doom_soul_devour:OnRefresh(kv)
    if not IsServer() then return end
    
    self.soul_power = kv.soul_power or self.soul_power
    self.heal_amount = kv.heal_amount or self.heal_amount
end

function modifier_doom_soul_devour:OnDestroy()
    if not IsServer() then return end
    
    -- Модификатор уничтожен
end

function modifier_doom_soul_devour:DeclareFunctions()
    local funcs = {
        MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
    }
    return funcs
end

function modifier_doom_soul_devour:GetModifierConstantHealthRegen()
    return self.heal_amount or 0
end
