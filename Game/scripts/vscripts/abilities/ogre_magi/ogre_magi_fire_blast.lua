ogre_magi_fire_blast = class({})

function ogre_magi_fire_blast:OnSpellStart()
    local caster = self:GetCaster()
    local point = self:GetCursorPosition()
    local delay = self:GetSpecialValueFor("delay")

    -- Play cast sound
    EmitGlobalSound("Hero_OgreMagi.Fireblast.Cast")

    -- Create marker particle
    local marker_particle = ParticleManager:CreateParticle(
        "particles/items_fx/meteor_hammer_marker.vpcf",
        PATTACH_WORLDORIGIN,
        nil
    )
    ParticleManager:SetParticleControl(marker_particle, 0, point)
    ParticleManager:SetParticleControl(marker_particle, 1, Vector(self:GetSpecialValueFor("radius"), 0, 0))
    ParticleManager:ReleaseParticleIndex(marker_particle)

    -- Create timer for delayed effect
    Timers:CreateTimer(delay, function()
        self:OnDelayComplete(point)
    end)
end

function ogre_magi_fire_blast:OnDelayComplete(point)
    local caster = self:GetCaster()
    local radius = self:GetSpecialValueFor("radius")
    local damage = self:GetSpecialValueFor("damage")
    local stun_duration = self:GetSpecialValueFor("stun_duration")

    -- Play cast effect
    local cast_particle = ParticleManager:CreateParticle(
        "particles/items_fx/meteor_hammer_cast.vpcf",
        PATTACH_WORLDORIGIN,
        nil
    )
    ParticleManager:SetParticleControl(cast_particle, 0, point)
    ParticleManager:ReleaseParticleIndex(cast_particle)

    -- Play impact sound
    EmitGlobalSound("Hero_OgreMagi.Fireblast.Target")

    -- Find all units in radius
    local units = FindUnitsInRadius(
        caster:GetTeamNumber(),
        point,
        nil,
        radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )

    -- Play area effect
    local aoe_particle = ParticleManager:CreateParticle(
        "particles/items_fx/meteor_hammer_aoe.vpcf",
        PATTACH_WORLDORIGIN,
        nil
    )
    ParticleManager:SetParticleControl(aoe_particle, 0, point)
    ParticleManager:SetParticleControl(aoe_particle, 1, Vector(radius, 0, 0))
    ParticleManager:ReleaseParticleIndex(aoe_particle)

    -- Apply effects to all units
    for _, unit in pairs(units) do
        -- Apply damage
        local damageTable = {
            victim = unit,
            attacker = caster,
            damage = damage,
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
            { duration = stun_duration }
        )

        -- Play effects on each unit
        self:PlayEffects(unit)
    end
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
    return self:GetSpecialValueFor("radius")
end 