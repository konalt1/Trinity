-- Phantom Assassin Phantom Cloud (Aghanim's Shard ability)
-- Creates a cloud that grants unrevealable invisibility to PA and allies

--------------------------------------------------------------------------------
phantom_assassin_phantom_cloud = class({})
LinkLuaModifier("modifier_phantom_assassin_phantom_cloud_thinker", "abilities/phantom_assassin/phantom_assassin_phantom_cloud", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_phantom_assassin_phantom_cloud_invis", "abilities/phantom_assassin/phantom_assassin_phantom_cloud", LUA_MODIFIER_MOTION_NONE)

--------------------------------------------------------------------------------
-- Precache
function phantom_assassin_phantom_cloud:Precache(context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_phantom_assassin.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_slark.vsndevts", context)
    PrecacheResource("particle", "particles/units/heroes/hero_phantom_assassin/phantom_assassin_blur.vpcf", context)
    PrecacheResource("particle", "particles/units/heroes/hero_slark/slark_shard_depth_shroud.vpcf", context)
    PrecacheResource("particle", "particles/generic_gameplay/generic_smoke.vpcf", context)
end

--------------------------------------------------------------------------------
-- Ability Start
function phantom_assassin_phantom_cloud:OnSpellStart()
    if not IsServer() then return end
    
    local caster = self:GetCaster()
    local duration = self:GetSpecialValueFor("duration")
    
    -- Create modifier thinker at caster position
    CreateModifierThinker(
        caster,
        self,
        "modifier_phantom_assassin_phantom_cloud_thinker",
        { duration = duration },
        caster:GetOrigin(),
        caster:GetTeamNumber(),
        false
    )
    
    -- Play cast sound
    EmitSoundOn("Hero_PhantomAssassin.Blur", caster)
end

--------------------------------------------------------------------------------
-- Thinker Modifier (the cloud itself)
--------------------------------------------------------------------------------
modifier_phantom_assassin_phantom_cloud_thinker = class({})

function modifier_phantom_assassin_phantom_cloud_thinker:IsHidden()
    return true
end

function modifier_phantom_assassin_phantom_cloud_thinker:IsDebuff()
    return false
end

function modifier_phantom_assassin_phantom_cloud_thinker:IsPurgable()
    return false
end

function modifier_phantom_assassin_phantom_cloud_thinker:RemoveOnDeath()
    return true
end

function modifier_phantom_assassin_phantom_cloud_thinker:OnCreated(kv)
    if not IsServer() then return end
    
    self.ability = self:GetAbility()
    self.parent = self:GetParent()
    self.caster = self.ability:GetCaster()
    self.radius = self.ability:GetSpecialValueFor("radius")
    self.duration = kv.duration or self.ability:GetSpecialValueFor("duration")
    
    -- Store cloud origin
    self.cloud_origin = self.parent:GetOrigin()
    
    -- Set duration
    self:SetDuration(self.duration, false)
    
    -- Create visual effects
    self:CreateCloudEffects()
    
    -- Start thinking to apply/remove invisibility
    self:StartIntervalThink(0.1)
end

function modifier_phantom_assassin_phantom_cloud_thinker:OnIntervalThink()
    if not IsServer() then return end
    
    -- Find all friendly units in radius
    local units = FindUnitsInRadius(
        self.caster:GetTeamNumber(),
        self.cloud_origin,
        nil,
        self.radius,
        DOTA_UNIT_TARGET_TEAM_FRIENDLY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )
    
    -- Create a set of units currently in cloud
    local units_in_cloud = {}
    for _, unit in pairs(units) do
        units_in_cloud[unit:entindex()] = true
        
        -- Apply invisibility if not already have it
        if not unit:HasModifier("modifier_phantom_assassin_phantom_cloud_invis") then
            unit:AddNewModifier(
                self.caster,
                self.ability,
                "modifier_phantom_assassin_phantom_cloud_invis",
                { cloud_thinker = self.parent:entindex() }
            )
        end
    end
    
    -- Store for cleanup
    self.units_in_cloud = units_in_cloud
end

function modifier_phantom_assassin_phantom_cloud_thinker:OnDestroy()
    if not IsServer() then return end
    
    -- Clean up particles
    if self.cloud_particle then
        ParticleManager:DestroyParticle(self.cloud_particle, false)
        ParticleManager:ReleaseParticleIndex(self.cloud_particle)
    end
    
    -- Remove invisibility from all affected units
    local all_units = FindUnitsInRadius(
        self.caster:GetTeamNumber(),
        self.cloud_origin,
        nil,
        self.radius + 100, -- Slightly larger to catch edge cases
        DOTA_UNIT_TARGET_TEAM_FRIENDLY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )
    
    for _, unit in pairs(all_units) do
        local invis_modifier = unit:FindModifierByName("modifier_phantom_assassin_phantom_cloud_invis")
        if invis_modifier and invis_modifier.cloud_thinker == self.parent:entindex() then
            invis_modifier:Destroy()
        end
    end
    
    -- Remove thinker
    UTIL_Remove(self.parent)
end

function modifier_phantom_assassin_phantom_cloud_thinker:CreateCloudEffects()
    if not IsServer() then return end
    
    -- Main cloud effect (using Slark's Depth Shroud particle)
    self.cloud_particle = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_slark/slark_shard_depth_shroud.vpcf",
        PATTACH_WORLDORIGIN,
        nil
    )
    ParticleManager:SetParticleControl(self.cloud_particle, 0, self.cloud_origin)
    ParticleManager:SetParticleControl(self.cloud_particle, 1, Vector(self.radius, self.radius, self.radius))
    ParticleManager:SetParticleControl(self.cloud_particle, 2, Vector(self.duration, 0, 0))
end

--------------------------------------------------------------------------------
-- Invisibility Modifier (applied to units in cloud)
--------------------------------------------------------------------------------
modifier_phantom_assassin_phantom_cloud_invis = class({})

function modifier_phantom_assassin_phantom_cloud_invis:IsHidden()
    return false
end

function modifier_phantom_assassin_phantom_cloud_invis:IsDebuff()
    return false
end

function modifier_phantom_assassin_phantom_cloud_invis:IsPurgable()
    return false -- Cannot be dispelled
end

function modifier_phantom_assassin_phantom_cloud_invis:IsPurgeException()
    return false -- Cannot be purged even by strong dispels
end

function modifier_phantom_assassin_phantom_cloud_invis:RemoveOnDeath()
    return true
end

function modifier_phantom_assassin_phantom_cloud_invis:GetAttributes()
    return MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE
end

function modifier_phantom_assassin_phantom_cloud_invis:OnCreated(kv)
    if not IsServer() then return end
    
    self.ability = self:GetAbility()
    self.parent = self:GetParent()
    self.cloud_thinker = kv.cloud_thinker
    
    -- Get cloud properties
    if self.ability then
        self.radius = self.ability:GetSpecialValueFor("radius")
    else
        self.radius = 200
    end
    
    -- Find the thinker to get cloud origin
    self.thinker_ent = EntIndexToHScript(self.cloud_thinker)
    if self.thinker_ent then
        self.cloud_origin = self.thinker_ent:GetOrigin()
    else
        self.cloud_origin = self.parent:GetOrigin()
    end
    
    -- Start checking if unit left the cloud
    self:StartIntervalThink(0.1)
end

function modifier_phantom_assassin_phantom_cloud_invis:OnIntervalThink()
    if not IsServer() then return end
    
    -- Check if thinker still exists
    if not self.thinker_ent or self.thinker_ent:IsNull() then
        self:Destroy()
        return
    end
    
    -- Check if unit is still inside cloud radius
    local distance = (self.parent:GetOrigin() - self.cloud_origin):Length2D()
    if distance > self.radius then
        -- Unit left the cloud - instantly remove invisibility
        self:Destroy()
    end
end

function modifier_phantom_assassin_phantom_cloud_invis:CheckState()
    return {
        [MODIFIER_STATE_INVISIBLE] = true,
        [MODIFIER_STATE_TRUESIGHT_IMMUNE] = true, -- Cannot be revealed by True Sight
    }
end

function modifier_phantom_assassin_phantom_cloud_invis:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_INVISIBILITY_LEVEL,
    }
end

function modifier_phantom_assassin_phantom_cloud_invis:GetModifierInvisibilityLevel()
    return 1
end

function modifier_phantom_assassin_phantom_cloud_invis:GetEffectName()
    return "particles/generic_gameplay/generic_smoke.vpcf"
end

function modifier_phantom_assassin_phantom_cloud_invis:GetEffectAttachType()
    return PATTACH_ABSORIGIN_FOLLOW
end

function modifier_phantom_assassin_phantom_cloud_invis:GetTexture()
    return "phantom_assassin_blur"
end
