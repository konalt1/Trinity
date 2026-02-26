LinkLuaModifier("modifier_ability_ice_phylactery", "abilities/lich/ability_ice_phylactery", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_ability_ice_phylactery_buff", "abilities/lich/ability_ice_phylactery", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_spell_lifesteal_custom", "abilities/lich/ability_ice_phylactery", LUA_MODIFIER_MOTION_NONE)
  
ability_ice_phylactery = class({})

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
    unit:AddNewModifier(self:GetCaster(), self, "modifier_ability_ice_phylactery", {duration = self:GetSpecialValueFor("duration")})
end


modifier_ability_ice_phylactery = class({
    IsHidden                = function(self) return false end,
    IsPurgable              = function(self) return false end,
    IsPurgeException        = function(self) return false end,
    IsDebuff                = function(self) return false end,
    RemoveOnDeath           = function(self) return true end,
    IsAura                  = function(self) return true end,
    GetModifierAura         = function(self) return "modifier_ability_ice_phylactery_buff" end,
    GetAuraSearchTeam       = function(self) return DOTA_UNIT_TARGET_TEAM_BOTH end,
    GetAuraRadius           = function(self) return self:GetAbility():GetSpecialValueFor("aura_radius") end,
    GetAuraDuration         = function(self) return self:GetAbility():GetSpecialValueFor("slow_duration") end,
    GetAuraSearchType       = function(self) return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC end,
    GetAuraEntityReject     = function(self, target) 
        local caster = self:GetCaster()
        if not caster or caster:IsNull() then return true end
        
        local isSameTeam = target:GetTeamNumber() == caster:GetTeamNumber()
        local isCaster = target == caster
        
        -- Действует только на кастера (союзник) или на врагов
        if isSameTeam then
            return not isCaster -- Отклоняем всех союзников кроме кастера
        end
        return false -- Не отклоняем врагов
    end,
    DeclareFunctions        = function(self)
        return {
            MODIFIER_PROPERTY_HEALTHBAR_PIPS,
            MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_MAGICAL,
            MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PHYSICAL,
            MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PURE,
            MODIFIER_EVENT_ON_ATTACKED,
            MODIFIER_EVENT_ON_TAKEDAMAGE,
        }
    end,
    GetAbsoluteNoDamageMagical  = function(self) return 1 end,
    GetAbsoluteNoDamagePhysical = function(self) return 1 end,
    GetAbsoluteNoDamagePure     = function(self) return 1 end,
})

function modifier_ability_ice_phylactery:OnCreated()
    local ability = self:GetAbility()
    if not ability then return end
    
    local parent = self:GetParent()
    if not parent or parent:IsNull() then return end
    
    local caster = self:GetCaster()
    
    local radius = ability:GetSpecialValueFor("aura_radius")
    local origin = parent:GetAbsOrigin()

    -- Инициализируем систему HP и пипсов
    self.Pips = ability:GetSpecialValueFor("max_hero_attacks")
    self.AttacksToDestroy = ability:GetSpecialValueFor("max_creep_attacks")
    
    if IsServer() then 
        parent:SetMaxHealth(self.AttacksToDestroy)
        parent:SetHealth(self.AttacksToDestroy)
        
        -- Проверяем наличие Aghanim's Shard для движения шпиля
        if caster and not caster:IsNull() and caster:HasModifier("modifier_item_aghanims_shard") then
            self.has_shard = true
            self.move_speed = ability:GetSpecialValueFor("shard_spire_move_speed")
            self.follow_distance = ability:GetSpecialValueFor("shard_spire_follow_distance")
            self.think_interval = 1 / 24
            self:StartIntervalThink(self.think_interval)
        else
            self.has_shard = false
        end
    end
    
    self.HeroesAttacksMult = 2
    self.HealthPerPips = self.AttacksToDestroy / self.AttacksToDestroy
    self.aura_radius = radius

    -- Создаём партикл шпиля
    self.effect_cast = self:CreateSpireParticle(parent, origin, radius)
end

-- Создаёт новый партикл и удаляет старый (двойная буферизация — без мигания)
function modifier_ability_ice_phylactery:CreateSpireParticle(parent, pos, radius)
    local new_particle = ParticleManager:CreateParticle("particles/items_fx/aura_shivas.vpcf", PATTACH_ABSORIGIN_FOLLOW, parent)
    ParticleManager:SetParticleControl(new_particle, 1, Vector(radius, radius, radius))
    return new_particle
end

