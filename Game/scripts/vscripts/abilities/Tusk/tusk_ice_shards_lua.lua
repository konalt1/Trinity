tusk_ice_shards_lua = class({})

function tusk_ice_shards_lua:OnSpellStart()
    if not IsServer() then return end
    
    local caster = self:GetCaster()
    local target_point = self:GetCursorPosition()
    local caster_position = caster:GetAbsOrigin()
    
    -- Get ability values
    local shard_damage = self:GetSpecialValueFor("shard_damage")
    local shard_slow = self:GetSpecialValueFor("shard_slow")
    local shard_count = self:GetSpecialValueFor("shard_count")
    local shard_speed = self:GetSpecialValueFor("shard_speed")
    local shard_duration = self:GetSpecialValueFor("shard_duration")
    local shard_slow_duration = self:GetSpecialValueFor("shard_slow_duration")
    local shard_width = self:GetSpecialValueFor("shard_width")
    local mind_power_multiplier = self:GetSpecialValueFor("mind_power_multiplier")
    
    -- Calculate Mind Power bonus damage
    local mind_power = GetHeroMindPower(caster)
    local bonus_damage = mind_power * mind_power_multiplier
    local total_damage = math.max(0, shard_damage + bonus_damage)
    
    -- Calculate direction and distance (ensure 2D)
    local direction = (target_point - caster_position):Normalized()
    direction.z = 0  -- Zero out the Z component
    direction = direction:Normalized()  -- Re-normalize after zeroing Z
    
    local cast_range = self:GetCastRange(target_point, nil)
    local distance = math.min((target_point - caster_position):Length2D(), cast_range)
    
    -- Create projectile with 2D velocity
    local projectile_velocity = direction * shard_speed
    
    local info = {
        Ability = self,
        EffectName = "particles/units/heroes/hero_tusk/tusk_ice_shards_projectile.vpcf",
        vSpawnOrigin = caster_position,
        fDistance = distance,
        fStartRadius = shard_width,
        fEndRadius = shard_width,
        Source = caster,
        bHasFrontalCone = false,
        bReplaceExisting = false,
        iUnitTargetTeam = DOTA_UNIT_TARGET_TEAM_ENEMY,
        iUnitTargetFlags = DOTA_UNIT_TARGET_FLAG_NONE,
        iUnitTargetType = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        fExpireTime = GameRules:GetGameTime() + 10.0,
        bDeleteOnHit = false,
        vVelocity = projectile_velocity,
        bProvidesVision = false,
        ExtraData = {
            total_damage = total_damage,
            shard_slow = shard_slow,
            shard_slow_duration = shard_slow_duration,
            shard_duration = shard_duration,
            shard_count = shard_count,
            direction_x = direction.x,
            direction_y = direction.y
        }
    }
    
    ProjectileManager:CreateLinearProjectile(info)
    
    -- Play sound
    EmitSoundOn("Hero_Tusk.IceShards.Cast", caster)
end

function tusk_ice_shards_lua:OnProjectileHit_ExtraData(target, location, extraData)
    if not IsServer() then return end
    
    local caster = self:GetCaster()
    local total_damage = extraData.total_damage
    local shard_slow = extraData.shard_slow
    local shard_slow_duration = extraData.shard_slow_duration
    local shard_duration = extraData.shard_duration
    local shard_count = extraData.shard_count
    local direction = Vector(extraData.direction_x, extraData.direction_y, 0)
    
    if target then
        -- Deal damage to target
        ApplyDamage({
            victim = target,
            attacker = caster,
            damage = total_damage,
            damage_type = DAMAGE_TYPE_MAGICAL,
            ability = self
        })
        
        -- Apply slow debuff
        target:AddNewModifier(caster, self, "modifier_tusk_ice_shards_lua_slow", {duration = shard_slow_duration})
        
        -- Play impact sound
        EmitSoundOn("Hero_Tusk.IceShards.ImpactTarget", target)
    end
    
    if location then
        -- Create ice shards at the hit location
        self:CreateIceShards(location, shard_count, shard_duration, direction)
        
        -- Play impact sound
        EmitSoundOnLocationWithCaster(location, "Hero_Tusk.IceShards.Projectile", caster)
    end
    
    return false
