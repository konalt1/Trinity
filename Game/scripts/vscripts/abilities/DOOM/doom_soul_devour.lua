-- Doom Soul Devour Ability
-- Позволяет Doom поглощать души крипов и героев для увеличения Mind Power

doom_soul_devour = class({})
LinkLuaModifier("modifier_doom_soul_devour", "abilities/DOOM/doom_soul_devour", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_mind_power_local_buff", "abilities/DOOM/doom_soul_devour", LUA_MODIFIER_MOTION_NONE)

--------------------------------------------------------------------------------
-- Ability Start
function doom_soul_devour:OnSpellStart()
    local caster = self:GetCaster()
    local target = self:GetCursorTarget()
    
    if not target then
        print("Doom Soul Devour: No target selected")
        return
    end
    
    -- Проверяем, что цель валидна
    if not self:IsValidTarget(target) then
        print("Doom Soul Devour: Invalid target")
        return
    end
    
    -- Получаем параметры способности
    local soul_power = self:GetSpecialValueFor("soul_power") or 1
    local heal_amount = self:GetSpecialValueFor("heal_amount") or 0
    local hero_soul_multiplier = self:GetSpecialValueFor("hero_soul_multiplier") or 3
    
    print("Doom Soul Devour: soul_power = " .. soul_power .. ", heal_amount = " .. heal_amount .. ", hero_soul_multiplier = " .. hero_soul_multiplier)
    
    -- Обрабатываем убийство героя (с Aghanim's Scepter)
    if target:IsRealHero() and self:GetCaster():HasScepter() then
        self:ProcessHeroKill(caster, target, soul_power, hero_soul_multiplier)
    else
        -- Обрабатываем убийство крипа
        self:ProcessCreepKill(caster, target, soul_power, heal_amount)
    end
    
    -- Воспроизводим эффекты
    self:PlayEffects(target)
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
    if target:IsRealHero() then
        return self:GetCaster():HasScepter()
    else
        return target:IsCreep()
    end
end

--------------------------------------------------------------------------------
-- Обработка убийства героя
function doom_soul_devour:ProcessHeroKill(caster, target, soul_power, hero_soul_multiplier)
    print("Doom Soul Devour: Processing hero kill with Aghanim")
    
    -- Убиваем героя
    target:Kill(self, caster)
    
    -- Воспроизводим эффекты
    local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_doom_bringer/doom_bringer_doom.vpcf", PATTACH_ABSORIGIN_FOLLOW, target)
    ParticleManager:ReleaseParticleIndex(particle)
    
    caster:EmitSound("Hero_DoomBringer.Doom")
    Timers:CreateTimer(0.1, function()
        caster:StopSound("Hero_DoomBringer.Doom")
    end)
    
    -- Увеличиваем Mind Power
    self:IncreaseMindPower(caster, soul_power * hero_soul_multiplier) -- Герои дают больше души
end

--------------------------------------------------------------------------------
-- Обработка убийства крипа
function doom_soul_devour:ProcessCreepKill(caster, target, soul_power, heal_amount)
    print("Doom Soul Devour: Processing creep kill")
    
    -- Убиваем крипа
    target:Kill(self, caster)
    
    -- Лечим кастера
    if heal_amount > 0 then
        caster:Heal(heal_amount, self)
    end
    
    -- Увеличиваем Mind Power
    self:IncreaseMindPower(caster, soul_power)
    
    print("Doom Soul Devour: Creep killed successfully")
end

--------------------------------------------------------------------------------
-- Увеличение Mind Power
function doom_soul_devour:IncreaseMindPower(caster, soul_power)
    print("Doom Soul Devour: Attempting to increase Mind Power by " .. soul_power)
    
    local mind_power_buff = caster:FindModifierByName("modifier_mind_power_local_buff")
    
    if mind_power_buff then
        -- Если модификатор уже есть, увеличиваем его
        local current_bonus = mind_power_buff:GetStackCount()
        local new_bonus = current_bonus + soul_power
        mind_power_buff:SetStackCount(new_bonus)
        print("Doom Soul Devour: Mind power buff increased from " .. current_bonus .. " to " .. new_bonus)
    else
        -- Создаем новый постоянный модификатор
        print("Doom Soul Devour: Creating new permanent mind power buff with +" .. soul_power)
        print("Doom Soul Devour: Caster = " .. caster:GetUnitName())
        print("Doom Soul Devour: Ability = " .. self:GetAbilityName())
        
        local new_buff = caster:AddNewModifier(caster, self, "modifier_mind_power_local_buff", {duration = -1, soul_power = soul_power})
        if new_buff then
            new_buff:SetStackCount(soul_power)
            print("Doom Soul Devour: Created permanent mind power buff with +" .. soul_power)
        else
            print("Doom Soul Devour: Failed to create mind power buff")
            print("Doom Soul Devour: Check if modifier is properly registered")
        end
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

--------------------------------------------------------------------------------
-- Mind Power Local Buff Modifier
modifier_mind_power_local_buff = class({})

function modifier_mind_power_local_buff:IsHidden()
    return false
end

function modifier_mind_power_local_buff:IsDebuff()
    return false
end

function modifier_mind_power_local_buff:IsPurgable()
    return false
end

function modifier_mind_power_local_buff:GetAttributes()
    return MODIFIER_ATTRIBUTE_MULTIPLE
end

function modifier_mind_power_local_buff:RemoveOnDeath()
    return false
end

function modifier_mind_power_local_buff:IsPermanent()
    return true
end

function modifier_mind_power_local_buff:OnCreated(kv)
    print("Mind Power Local Buff: OnCreated called")
    if not IsServer() then 
        print("Mind Power Local Buff: Not server, returning")
        return 
    end
    
    -- Получаем начальное значение из параметров или из стека
    self.mind_power_bonus = kv.soul_power or self:GetStackCount()
    print("Mind Power Local Buff: Created with +" .. self.mind_power_bonus .. " for " .. self:GetParent():GetUnitName())
end

function modifier_mind_power_local_buff:OnRefresh()
    if not IsServer() then return end
    
    self.mind_power_bonus = self:GetStackCount()
    print("Mind Power Local Buff: Updated to +" .. self.mind_power_bonus .. " for " .. self:GetParent():GetUnitName())
end

function modifier_mind_power_local_buff:GetModifierMindPowerBonus()
    return self:GetStackCount()
end

function modifier_mind_power_local_buff:GetTexture()
    return "doom_bringer_devour"
end

function modifier_mind_power_local_buff:GetEffectName()
    return "particles/units/heroes/hero_doom_bringer/doom_bringer_devour.vpcf"
end

function modifier_mind_power_local_buff:GetEffectAttachType()
    return PATTACH_ABSORIGIN_FOLLOW
end

function modifier_mind_power_local_buff:GetModifierDisplayName()
    return "Soul Power"
end

function modifier_mind_power_local_buff:GetModifierDescription()
    return "Increases Mind Power by " .. self:GetStackCount() .. " through devoured souls."
end 