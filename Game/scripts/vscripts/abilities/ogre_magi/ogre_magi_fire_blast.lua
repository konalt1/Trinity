ogre_magi_fire_blast = class({})

function ogre_magi_fire_blast:Precache(context)
    -- Precache particles that use models
    PrecacheResource("particle", "particles/units/heroes/hero_ogre_magi/ogre_bruiser_smash.vpcf", context)
    PrecacheResource("particle", "particles/neutral_fx/ogre_bruiser_smash.vpcf", context)
    PrecacheResource("particle", "particles/creatures/ogre/ogre_bruiser_smash.vpcf", context)
    PrecacheResource("particle", "particles/units/neutral_creeps/ogre_bruiser_smash.vpcf", context)
    
    -- Precache sounds
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_ogre_magi.vsndevts", context)
    
    print("[DEBUG] Precached ogre_bruiser_smash particles and sounds")
end

function ogre_magi_fire_blast:GetChannelTime()
    local channel_time = self:GetSpecialValueFor("channel_time")
    print("[DEBUG] GetChannelTime: " .. tostring(channel_time))
    return channel_time
end

function ogre_magi_fire_blast:GetBehavior()
    return DOTA_ABILITY_BEHAVIOR_POINT + DOTA_ABILITY_BEHAVIOR_CHANNELLED
end

function ogre_magi_fire_blast:OnSpellStart()
    local caster = self:GetCaster()
    local target_point = self:GetCursorPosition()
    
    print("[DEBUG] Fire Blast OnSpellStart called")
    print("[DEBUG] Target point: " .. tostring(target_point))
    print("[DEBUG] Effective radius: " .. tostring(self:GetEffectiveRadius()))
    
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
    
    print("[DEBUG] Marker particle created: " .. tostring(marker_particle))
end

function ogre_magi_fire_blast:OnChannelFinish(bInterrupted)
    local caster = self:GetCaster()
    
    print("[DEBUG] OnChannelFinish called, interrupted: " .. tostring(bInterrupted))
    print("[DEBUG] Channel time was: " .. tostring(self:GetChannelTime()))
    
    -- Clean up marker particle
    if self.marker_particle then
        ParticleManager:DestroyParticle(self.marker_particle, false)
        ParticleManager:ReleaseParticleIndex(self.marker_particle)
        self.marker_particle = nil
        print("[DEBUG] Marker particle cleaned up")
    end
    
    -- Stop channeling sound (TO REPLACE: stop cast sound)
    StopSoundOn("Hero_OgreMagi.Fireblast.Cast", caster)
    
    -- Remove animation slow modifier
    caster:RemoveModifierByName("modifier_ogre_fire_blast_anim_slow")
    
    -- If interrupted or cancelled, don't apply effects and refund mana/cooldown
    if bInterrupted then
        print("[DEBUG] Spell interrupted, refunding resources")
        -- Refund mana cost
        local mana_cost = self:GetManaCost(self:GetLevel())
        caster:GiveMana(mana_cost)
        
        -- Refund cooldown
        self:EndCooldown()
        return
    end
    
    print("[DEBUG] Executing spell effect")
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
    
    print("[DEBUG] ExecuteSpell - target_point: " .. tostring(target_point))
    print("[DEBUG] ExecuteSpell - radius: " .. tostring(radius))
    print("[DEBUG] ExecuteSpell - base_damage: " .. tostring(base_damage))
    print("[DEBUG] ExecuteSpell - base_stun: " .. tostring(base_stun))
    
    -- Create ground effect using neutral creep Ogre Bruiser effect (precached)
    local ground_particle = ParticleManager:CreateParticle(
        "particles/neutral_fx/ogre_bruiser_smash.vpcf",
        PATTACH_WORLDORIGIN,
        nil
    )
    
    print("[DEBUG] Attempted to create ogre_bruiser_smash particle: " .. tostring(ground_particle))
    
    if not ground_particle or ground_particle == 0 then
        print("[DEBUG] Ogre bruiser effect failed, using standard fireblast")
        ground_particle = ParticleManager:CreateParticle(
            "particles/units/heroes/hero_ogre_magi/ogre_magi_fireblast.vpcf",
            PATTACH_WORLDORIGIN,
            nil
        )
    end
    
    print("[DEBUG] Final ground particle: " .. tostring(ground_particle))
    
    if ground_particle then
        ParticleManager:SetParticleControl(ground_particle, 0, target_point)
        ParticleManager:SetParticleControl(ground_particle, 1, Vector(radius, 0, 0))
        
        -- Let the particle play for its natural duration, then clean up
        Timers:CreateTimer(2.0, function()
            ParticleManager:DestroyParticle(ground_particle, false)
            ParticleManager:ReleaseParticleIndex(ground_particle)
        end)
        
        print("[DEBUG] Ground effect created and will auto-cleanup in 2 seconds")
    else
        print("[DEBUG] Failed to create any ground particle")
    end
    
    print("[DEBUG] Ground particle created: " .. tostring(ground_particle))
    
    -- Play impact sound (TO REPLACE: impact/smash sound)
    EmitGlobalSound("Hero_OgreMagi.Fireblast.Target")
    
    -- Find all units in radius
    local units = FindUnitsInRadius(
        caster:GetTeamNumber(),
        target_point,
        nil,
        radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )
    
    print("[DEBUG] Found " .. tostring(#units) .. " units in radius")
    
    -- Apply effects with distance-based scaling
    for _, unit in pairs(units) do
        local distance = (unit:GetAbsOrigin() - target_point):Length2D()
        local distance_factor = math.max(0.3, 1 - (distance / radius)) -- Minimum 30% effect at edge
        
        -- Calculate scaled damage and stun
        local scaled_damage = base_damage * distance_factor
        local scaled_stun = base_stun * distance_factor
        
        print("[DEBUG] Unit: " .. unit:GetUnitName() .. ", distance: " .. tostring(distance) .. ", factor: " .. tostring(distance_factor))
        print("[DEBUG] Scaled damage: " .. tostring(scaled_damage) .. ", scaled stun: " .. tostring(scaled_stun))
        
        -- Apply damage
        local damageTable = {
            victim = unit,
            attacker = caster,
            damage = scaled_damage,
            damage_type = DAMAGE_TYPE_MAGICAL,
            ability = self,
            damage_flags = DOTA_DAMAGE_FLAG_NONE
        }
        ApplyDamage(damageTable)
        
        -- Apply stun
        unit:AddNewModifier(
            caster,
            self,
            "modifier_stunned",
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
    
    print("[DEBUG] GetEffectiveRadius - base: " .. tostring(base_radius) .. ", strength: " .. tostring(caster_strength) .. ", bonus: " .. tostring(strength_bonus) .. ", result: " .. tostring(effective_radius))
    
    return effective_radius
end

function ogre_magi_fire_blast:GetEffectiveDamage()
    local caster = self:GetCaster()
    local base_damage = self:GetSpecialValueFor("damage")
    local strength_bonus = self:GetSpecialValueFor("strength_damage_bonus")
    
    local caster_strength = caster:GetStrength()
    local effective_damage = base_damage + (caster_strength * strength_bonus)
    
    print("[DEBUG] GetEffectiveDamage - base: " .. tostring(base_damage) .. ", strength: " .. tostring(caster_strength) .. ", bonus: " .. tostring(strength_bonus) .. ", result: " .. tostring(effective_damage))
    
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
