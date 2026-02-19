LinkLuaModifier('modifier_ogre_magi_ogres_roar_fear', 'abilities/ogre_magi/ogre_magi_ogres_roar', LUA_MODIFIER_MOTION_NONE)

ogre_magi_ogres_roar = class({})

function ogre_magi_ogres_roar:Precache(context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_ogre_magi.vsndevts", context)
    PrecacheResource("particle", "particles/units/heroes/hero_beastmaster/beastmaster_primal_roar.vpcf", context)
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
    
    -- Визуальный эффект рыка (Beastmaster Primal Roar) — цель впереди кастера по направлению взгляда
    local particle = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_beastmaster/beastmaster_primal_roar.vpcf",
        PATTACH_ABSORIGIN_FOLLOW,
        caster
    )
    local target_point = caster_origin + forward * radius
    ParticleManager:SetParticleControl(particle, 1, target_point)
    ParticleManager:ReleaseParticleIndex(particle)
    
    -- Находим всех врагов в радиусе (герои и крипы)
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
    -- Копия направления в плоскости X/Y (не мутируем исходный forward)
    local forward_flat = Vector(forward.x, forward.y, 0)
    local forward_flat_len = forward_flat:Length()
    if forward_flat_len > 0.0001 then
        forward_flat = forward_flat / forward_flat_len
    else
        forward_flat = Vector(1, 0, 0) -- кастер смотрит вверх/вниз — берём произвольное направление
    end
    
    for _, enemy in pairs(enemies) do
        if enemy and IsValidEntity(enemy) and enemy:IsAlive() then
            -- Проверяем, находится ли враг в секторе (2D, нормализованные векторы)
            local to_enemy = enemy:GetAbsOrigin() - caster_origin
            to_enemy.z = 0
            local len = to_enemy:Length()
            if len < 0.0001 then
                goto continue
            end
            local direction_to_enemy = to_enemy / len
            
            local dot_product = forward_flat:Dot(direction_to_enemy)
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
            ::continue::
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
    -- Запоминаем позицию кастера для направления бегства (если кастера нет — используем позицию цели, чтобы не падать в OnIntervalThink)
    self.fear_source = caster and caster:GetAbsOrigin() or parent:GetAbsOrigin()
    
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
    
    -- Вычисляем направление от источника страха (проверка до Normalized — иначе нулевой вектор даёт ошибку)
    local to_source = parent:GetAbsOrigin() - self.fear_source
    to_source.z = 0
    local len = to_source:Length()
    local direction
    if len < 0.01 then
        local random_angle = RandomFloat(0, 2 * math.pi)
        direction = Vector(math.cos(random_angle), math.sin(random_angle), 0)
    else
        direction = to_source / len
    end
    
    -- Задаём движение в направлении от источника страха (работает для героев и крипов).
    -- API (moddota.com): у CDOTA_BaseNPC нет GetMoveSpeed(); GetIdealSpeed() — текущая скорость с учётом модификаторов.
    local move_speed = parent:GetIdealSpeed()
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
