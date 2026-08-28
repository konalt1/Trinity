LinkLuaModifier("modifier_ogre_fire_blast_stun", "abilities/ogre_magi/ogre_magi_fire_blast", LUA_MODIFIER_MOTION_NONE)

ogre_magi_fire_blast = class({})

function ogre_magi_fire_blast:Precache(context)
    -- Precache particles that use models
    PrecacheResource("particle", "particles/units/heroes/hero_ogre_magi/ogre_bruiser_smash.vpcf", context)
    PrecacheResource("particle", "particles/neutral_fx/ogre_bruiser_smash.vpcf", context)
    PrecacheResource("particle", "particles/creatures/ogre/ogre_bruiser_smash.vpcf", context)
    PrecacheResource("particle", "particles/units/neutral_creeps/ogre_bruiser_smash.vpcf", context)
    
    -- Precache sounds
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_ogre_magi.vsndevts", context)
end

function ogre_magi_fire_blast:GetChannelTime()
    return self:GetSpecialValueFor("channel_time")
end

function ogre_magi_fire_blast:GetBehavior()
    return DOTA_ABILITY_BEHAVIOR_POINT + DOTA_ABILITY_BEHAVIOR_CHANNELLED
end

function ogre_magi_fire_blast:OnSpellStart()
    local caster = self:GetCaster()
    local target_point = self:GetCursorPosition()
    
    -- Store target point for later use
    self.target_point = target_point
    
    -- Play channeling sound (TO REPLACE: cast sound during channel)
    EmitSoundOn("Hero_OgreMagi.Fireblast.Cast", caster)
    
    -- Apply animation slow modifier
    caster:AddNewModifier(
        caster,
        self,
        "modifier_ogre_fire_blast_anim_slow",
        { duration = self:GetChannelTime() + 0.2 }
    )
    
    -- Show targeting indicator
    local marker_particle = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_ogre_magi/ogre_bruiser_smash.vpcf",
        PATTACH_WORLDORIGIN,
        nil
    )
    ParticleManager:SetParticleControl(marker_particle, 0, target_point)
    ParticleManager:SetParticleControl(marker_particle, 1, Vector(self:GetEffectiveRadius(), 0, 0))
    self.marker_particle = marker_particle
end

function ogre_magi_fire_blast:OnChannelFinish(bInterrupted)
    local caster = self:GetCaster()
    
    -- Clean up marker particle
    if self.marker_particle then
        ParticleManager:DestroyParticle(self.marker_particle, false)
        ParticleManager:ReleaseParticleIndex(self.marker_particle)
        self.marker_particle = nil
    end
    
    -- Stop channeling sound (TO REPLACE: stop cast sound)
    StopSoundOn("Hero_OgreMagi.Fireblast.Cast", caster)
    
    -- Remove animation slow modifier
    caster:RemoveModifierByName("modifier_ogre_fire_blast_anim_slow")
    
    -- If interrupted or cancelled, don't apply effects and refund mana/cooldown
    if bInterrupted then
        -- Refund mana cost
        local mana_cost = self:GetManaCost(self:GetLevel())
        caster:GiveMana(mana_cost)
        
        -- Refund cooldown
        self:EndCooldown()
        return
    end
    
    -- Small delay to sync with cast animation end
    Timers:CreateTimer(0.1, function()
        self:ExecuteSpell()
    end)
end

function ogre_magi_fire_blast:ExecuteSpell()
    local caster = self:GetCaster()
    local target_point = self.target_point
    local radius = self:GetEffectiveRadius()
    local base_damage = self:GetEffectiveDamage()
    local base_stun = self:GetSpecialValueFor("stun_duration")
    
    -- Create ground effect using neutral creep Ogre Bruiser effect (precached)
    local ground_particle = ParticleManager:CreateParticle(
        "particles/neutral_fx/ogre_bruiser_smash.vpcf",
        PATTACH_WORLDORIGIN,
        nil
    )
    
    if not ground_particle or ground_particle == 0 then
        ground_particle = ParticleManager:CreateParticle(
            "particles/units/heroes/hero_ogre_magi/ogre_magi_fireblast.vpcf",
            PATTACH_WORLDORIGIN,
            nil
        )
    end
    
    if ground_particle then
        ParticleManager:SetParticleControl(ground_particle, 0, target_point)
        ParticleManager:SetParticleControl(ground_particle, 1, Vector(radius, 0, 0))
        
        -- Let the particle play for its natural duration, then clean up
        Timers:CreateTimer(2.0, function()
            ParticleManager:DestroyParticle(ground_particle, false)
            ParticleManager:ReleaseParticleIndex(ground_particle)
        end)
    end
    
    -- Play impact sound (TO REPLACE: impact/smash sound)
    EmitSoundOnLocationWithCaster(target_point, "Hero_OgreMagi.Fireblast.Target", caster)
    
    -- Shard: Fire Blast пробивает БКБ
    local has_shard = caster:HasModifier("modifier_item_aghanims_shard")
    local unit_target_flags = has_shard and DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES or DOTA_UNIT_TARGET_FLAG_NONE

    -- Find all units in radius
    local units = FindUnitsInRadius(
        caster:GetTeamNumber(),
        target_point,
        nil,
        radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        unit_target_flags,
        FIND_ANY_ORDER,
        false
    )
    
    -- Apply effects with distance-based scaling
    for _, unit in pairs(units) do
        local distance = (unit:GetAbsOrigin() - target_point):Length2D()
        local distance_factor = math.max(0.3, 1 - (distance / radius)) -- Minimum 30% effect at edge
        
        -- Calculate scaled damage and stun
        local scaled_damage = base_damage * distance_factor
        local scaled_stun = base_stun * distance_factor
        
        -- Apply damage (Pure при шарде пробивает БКБ)
        local damage_type = has_shard and DAMAGE_TYPE_PURE or DAMAGE_TYPE_MAGICAL
        local damageTable = {
            victim = unit,
            attacker = caster,
            damage = scaled_damage,
            damage_type = damage_type,
            ability = self,
            damage_flags = DOTA_DAMAGE_FLAG_NONE
        }
        ApplyDamage(damageTable)
        
        -- Apply stun (кастомный модификатор при шарде пробивает БКБ)
        local stun_modifier = has_shard and "modifier_ogre_fire_blast_stun" or "modifier_stunned"
        unit:AddNewModifier(
            caster,
            self,
            stun_modifier,
            { duration = scaled_stun }
        )
        
        -- Remove individual unit effects - only ground effect now
        -- self:PlayEffects(unit)  -- Commented out
    end
