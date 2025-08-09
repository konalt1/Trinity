require('utils/util')

tusk_mp_snowball = class({})

-- Register modifiers
LinkLuaModifier("modifier_tusk_snowball_formation", "Tusk/tusk_mp_snowball", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_tusk_snowball_pickup", "Tusk/tusk_mp_snowball", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_tusk_snowball_movement", "Tusk/tusk_mp_snowball", LUA_MODIFIER_MOTION_NONE)

function tusk_mp_snowball:IsStealable()
    return true
end

function tusk_mp_snowball:IsHiddenWhenStolen()
    return false
end

function tusk_mp_snowball:OnSpellStart()
    local caster = self:GetCaster()
    local target = self:GetCursorTarget()
    
    if not target or not IsValidEntity(target) or not target:IsAlive() then
        return
    end

    -- Store snowball state
    self.snowball_target = target
    self.snowball_allies = {}
    self.is_forming = true
    self.formation_start_time = GameRules:GetGameTime()
    self.formation_time = self:GetSpecialValueFor("formation_time")
    
    -- Add caster to snowball
    table.insert(self.snowball_allies, caster)
    
    -- Hide Tusk model and make invulnerable
    caster:AddNoDraw()
    caster:AddNewModifier(caster, self, "modifier_tusk_snowball_formation", {duration = self.formation_time + 1.0})
    
    -- Create snowball model entity using prop_dynamic for better reliability
    self.snowball_entity = SpawnEntityFromTableSynchronous("prop_dynamic", {
        model = "models/snowball.vmdl",
        origin = caster:GetAbsOrigin(),
        ModelScale = 1.0,
    })
    
    -- Alternative: Try creating a unit if prop fails
    if not self.snowball_entity or not IsValidEntity(self.snowball_entity) then
        self.snowball_entity = CreateUnitByName("npc_dummy_unit", caster:GetAbsOrigin(), false, caster, caster, caster:GetTeamNumber())
        if self.snowball_entity and IsValidEntity(self.snowball_entity) then
            self.snowball_entity:SetModel("models/snowball.vmdl")
            self.snowball_entity:SetModelScale(1.0)
            self.snowball_entity:AddNewModifier(caster, self, "modifier_phased", {})
            self.snowball_entity:AddNewModifier(caster, self, "modifier_invulnerable", {})
        else
            -- Final fallback: No snowball model, just use particles
            print("[Tusk Snowball] Warning: Could not create snowball model entity")
            self.snowball_entity = nil
        end
    end
    
    -- Start snowball formation sound and particle
    EmitSoundOn("Hero_Tusk.Snowball.Cast", caster)
    
    -- Create snowball formation particle
    self.formation_particle = ParticleManager:CreateParticle("particles/units/heroes/hero_tusk/tusk_snowball.vpcf", PATTACH_ABSORIGIN_FOLLOW, self.snowball_entity or caster)
    
    -- Make allies near caster able to join snowball
    self:SetupAllyJoining()
    
    -- Create formation timer
    self.formation_timer = Timers:CreateTimer(self.formation_time, function()
        if self.is_forming then
            self:LaunchSnowball()
        end
    end)
    
    -- Enable manual launch by pressing W again
    caster:SwapAbilities("tusk_mp_snowball", "tusk_mp_snowball_launch", false, true)
end

function tusk_mp_snowball:SetupAllyJoining()
    local caster = self:GetCaster()
    local pickup_radius = self:GetSpecialValueFor("ally_pickup_radius")
    
    local allies = FindUnitsInRadius(
        caster:GetTeamNumber(),
        caster:GetAbsOrigin(),
        nil,
        pickup_radius,
        DOTA_UNIT_TARGET_TEAM_FRIENDLY,
        DOTA_UNIT_TARGET_HERO,
        DOTA_UNIT_TARGET_FLAG_NOT_ILLUSIONS,
        FIND_ANY_ORDER,
        false
    )
    
    for _, ally in pairs(allies) do
        if ally ~= caster and ally:IsHero() and ally:IsAlive() then
            -- Add modifier to allow allies to right-click to join
            ally:AddNewModifier(caster, self, "modifier_tusk_snowball_pickup", {duration = self.formation_time + 1.0})
        end
    end
end