-- Think функция для движения шпиля за Личём (только с Aghanim's Shard)
function modifier_ability_ice_phylactery:OnIntervalThink()
    if not IsServer() then return end
    if not self.has_shard then return end
    
    local parent = self:GetParent()
    local caster = self:GetCaster()
    
    if not parent or parent:IsNull() then return end
    if not caster or caster:IsNull() then return end
    
    -- Шпиль следует за кастером даже после его смерти? Нет - остаётся на месте
    if not caster:IsAlive() then return end
    
    local spire_pos = parent:GetAbsOrigin()
    local caster_pos = caster:GetAbsOrigin()
    
    -- Вычисляем расстояние до кастера
    local direction = caster_pos - spire_pos
    local distance = direction:Length2D()
    
    -- Если шпиль уже достаточно близко - не двигаемся
    if distance <= self.follow_distance then
        return
    end
    
    -- Нормализуем направление
    direction.z = 0
    direction = direction:Normalized()
    
    -- Вычисляем новую позицию (движемся со скоростью move_speed)
    local move_distance = self.move_speed * self.think_interval
    
    -- Не перелетаем через цель
    if move_distance > (distance - self.follow_distance) then
        move_distance = distance - self.follow_distance
    end
    
    local new_pos = spire_pos + direction * move_distance
    
    -- Перемещаем шпиль
    parent:SetAbsOrigin(new_pos)
    
    -- Пересоздаём партикл на новой позиции (двойная буферизация)
    self.effect_cast = self:CreateSpireParticle(parent, new_pos, self.aura_radius)
end

function modifier_ability_ice_phylactery:OnDestroy()
    if IsServer() then 
        self:GetParent():EmitSound("Hero_Lich.IceSpire.Destroy")
    end
    ParticleManager:DestroyParticle(self.effect_cast, false)
    ParticleManager:ReleaseParticleIndex(self.effect_cast)
end

function modifier_ability_ice_phylactery:GetTexture()
    return "lich_ice_phylactery"
end

function modifier_ability_ice_phylactery:OnTakeDamage(params)
    if not IsServer() then return end
    if not params or not params.unit then return end
    
    local parent = self:GetParent()
    if not parent or parent:IsNull() then return end
    
    local caster = self:GetCaster()
    if not caster or caster:IsNull() then return end
    
    local victim = params.unit
    if victim:IsNull() then return end
    
    local ability = self:GetAbility()
    if not ability then return end
    
    local radius = ability:GetSpecialValueFor("aura_radius")
    
    -- Проверяем, что жертва - враг
    if victim:GetTeamNumber() == caster:GetTeamNumber() then
        return
    end
    
    -- Проверяем, что жертва в радиусе тотема
    local distance = (victim:GetAbsOrigin() - parent:GetAbsOrigin()):Length2D()
    if distance > radius then
        return
    end
    
    -- Даем кастеру ману равную полученному урону
    if caster:IsAlive() then
        caster:GiveMana(params.damage)
        
        -- Эффект восстановления маны
        local particle = ParticleManager:CreateParticle("particles/generic_gameplay/generic_mana_gain.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
        ParticleManager:SetParticleControl(particle, 0, caster:GetAbsOrigin())
        ParticleManager:ReleaseParticleIndex(particle)
    end
end

-- Обработка атак через систему HP
function modifier_ability_ice_phylactery:OnAttacked(keys)
    if not IsServer() then return end
    
    local target = keys.target
    local attacker = keys.attacker
    local parent = self:GetParent()
    
    if not target or not attacker or not parent or parent:IsNull() then return end
    if target ~= parent then return end
    
    -- Рассчитываем урон: герои х2, крипы х1
    local damage = self.HealthPerPips * (attacker:IsRealHero() and self.HeroesAttacksMult or 1)
    local HealthsDiff = math.floor(parent:GetHealth() - damage)
    
    -- Эффект попадания
    local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_crystalmaiden/maiden_ice_hit.vpcf", PATTACH_ABSORIGIN_FOLLOW, parent)
    ParticleManager:SetParticleControl(particle, 0, parent:GetAbsOrigin())
    ParticleManager:ReleaseParticleIndex(particle)
    
    parent:EmitSound("Hero_Lich.IceSpire.Hit")
    
    if HealthsDiff <= 0 then
        parent:Kill(nil, attacker)
        self:Destroy()
    else 
        parent:SetHealth(HealthsDiff)
    end
end

-- Показываем пипсы на хелсбаре
function modifier_ability_ice_phylactery:GetModifierHealthBarPips()
    return self.Pips or 0
end

modifier_ability_ice_phylactery_buff = class({
    IsHidden      = function(self) return false end,
    IsPurgable    = function(self) return false end,
    RemoveOnDeath = function(self) return true end,
})

function modifier_ability_ice_phylactery_buff:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
        MODIFIER_PROPERTY_COOLDOWN_PERCENTAGE,
    }
end

function modifier_ability_ice_phylactery_buff:OnCreated()
    local caster = self:GetCaster()
    if not caster or caster:IsNull() then return end
    
    local parent = self:GetParent()
    if not parent or parent:IsNull() then return end
    
    local ability = self:GetAbility()
    if not ability then return end
    
    -- Проверяем, является ли цель кастером
    self.isCaster = parent == caster
    
    if IsServer() and self.isCaster then 
        self.modifier = parent:AddNewModifier(caster, ability, "modifier_spell_lifesteal_custom", {})
    end
end

function modifier_ability_ice_phylactery_buff:OnDestroy()
    if IsClient() then return end

    if self.modifier then 
        self.modifier:Destroy()
    end
end

function modifier_ability_ice_phylactery_buff:IsBuff()
    return self.isCaster
end

function modifier_ability_ice_phylactery_buff:GetModifierMoveSpeedBonus_Percentage()
    -- Замедление для врагов
    if not self.isCaster then 
        local ability = self:GetAbility()
        if not ability then return 0 end
        return ability:GetSpecialValueFor("bonus_movespeed")
    end
    return 0
end

function modifier_ability_ice_phylactery_buff:GetModifierPercentageCooldown()
    if self.isCaster then 
        local ability = self:GetAbility()
        if not ability then return 0 end
        return ability:GetSpecialValueFor("cooldown_reduction")
    end
    return 0
end

modifier_spell_lifesteal_custom = class({
    IsHidden      = function(self) return true end,
    IsPurgable    = function(self) return false end,
    IsBuff        = function(self) return true end,
    RemoveOnDeath = function(self) return false end,
})

function modifier_spell_lifesteal_custom:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_TAKEDAMAGE,
    }
