tusk_hello_world = class({})

function tusk_hello_world:OnSpellStart()
    if not IsServer() then return end
    -- OnSpellStart now just initiates channeling. Projectile launch is in OnChannelFinish.
end

function tusk_hello_world:OnChannelThink(flInterval)
    if not IsServer() then return end
    
    local caster = self:GetCaster()
    local target_point = self:GetCursorPosition()
    local direction_3d = (target_point - caster:GetAbsOrigin()):Normalized()
    -- Ensure direction is 2D (Z = 0) for CreateLinearProjectile
    local direction = Vector(direction_3d.x, direction_3d.y, 0):Normalized()
    local distance = (target_point - caster:GetAbsOrigin()):Length2D()
    
    -- Update the path indicator
    if self.path_particle then
        ParticleManager:DestroyParticle(self.path_particle, false)
    end
    
    -- Create a visual path indicator
    self.path_particle = ParticleManager:CreateParticle("particles/units/heroes/hero_tusk/tusk_ice_shards.vpcf", PATTACH_WORLDORIGIN, nil)
    ParticleManager:SetParticleControl(self.path_particle, 0, caster:GetAbsOrigin())
    
    -- Create multiple points along the path to show trajectory
    local num_points = 10
    for i = 1, num_points do
        local t = i / num_points
        local point = caster:GetAbsOrigin() + direction * (distance * t)
        ParticleManager:SetParticleControl(self.path_particle, i, point)
    end
end

function tusk_hello_world:OnChannelFinish(bInterrupted)
    if not IsServer() then return end
    
    local caster = self:GetCaster()
    
    -- Clean up path indicator
    if self.path_particle then
        ParticleManager:DestroyParticle(self.path_particle, false)
        self.path_particle = nil
    end
    
    if bInterrupted then
        -- Ability was interrupted, don't launch projectile
        return
    end
    
    -- Launch the projectile when channeling completes
    local target_point = self:GetCursorPosition()
    local direction_3d = (target_point - caster:GetAbsOrigin()):Normalized()
    -- Ensure direction is 2D (Z = 0) for CreateLinearProjectile
    local direction = Vector(direction_3d.x, direction_3d.y, 0):Normalized()
    local distance = (target_point - caster:GetAbsOrigin()):Length2D()
    
    -- Create projectile info
    local projectile_info = {
        Ability = self,
        EffectName = "particles/units/heroes/hero_tusk/tusk_ice_shards_projectile.vpcf",
        vSpawnOrigin = caster:GetAbsOrigin(),
        fDistance = distance,
        fStartRadius = 100,
        fEndRadius = 100,
        Source = caster,
        bHasFrontalCone = false,
        bReplaceExisting = false,
        iUnitTargetTeam = DOTA_UNIT_TARGET_TEAM_ENEMY,
        iUnitTargetFlags = DOTA_UNIT_TARGET_FLAG_NONE,
        iUnitTargetType = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        fExpireTime = GameRules:GetGameTime() + 10.0,
        bDeleteOnHit = true,
        vVelocity = direction * 1200,
        bProvidesVision = true,
        iVisionRadius = 300,
        iVisionTeamNumber = caster:GetTeamNumber(),
        ExtraData = {
            damage = self:GetSpecialValueFor("damage"),
            radius = self:GetSpecialValueFor("radius")
        }
    }
    
    -- Create the projectile
    ProjectileManager:CreateLinearProjectile(projectile_info)
    
    -- Play sound effect
    EmitSoundOn("Hero_Tusk.IceShards", caster)
    
    -- Create launch particle effect
    local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_tusk/tusk_ice_shards.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
    ParticleManager:ReleaseParticleIndex(particle)
end

function tusk_hello_world:OnChannelInterrupted()
    if not IsServer() then return end
    
    -- Clean up path indicator when interrupted
    if self.path_particle then
        ParticleManager:DestroyParticle(self.path_particle, false)
        self.path_particle = nil
    end
end

function tusk_hello_world:OnProjectileHit(target, location)
    if not target then return false end
    
    local caster = self:GetCaster()
    local damage = self:GetSpecialValueFor("damage")
    local radius = self:GetSpecialValueFor("radius")
    
    -- Deal damage to the target
    local damage_table = {
        victim = target,
        attacker = caster,
        damage = damage,
        damage_type = DAMAGE_TYPE_MAGICAL,
        ability = self
    }
    
    ApplyDamage(damage_table)
    
    -- Create explosion effect at hit location
    local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_tusk/tusk_ice_shards.vpcf", PATTACH_WORLDORIGIN, nil)
    ParticleManager:SetParticleControl(particle, 0, location)
    ParticleManager:ReleaseParticleIndex(particle)
    
    -- Play hit sound
    EmitSoundOn("Hero_Tusk.IceShards", target)
    
    -- Print hello world message
    print("Hello World! Projectile hit " .. target:GetUnitName())
    
    return true -- Destroy the projectile
end

function tusk_hello_world:GetCastRange(location, target)
    return 1200
end

function tusk_hello_world:GetCooldown(level)
    return 15.0
end

function tusk_hello_world:GetManaCost(level)
    return 100
end