function tusk_mp_snowball:LaunchSnowball()
    if not self.is_forming then
        return
    end
    
    local caster = self:GetCaster()
    
    -- Clean up formation
    self.is_forming = false
    if self.formation_timer then
        Timers:RemoveTimer(self.formation_timer)
        self.formation_timer = nil
    end
    
    if self.formation_particle then
        ParticleManager:DestroyParticle(self.formation_particle, false)
        ParticleManager:ReleaseParticleIndex(self.formation_particle)
    end
    
    -- Clean up snowball entity
    if self.snowball_entity and IsValidEntity(self.snowball_entity) then
        if self.snowball_entity:IsNull() == false then
            UTIL_Remove(self.snowball_entity)
        end
        self.snowball_entity = nil
    end
    
    -- Swap abilities back
    caster:SwapAbilities("tusk_mp_snowball_launch", "tusk_mp_snowball", false, true)
    
    -- Clean up ally pickup modifiers
    self:CleanupPickupModifiers()
    
    -- Calculate launch parameters
    local target_pos = self.snowball_target:GetAbsOrigin()
    local caster_pos = caster:GetAbsOrigin()
    local direction = CalculateDirection(target_pos, caster_pos)
    local max_distance = self:GetSpecialValueFor("max_travel_distance")
    local actual_distance = CalculateDistance(target_pos, caster_pos)
    local travel_distance = math.min(actual_distance, max_distance)
    local speed = self:GetSpecialValueFor("snowball_speed")
    
    -- Launch sound
    EmitSoundOn("Hero_Tusk.Snowball.Launch", caster)
    
    -- Create projectile
    local projectile = {
        Ability = self,
        EffectName = "particles/units/heroes/hero_tusk/tusk_snowball_launch.vpcf",
        vSpawnOrigin = caster_pos,
        fDistance = travel_distance,
        fStartRadius = self:GetSpecialValueFor("snowball_radius"),
        fEndRadius = self:GetSpecialValueFor("snowball_radius"),
        Source = caster,
        bHasFrontalCone = false,
        bReplaceExisting = false,
        iUnitTargetTeam = DOTA_UNIT_TARGET_TEAM_ENEMY,
        iUnitTargetFlags = DOTA_UNIT_TARGET_FLAG_NONE,
        iUnitTargetType = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC + DOTA_UNIT_TARGET_CREEP,
        fExpireTime = GameRules:GetGameTime() + 15.0,
        bDeleteOnHit = false,
        vVelocity = Vector(direction.x * speed, direction.y * speed, 0),
        bProvidesVision = false,
        ExtraData = {ally_count = #self.snowball_allies}
    }
    
    ProjectileManager:CreateLinearProjectile(projectile)
    
    -- Hide all allies in the snowball and give them movement modifier
    for _, ally in pairs(self.snowball_allies) do
        if IsValidEntity(ally) and ally:IsAlive() then
            ally:AddNoDraw()
            ally:AddNewModifier(caster, self, "modifier_tusk_snowball_movement", {duration = 15.0})
        end
    end
end

function tusk_mp_snowball:OnProjectileThink(vLocation)
    -- Move all allies in snowball to current location
    for _, ally in pairs(self.snowball_allies) do
        if IsValidEntity(ally) and ally:IsAlive() then
            ally:SetAbsOrigin(vLocation)
        end
    end
end

function tusk_mp_snowball:OnProjectileHit(hTarget, vLocation)
    if hTarget then
        -- Hit an enemy
        self:HitEnemy(hTarget, vLocation)
        self:EndSnowball(vLocation)
        return true -- Stop projectile
    else
        -- Reached max distance
        self:EndSnowball(vLocation)
        return true
    end
end

function tusk_mp_snowball:HitEnemy(target, location)
    local caster = self:GetCaster()
    
    -- Calculate damage with mind power scaling
    local base_damage = self:GetSpecialValueFor("snowball_damage")
    local mind_power_multiplier = self:GetSpecialValueFor("mind_power_multiplier") or 0.8
    
    -- Get mind power using the system
    local mind_power = 0
    if GetHeroMindPower then
        mind_power = GetHeroMindPower(caster) or 0
    else
        mind_power = caster:GetIntellect(false) or 0
    end
    
    local mind_power_bonus = mind_power * mind_power_multiplier
    local ally_count = #self.snowball_allies
    local ally_damage_bonus = (ally_count - 1) * (base_damage * 0.2) -- 20% damage per additional ally
    local total_damage = base_damage + mind_power_bonus + ally_damage_bonus
    
    -- Apply damage
    local damageTable = {
        victim = target,
        attacker = caster,
        damage = total_damage,
        damage_type = DAMAGE_TYPE_MAGICAL,
        ability = self
    }
    ApplyDamage(damageTable)
    
    -- Apply stun
    local base_stun = self:GetSpecialValueFor("stun_duration")
    local stun_bonus = self:GetSpecialValueFor("stun_duration_bonus")
    local ally_stun_bonus = (ally_count - 1) * stun_bonus
    local total_stun = base_stun + ally_stun_bonus
    
    target:AddNewModifier(caster, self, "modifier_stunned", {duration = total_stun})
    
    -- Hit sound and particle
    EmitSoundOn("Hero_Tusk.Snowball.Impact", target)
end

function tusk_mp_snowball:EndSnowball(location)
    -- Clean up snowball entity
    if self.snowball_entity and IsValidEntity(self.snowball_entity) then
        if self.snowball_entity:IsNull() == false then
            UTIL_Remove(self.snowball_entity)
        end
        self.snowball_entity = nil
    end
    
    -- Restore all allies from snowball
    for _, ally in pairs(self.snowball_allies) do
        if IsValidEntity(ally) and ally:IsAlive() then
            ally:RemoveNoDraw() -- Make model visible again
            ally:SetAbsOrigin(location)
            ally:RemoveModifierByName("modifier_tusk_snowball_movement")
            ally:RemoveModifierByName("modifier_tusk_snowball_formation")
        end
    end
    
    self:ResetSnowball()
end

function tusk_mp_snowball:CleanupPickupModifiers()
    -- Clean up any remaining pickup modifiers
    local allies = FindUnitsInRadius(
        self:GetCaster():GetTeamNumber(),
        self:GetCaster():GetAbsOrigin(),
        nil,
        2000,
        DOTA_UNIT_TARGET_TEAM_FRIENDLY,
        DOTA_UNIT_TARGET_HERO,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )
    
    for _, ally in pairs(allies) do
        ally:RemoveModifierByName("modifier_tusk_snowball_pickup")
    end
end

function tusk_mp_snowball:ResetSnowball()
    self:CleanupPickupModifiers()
    self.snowball_allies = {}
    self.snowball_target = nil
    self.is_forming = false
end

function tusk_mp_snowball:AddAllyToSnowball(ally)
    if not self.is_forming then
        return false
    end
    
    -- Check if ally is already in snowball
    for _, existing_ally in pairs(self.snowball_allies) do
        if existing_ally == ally then
            return false
        end
    end
    
    -- Add ally to snowball
    table.insert(self.snowball_allies, ally)
    ally:AddNoDraw() -- Hide ally model
    ally:AddNewModifier(self:GetCaster(), self, "modifier_tusk_snowball_formation", {duration = self.formation_time + 1.0})
    EmitSoundOn("Hero_Tusk.Snowball.PickUp", ally)
    
    return true
end

-- Launch ability (activated when pressing W again)
tusk_mp_snowball_launch = class({})

function tusk_mp_snowball_launch:IsStealable()
    return false
end

function tusk_mp_snowball_launch:IsHiddenWhenStolen()
    return true
end

function tusk_mp_snowball_launch:OnSpellStart()
    local caster = self:GetCaster()
    local snowball_ability = caster:FindAbilityByName("tusk_mp_snowball")
    
    if snowball_ability and snowball_ability.is_forming then
        snowball_ability:LaunchSnowball()
    end
end

-- Modifier for Tusk and allies during formation (invulnerable, invisible)
modifier_tusk_snowball_formation = class({})

function modifier_tusk_snowball_formation:IsHidden()
    return false
end

function modifier_tusk_snowball_formation:IsPurgable()
    return false
end

function modifier_tusk_snowball_formation:GetTexture()
    return "tusk_snowball"
end

function modifier_tusk_snowball_formation:CheckState()
    return {
        [MODIFIER_STATE_INVULNERABLE] = true,
        [MODIFIER_STATE_NO_HEALTH_BAR] = true,
        [MODIFIER_STATE_ROOTED] = true,
        [MODIFIER_STATE_DISARMED] = false, -- Can still use abilities
    }
end

-- Modifier for allies to join snowball
modifier_tusk_snowball_pickup = class({})

function modifier_tusk_snowball_pickup:IsHidden()
    return false
end

function modifier_tusk_snowball_pickup:IsPurgable()
    return false
end

function modifier_tusk_snowball_pickup:GetTexture()
    return "tusk_snowball"
end

function modifier_tusk_snowball_pickup:CheckState()
    return {
        [MODIFIER_STATE_SPECIALLY_DENIABLE] = true,
    }
end

function modifier_tusk_snowball_pickup:OnDestroy()
    if not IsServer() then return end
    
    local parent = self:GetParent()
    local caster = self:GetCaster()
    local ability = caster:FindAbilityByName("tusk_mp_snowball")
    
    -- Check if this was triggered by right-click (deny action)
    if ability and ability.AddAllyToSnowball then
        ability:AddAllyToSnowball(parent)
    end
end

-- Modifier for units in the snowball during movement
modifier_tusk_snowball_movement = class({})

function modifier_tusk_snowball_movement:IsHidden()
    return true
end

function modifier_tusk_snowball_movement:IsPurgable()
    return false
end

function modifier_tusk_snowball_movement:CheckState()
    return {
        [MODIFIER_STATE_INVULNERABLE] = true,
        [MODIFIER_STATE_NO_HEALTH_BAR] = true,
        [MODIFIER_STATE_UNSELECTABLE] = true,
        [MODIFIER_STATE_OUT_OF_GAME] = true,
    }
end