LinkLuaModifier('modifier_ogre_magi_ogres_roar_fear', 'abilities/ogre_magi/ogre_magi_ogres_roar', LUA_MODIFIER_MOTION_NONE)

ogre_magi_ogres_roar = class({})

function ogre_magi_ogres_roar:Precache(context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_ogre_magi.vsndevts", context)
    PrecacheResource("particle", "particles/units/heroes/hero_lone_druid/lone_druid_savage_roar.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_lone_druid/lone_druid_savage_roar_debuff.vpcf", context)
end

function ogre_magi_ogres_roar:GetAOERadius()
    return self:GetSpecialValueFor("radius")
end

function ogre_magi_ogres_roar:OnSpellStart()
    if not IsServer() then return end
    
    local caster = self:GetCaster()
    local radius = self:GetSpecialValueFor("radius")
    local angle = self:GetSpecialValueFor("angle")
    local base_fear_duration = self:GetSpecialValueFor("base_fear_duration")
    local fear_per_strength = self:GetSpecialValueFor("fear_per_strength")
    local strength_per_bonus = self:GetSpecialValueFor("strength_per_bonus")
    
    -- Вычисляем длительность страха на основе силы огра
    local total_strength = caster:GetStrength()
    local bonus_duration = (total_strength / strength_per_bonus) * fear_per_strength
    local fear_duration = base_fear_duration + bonus_duration
    
    -- Направление взгляда огра
    local forward = caster:GetForwardVector()
    local caster_origin = caster:GetAbsOrigin()
    
    -- Звук рыка
    EmitSoundOn("Hero_OgreMagi.Fireblast.Cast", caster)
    
    -- Визуальный эффект рыка
    local particle = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_lone_druid/lone_druid_savage_roar.vpcf",
        PATTACH_ABSORIGIN_FOLLOW,
        caster
    )
    ParticleManager:SetParticleControl(particle, 1, Vector(radius, 0, 0))
    ParticleManager:ReleaseParticleIndex(particle)
    
    -- Находим всех врагов в радиусе
    local enemies = FindUnitsInRadius(
        caster:GetTeamNumber(),
        caster_origin,
        nil,
        radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )
    
    -- Половина угла в радианах для проверки сектора
    local half_angle_rad = math.rad(angle / 2)
    
    for _, enemy in pairs(enemies) do
        if enemy and IsValidEntity(enemy) and enemy:IsAlive() then
            -- Проверяем, находится ли враг в секторе
            local direction_to_enemy = (enemy:GetAbsOrigin() - caster_origin):Normalized()
            direction_to_enemy.z = 0
            forward.z = 0
            
            local dot_product = forward:Dot(direction_to_enemy)
            local angle_to_enemy = math.acos(math.max(-1, math.min(1, dot_product)))
            
            -- Если враг в пределах угла сектора
            if angle_to_enemy <= half_angle_rad then
                -- Применяем страх
                enemy:AddNewModifier(
                    caster,
                    self,
                    "modifier_ogre_magi_ogres_roar_fear",
                    { duration = fear_duration }
                )
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Модификатор страха
modifier_ogre_magi_ogres_roar_fear = class({})

function modifier_ogre_magi_ogres_roar_fear:IsHidden()
    return false
end

function modifier_ogre_magi_ogres_roar_fear:IsPurgable()
    return true
end

function modifier_ogre_magi_ogres_roar_fear:IsDebuff()
    return true
end

function modifier_ogre_magi_ogres_roar_fear:GetEffectName()
    return "particles/units/heroes/hero_lone_druid/lone_druid_savage_roar_debuff.vpcf"
end

function modifier_ogre_magi_ogres_roar_fear:GetEffectAttachType()
    return PATTACH_OVERHEAD_FOLLOW
end

function modifier_ogre_magi_ogres_roar_fear:OnCreated(kv)
    if not IsServer() then return end
    
    local caster = self:GetCaster()
    local parent = self:GetParent()
    
    -- Запоминаем позицию кастера для направления бегства
    self.fear_source = caster:GetAbsOrigin()
    
    -- Звук страха на цели
    EmitSoundOn("Hero_LoneDruid.SavageRoar.Target", parent)
    
    -- Начинаем двигаться от источника страха
    self:StartIntervalThink(0.1)
end

function modifier_ogre_magi_ogres_roar_fear:OnIntervalThink()
    if not IsServer() then return end
    
    local parent = self:GetParent()
    
    if not parent:IsAlive() then
        return
    end
    
    -- Вычисляем направление от источника страха
    local direction = (parent:GetAbsOrigin() - self.fear_source):Normalized()
    direction.z = 0
    
    -- Если направление нулевое, выбираем случайное
    if direction:Length() < 0.01 then
        local random_angle = RandomFloat(0, 2 * math.pi)
        direction = Vector(math.cos(random_angle), math.sin(random_angle), 0)
    end
    
    -- Задаём движение в направлении от источника страха
    local move_speed = parent:GetMoveSpeedModifier(parent:GetBaseMoveSpeed(), false)
    local move_distance = move_speed * 0.1
    local target_position = parent:GetAbsOrigin() + direction * move_distance
    
    -- Проверяем, можно ли двигаться в эту точку
    parent:MoveToPosition(target_position)
end

function modifier_ogre_magi_ogres_roar_fear:OnDestroy()
    if not IsServer() then return end
    
    local parent = self:GetParent()
    
    -- Останавливаем принудительное движение
    parent:Stop()
end

function modifier_ogre_magi_ogres_roar_fear:CheckState()
    return {
        [MODIFIER_STATE_FEARED] = true,
        [MODIFIER_STATE_COMMAND_RESTRICTED] = true,
    }
end

function modifier_ogre_magi_ogres_roar_fear:DeclareFunctions()
    return {}
end

function modifier_ogre_magi_ogres_roar_fear:GetTexture()
    return "lone_druid_savage_roar"
end
