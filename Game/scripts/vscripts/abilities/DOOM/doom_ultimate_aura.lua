LinkLuaModifier("modifier_doom_ultimate_aura", "abilities/DOOM/doom_ultimate_aura", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_doom_ultimate_aura_debuff", "abilities/DOOM/doom_ultimate_aura", LUA_MODIFIER_MOTION_NONE)

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

function modifier_doom_ultimate_aura:IsAura() return false end
function modifier_doom_ultimate_aura:IsPurgable() return false end
function modifier_doom_ultimate_aura:IsBuff() return true end
function modifier_doom_ultimate_aura:GetEffectRadius()
    local ability = self:GetAbility()
    if not ability then return 0 end

    local base_radius = ability:GetSpecialValueFor("aura_radius")
    local caster = self:GetCaster()
    if not caster then return base_radius end

    -- Учитываем бонусы к радиусу заклинаний
    local spell_radius_bonus = caster:GetSpellAmplification(false) * 100 -- Преобразуем в проценты
    local total_radius = base_radius * (1 + spell_radius_bonus / 100)

    return total_radius
end
function modifier_doom_ultimate_aura:GetEffectName() 
    return "" -- Эффект создается вручную в OnCreated()
end
function modifier_doom_ultimate_aura:GetEffectAttachType() 
    return PATTACH_ABSORIGIN_FOLLOW 
end


function modifier_doom_ultimate_aura:OnCreated()
    if not IsServer() then return end
    self:GetParent():EmitSound("Hero_DoomBringer.ScorchedEarth")
    self.debuff_refresh_interval = 0.2
    self.applied_targets = {}
    
    -- Отладочная информация о радиусе ауры
    local ability = self:GetAbility()
    local total_radius = self:GetEffectRadius()
    
    print("Doom Aura - Total radius:", total_radius)
    
    -- Создаем кастомную частицу с правильным радиусом
    local caster = self:GetCaster()
    local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_doom_bringer/doom_bringer_doom_aura.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
    ParticleManager:SetParticleControl(particle, 1, Vector(total_radius, total_radius, total_radius))
    ParticleManager:SetParticleControl(particle, 2, Vector(total_radius, total_radius, total_radius))
    self.particle = particle

    self:ApplyDebuffInRadius()
    self:StartIntervalThink(self.debuff_refresh_interval)
end

function modifier_doom_ultimate_aura:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_DEATH,
    }
end

function modifier_doom_ultimate_aura:OnIntervalThink()
    if not IsServer() then return end
    self:ApplyDebuffInRadius()
end

function modifier_doom_ultimate_aura:ApplyDebuffInRadius()
    local parent = self:GetParent()
    local ability = self:GetAbility()
    if not parent or not ability then return end

    local enemies = FindUnitsInRadius(
        parent:GetTeamNumber(),
        parent:GetAbsOrigin(),
        nil,
        self:GetEffectRadius(),
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
        FIND_ANY_ORDER,
        false
    )

    local current_targets = {}

    for _, enemy in pairs(enemies) do
        local target_index = enemy:entindex()
        current_targets[target_index] = enemy

        if not self.applied_targets[target_index] then
            enemy:AddNewModifier(parent, ability, "modifier_doom_ultimate_aura_debuff", { duration = self:GetRemainingTime() + 0.1 })
            self.applied_targets[target_index] = enemy
        else
            local modifier = enemy:FindModifierByNameAndCaster("modifier_doom_ultimate_aura_debuff", parent)
            if not modifier then
                enemy:AddNewModifier(parent, ability, "modifier_doom_ultimate_aura_debuff", { duration = self:GetRemainingTime() + 0.1 })
            end
        end
    end

    for target_index, target in pairs(self.applied_targets) do
        if not current_targets[target_index] then
            if target and IsValidEntity(target) then
                target:RemoveModifierByNameAndCaster("modifier_doom_ultimate_aura_debuff", parent)
            end

            self.applied_targets[target_index] = nil
        end
    end
end

function modifier_doom_ultimate_aura:OnDeath( params )
    if not IsServer() then return end
    
    -- Check if the dead unit is the caster
    if params.unit == self:GetParent() then
        -- Stop sounds
        self:GetParent():StopSound("Hero_DoomBringer.Doom")
        self:GetParent():StopSound("Hero_DoomBringer.ScorchedEarth")
        -- Remove modifier
        self:Destroy()
    end
end

function modifier_doom_ultimate_aura:OnDestroy()
    if not IsServer() then return end
    local parent = self:GetParent()
    if parent then
        parent:StopSound("Hero_DoomBringer.ScorchedEarth")
    end

    for _, target in pairs(self.applied_targets or {}) do
        if target and IsValidEntity(target) then
            target:RemoveModifierByNameAndCaster("modifier_doom_ultimate_aura_debuff", self:GetParent())
        end
    end
    
    -- Уничтожаем кастомную частицу
    if self.particle then
        ParticleManager:DestroyParticle(self.particle, false)
        ParticleManager:ReleaseParticleIndex(self.particle)
        self.particle = nil
    end
end

-- Модификатор дебаффа на врагах
modifier_doom_ultimate_aura_debuff = class({})

function modifier_doom_ultimate_aura_debuff:IsPurgable() return false end
function modifier_doom_ultimate_aura_debuff:IsDebuff() return true end

function modifier_doom_ultimate_aura_debuff:GetAttributes()
	return MODIFIER_ATTRIBUTE_IGNORE_DEBUFF_IMMUNITY
end

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
        local current_damage = math.max(0, base_damage + (mind_power * mind_power_multiplier))
        
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
        MODIFIER_PROPERTY_DISABLE_HEALING,
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
    }
end

function modifier_doom_ultimate_aura_debuff:GetDisableHealing()
    return 1
end

function modifier_doom_ultimate_aura_debuff:GetModifierMoveSpeedBonus_Percentage()
    local caster = self:GetCaster()
    if caster and caster:HasModifier("modifier_item_aghanims_shard") then
        local ability = self:GetAbility()
        if ability then
            return -ability:GetSpecialValueFor("shard_move_slow")
        end
    end
    return 0
end

function modifier_doom_ultimate_aura_debuff:CheckState()
    return {
        [MODIFIER_STATE_SILENCED] = true,
        [MODIFIER_STATE_PASSIVES_DISABLED] = true,
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