end

function tusk_ice_shards_lua:CreateIceShards(center_point, shard_count, duration, direction)
    local shard_width = self:GetSpecialValueFor("shard_width")
    
    -- Calculate perpendicular vector for the sides of the C shape
    local perp_vector = Vector(-direction.y, direction.x, 0)
    
    -- Parameters for C shape
    local c_width = shard_count * shard_width * 0.5  -- Total width of the C shape
    local c_depth = c_width * 0.5  -- How far back the sides go
    
    -- Create the bottom part of C
    local bottom_start = center_point - perp_vector * c_width
    local shards_per_side = math.floor(shard_count / 3)  -- Divide shards between bottom, right, and left sides
    
    -- Bottom line of the C
    for i = 0, shards_per_side - 1 do
        local shard_position = bottom_start + perp_vector * (i * shard_width * 2)
        self:CreateSingleShard(shard_position, duration)
    end
    
    -- Right side of the C
    local right_start = center_point + perp_vector * c_width
    for i = 0, shards_per_side - 1 do
        local shard_position = right_start - direction * (i * shard_width * 2)
        self:CreateSingleShard(shard_position, duration)
    end
    
    -- Left side of the C
    local left_start = bottom_start
    for i = 0, shards_per_side - 1 do
        local shard_position = left_start - direction * (i * shard_width * 2)
        self:CreateSingleShard(shard_position, duration)
    end
end

function tusk_ice_shards_lua:CreateSingleShard(position, duration)
    -- Create invisible wall unit
    local wall = CreateUnitByName("npc_dota_tusk_ice_shard_blocker", position, false, nil, nil, DOTA_TEAM_NEUTRALS)
    if wall then
        wall:SetAbsOrigin(position)
        wall:AddNewModifier(wall, self, "modifier_tusk_ice_shards_lua_blocker", {duration = duration})
        
        -- Create visual effect for the ice shard
        local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_tusk/tusk_ice_shards.vpcf", PATTACH_ABSORIGIN, wall)
        ParticleManager:SetParticleControl(particle, 0, position)
        ParticleManager:SetParticleControl(particle, 1, position)
        
        -- Store particle index in the wall entity for cleanup
        wall.particle_index = particle
    end
end

-- Slow modifier
modifier_tusk_ice_shards_lua_slow = class({})

function modifier_tusk_ice_shards_lua_slow:IsDebuff()
    return true
end

function modifier_tusk_ice_shards_lua_slow:IsPurgable()
    return true
end

function modifier_tusk_ice_shards_lua_slow:GetEffectName()
    return "particles/units/heroes/hero_tusk/tusk_ice_shards_debuff.vpcf"
end

function modifier_tusk_ice_shards_lua_slow:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE
    }
end

function modifier_tusk_ice_shards_lua_slow:GetModifierMoveSpeedBonus_Percentage()
    return -self:GetAbility():GetSpecialValueFor("shard_slow")
end

-- Blocker modifier for ice shards
modifier_tusk_ice_shards_lua_blocker = class({})

function modifier_tusk_ice_shards_lua_blocker:IsHidden()
    return true
end

function modifier_tusk_ice_shards_lua_blocker:IsPurgable()
    return false
end

function modifier_tusk_ice_shards_lua_blocker:CheckState()
    return {
        [MODIFIER_STATE_UNSELECTABLE] = true,
        [MODIFIER_STATE_INVULNERABLE] = true,
        [MODIFIER_STATE_NOT_ON_MINIMAP] = true,
        [MODIFIER_STATE_NO_HEALTH_BAR] = true,
        [MODIFIER_STATE_BLOCK_DISABLED] = true,
        [MODIFIER_STATE_FLYING_FOR_PATHING_PURPOSES_ONLY] = true
    }
end

function modifier_tusk_ice_shards_lua_blocker:OnDestroy()
    if IsServer() then
        -- Clean up the particle when the wall is destroyed
        if self:GetParent().particle_index then
            ParticleManager:DestroyParticle(self:GetParent().particle_index, false)
            ParticleManager:ReleaseParticleIndex(self:GetParent().particle_index)
        end
        
        -- Remove the wall unit
        self:GetParent():RemoveSelf()
    end
end 