end

function modifier_spell_lifesteal_custom:OnCreated()
    if not IsServer() then return end
    
    local ability = self:GetAbility()
    if not ability then return end
    
    self.spell_lifesteal = ability:GetSpecialValueFor("spell_lifesteal")
end
 
function modifier_spell_lifesteal_custom:OnTakeDamage(keys)
    if not IsServer() then return end
    if not keys or not keys.attacker or not keys.unit then return end
    
    local parent = self:GetParent()
    if not parent or parent:IsNull() then return end
    
    -- Проверяем, что атакующий - владелец модификатора
    if keys.attacker ~= parent then return end
    
    -- Не работает на здания и другие объекты
    if keys.unit:IsBuilding() or keys.unit:IsOther() then return end
    
    -- Проверяем, что это урон от заклинания и есть инфликтор
    if keys.damage_category ~= DOTA_DAMAGE_CATEGORY_SPELL or not keys.inflictor then return end
    
    -- Исправленная проверка флага NO_SPELL_LIFESTEAL
    if bit.band(keys.damage_flags, DOTA_DAMAGE_FLAG_NO_SPELL_LIFESTEAL) == DOTA_DAMAGE_FLAG_NO_SPELL_LIFESTEAL then
        return
    end
    
    -- Эффект лайфстила
    local lifesteal_pfx = ParticleManager:CreateParticle("particles/items3_fx/octarine_core_lifesteal.vpcf", PATTACH_ABSORIGIN_FOLLOW, keys.attacker)
    ParticleManager:SetParticleControl(lifesteal_pfx, 0, keys.attacker:GetAbsOrigin())
    ParticleManager:ReleaseParticleIndex(lifesteal_pfx)
    
    local damage = keys.damage
    
    -- Корректируем урон для иллюзий
    if keys.unit:IsIllusion() and keys.original_damage then
        if keys.damage_type == DAMAGE_TYPE_PHYSICAL and keys.unit.GetPhysicalArmorValue and GetReductionFromArmor then
            damage = keys.original_damage * (1 - GetReductionFromArmor(keys.unit:GetPhysicalArmorValue(false)))
        elseif keys.damage_type == DAMAGE_TYPE_MAGICAL and keys.unit.GetMagicalArmorValue then
            damage = keys.original_damage * (1 - GetReductionFromArmor(keys.unit:GetMagicalArmorValue()))
        elseif keys.damage_type == DAMAGE_TYPE_PURE then
            damage = keys.original_damage
        end
    end
    
    -- Восстанавливаем здоровье
    local heal_amount = math.max(damage, 0) * (self.spell_lifesteal or 0) * 0.01
    keys.attacker:Heal(heal_amount, keys.attacker)
end