end

function ogre_magi_fire_blast:GetEffectiveRadius()
    local caster = self:GetCaster()
    local base_radius = self:GetSpecialValueFor("radius")
    local strength_bonus = self:GetSpecialValueFor("strength_radius_bonus")
    
    local caster_strength = caster:GetStrength()
    local effective_radius = base_radius + (caster_strength * strength_bonus)
    
    return effective_radius
end

function ogre_magi_fire_blast:GetEffectiveDamage()
    local caster = self:GetCaster()
    local base_damage = self:GetSpecialValueFor("damage")
    local strength_bonus = self:GetSpecialValueFor("strength_damage_bonus")
    
    local caster_strength = caster:GetStrength()
    local effective_damage = base_damage + (caster_strength * strength_bonus)
    
    return effective_damage
end


function ogre_magi_fire_blast:PlayEffects(target)
    -- Get Resources
    local particle_cast = "particles/units/heroes/hero_ogre_magi/ogre_magi_fireblast.vpcf"
    local sound_target = "Hero_OgreMagi.Fireblast.Target"

    -- Create Particle
    local effect_cast = ParticleManager:CreateParticle(particle_cast, PATTACH_ABSORIGIN_FOLLOW, target)
    ParticleManager:SetParticleControlEnt(
        effect_cast,
        0,
        target,
        PATTACH_POINT_FOLLOW,
        "attach_hitloc",
        target:GetOrigin(),
        true
    )
    ParticleManager:ReleaseParticleIndex(effect_cast)

    -- Create Sound
    EmitSoundOn(sound_target, target)
end

function ogre_magi_fire_blast:GetCastRange(location, target)
    return self:GetSpecialValueFor("AbilityCastRange")
end

function ogre_magi_fire_blast:GetManaCost(level)
    return self.BaseClass.GetManaCost(self, level)
end

function ogre_magi_fire_blast:GetCooldown(level)
    return self.BaseClass.GetCooldown(self, level)
end

function ogre_magi_fire_blast:GetCastPoint()
    return self:GetSpecialValueFor("AbilityCastPoint")
end

function ogre_magi_fire_blast:GetAOERadius()
    return self:GetEffectiveRadius()
end

--------------------------------------------------------------------------------
-- Animation slow modifier
--------------------------------------------------------------------------------
modifier_ogre_fire_blast_anim_slow = class({})

function modifier_ogre_fire_blast_anim_slow:IsHidden()
    return true
end

function modifier_ogre_fire_blast_anim_slow:IsPurgable()
    return false
end

function modifier_ogre_fire_blast_anim_slow:GetModifierAnimationRate()
    return 0.1  -- 10% animation speed (very slow)
end

function modifier_ogre_fire_blast_anim_slow:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_ANIMATION_RATE
    }
end

--------------------------------------------------------------------------------
-- Custom stun modifier (Shard: пробивает БКБ)
--------------------------------------------------------------------------------
modifier_ogre_fire_blast_stun = class({})

function modifier_ogre_fire_blast_stun:IsHidden()
    return false
end

function modifier_ogre_fire_blast_stun:IsPurgable()
    return true
end

function modifier_ogre_fire_blast_stun:IsDebuff()
    return true
end

function modifier_ogre_fire_blast_stun:GetAttributes()
    return MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE
end

function modifier_ogre_fire_blast_stun:CheckState()
    return {
        [MODIFIER_STATE_STUNNED] = true,
    }
end

function modifier_ogre_fire_blast_stun:GetEffectName()
    return "particles/generic_gameplay/generic_stunned.vpcf"
end

function modifier_ogre_fire_blast_stun:GetEffectAttachType()
    return PATTACH_OVERHEAD_FOLLOW
end
