require('utils/util')

tusk_ice = class({})

function tusk_ice:IsStealable()
    return true
end

function tusk_ice:IsHiddenWhenStolen()
    return false
end

function tusk_ice:GetCooldown(iLvl)
    local cooldown = self.BaseClass.GetCooldown(self, iLvl)
    local caster = self:GetCaster()
    
    -- Safe talent check (talents may not be implemented in this mod)
    if caster.HasTalent and caster.FindTalentValue then
        if caster:HasTalent("special_bonus_unique_tusk_ice_1") then 
            cooldown = cooldown + caster:FindTalentValue("special_bonus_unique_tusk_ice_1") 
        end
    end
    
    return cooldown
end

function tusk_ice:OnSpellStart()
    local caster = self:GetCaster()
    local point = self:GetCursorPosition()
    if self:GetCursorTarget() then
        point = self:GetCursorTarget():GetAbsOrigin()
    end

    local direction = CalculateDirection(point, caster:GetAbsOrigin())
    local speed = self:GetSpecialValueFor("speed")
    -- Ensure velocity is 2D (no vertical component)
    local vel = Vector(direction.x * speed, direction.y * speed, 0)
    local distance = CalculateDistance(point, caster:GetAbsOrigin())

    EmitSoundOn("Hero_Tusk.IceShards.Cast", caster)
    
    local projectile = {
        Ability = self,
        EffectName = "particles/units/heroes/hero_tusk/tusk_ice_shards_projectile.vpcf",
        vSpawnOrigin = caster:GetAbsOrigin(),
        fDistance = distance,
        fStartRadius = self:GetSpecialValueFor("width"),
        fEndRadius = self:GetSpecialValueFor("width"),
        Source = caster,
        bHasFrontalCone = false,
        bReplaceExisting = false,
        iUnitTargetTeam = DOTA_UNIT_TARGET_TEAM_ENEMY,
        iUnitTargetFlags = DOTA_UNIT_TARGET_FLAG_NONE,
        iUnitTargetType = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        fExpireTime = GameRules:GetGameTime() + 10.0,
        bDeleteOnHit = true,
        vVelocity = vel,
        bProvidesVision = false
    }
    
    ProjectileManager:CreateLinearProjectile(projectile)

    self.dummy = CreateUnitByName("npc_dummy_unit", caster:GetAbsOrigin(), false, nil, nil, caster:GetTeamNumber())
    if self.dummy then
        self.dummy:AddNewModifier(self.dummy, nil, "modifier_phased", {})
        EmitSoundOn("Hero_Tusk.IceShards.Projectile", self.dummy)
    end
end

function tusk_ice:OnProjectileThink(vLocation)
    if self.dummy and IsValidEntity(self.dummy) then
        self.dummy:SetAbsOrigin(vLocation)
    end
end

function tusk_ice:OnProjectileHit(hTarget, vLocation)
    local caster = self:GetCaster()
    local hitEnemy = {}

    if hTarget ~= nil and not hTarget:TriggerSpellAbsorb( self ) then
        local base_damage = self:GetSpecialValueFor("damage")
        local mind_power_multiplier = self:GetSpecialValueFor("mind_power_multiplier") or 1.0  -- Default 1.0 if not defined
        
        -- Safe call to GetHeroMindPower with fallback
        local mind_power = 0
        if GetHeroMindPower then
            mind_power = GetHeroMindPower(caster) or 0
        else
            mind_power = caster:GetIntellect(false) or 0
        end
        
        local mind_power_bonus = mind_power * mind_power_multiplier
        local total_damage = math.max(0, base_damage + mind_power_bonus)

        local damageTable = {
            victim = hTarget,
            attacker = caster,
            damage = total_damage,
            damage_type = DAMAGE_TYPE_MAGICAL,
            ability = self
        }
        ApplyDamage(damageTable)
        table.insert(hitEnemy, hTarget)
    else
        local deleteTable = {}
        local direction = CalculateDirection(vLocation, caster:GetAbsOrigin())
        local duration = self:GetSpecialValueFor("duration")
        local vision_range = self:GetSpecialValueFor("radius")
        local shard = 7
        local radius = self:GetSpecialValueFor("radius")
        local nfx = ParticleManager:CreateParticle("particles/units/heroes/hero_tusk/tusk_shards.vpcf", PATTACH_POINT, self:GetCaster())

        ParticleManager:SetParticleControl(nfx, 0, Vector(duration, 0, 0))
        
        EmitSoundOnLocationWithCaster(vLocation, "Hero_Tusk.IceShards", caster)

        if self.dummy then
            StopSoundOn("Hero_Tusk.IceShards.Projectile", self.dummy)
            self.dummy:ForceKill(false)
        end

        -- Create half circle formation
        -- Position center behind target so tip of semicircle is at target point
        local semicircle_radius = 300  -- Larger radius for bigger semicircle
        local wall_center = vLocation - direction * semicircle_radius
        
        -- Get the angle of the direction from caster to target
        local base_angle = math.atan2(direction.y, direction.x)
        
        -- Create 7 shards in a semicircle formation
        for i = 1, 7 do
            -- Distribute shards across wider arc (about 120 degrees)
            -- More spread out formation
            local angle_offset = (i - 4) * (math.pi / 5)  -- ~36 degrees between each shard
            local shard_angle = base_angle + angle_offset  -- Tip points away from caster
            
            local shard_position = Vector(
                wall_center.x + math.cos(shard_angle) * semicircle_radius,
                wall_center.y + math.sin(shard_angle) * semicircle_radius,
                wall_center.z - 75
            )
            
            ParticleManager:SetParticleControl(nfx, i, shard_position)
            local ice_shard = SpawnEntityFromTableSynchronous("prop_dynamic", {
                model = "models/particle/ice_shards.vmdl",
                origin = shard_position,
                ModelScale = 17.0,
            })
            -- Create larger hitbox with multiple obstruction points
            local pso = SpawnEntityFromTableSynchronous('point_simple_obstruction', {origin = shard_position})
            table.insert(deleteTable, ice_shard)
            table.insert(deleteTable, pso)
            
            -- Add additional obstruction points around the crystal for larger hitbox
            local hitbox_offsets = {
                {x = 50, y = 0}, {x = -50, y = 0}, {x = 0, y = 50}, {x = 0, y = -50},
                {x = 35, y = 35}, {x = -35, y = -35}, {x = 35, y = -35}, {x = -35, y = 35}
            }
            
            for _, offset in ipairs(hitbox_offsets) do
                local offset_pos = Vector(
                    shard_position.x + offset.x,
                    shard_position.y + offset.y,
                    shard_position.z
                )
                local extra_pso = SpawnEntityFromTableSynchronous('point_simple_obstruction', {origin = offset_pos})
                table.insert(deleteTable, extra_pso)
            end
        end

        Timers:CreateTimer(self:GetSpecialValueFor("duration"), function()
            for _,entity in pairs(deleteTable) do
                if entity and IsValidEntity(entity) and not entity:IsNull() then 
                    UTIL_Remove(entity)
                end
            end
        end)

        local enemies = FindUnitsInRadius(caster:GetTeamNumber(), vLocation, nil, self:GetSpecialValueFor("radius"), DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)
        for _,enemy in pairs(enemies) do
            local found = false
            for _,hTarget in pairs(hitEnemy) do
                if enemy == hTarget then
                    found = true
                    break
                end
            end
            if not found and not enemy:TriggerSpellAbsorb( self ) then
                local base_damage = self:GetSpecialValueFor("damage")
                local mind_power_multiplier = self:GetSpecialValueFor("mind_power_multiplier") or 1.0  -- Default 1.0 if not defined
                
                -- Safe call to GetHeroMindPower with fallback
                local mind_power = 0
                if GetHeroMindPower then
                    mind_power = GetHeroMindPower(caster) or 0
                else
                    mind_power = caster:GetIntellect(false) or 0
                end
                
                local mind_power_bonus = mind_power * mind_power_multiplier
                local total_damage = math.max(0, base_damage + mind_power_bonus)
                
                local damageTable = {
                    victim = enemy,
                    attacker = caster,
                    damage = total_damage,
                    damage_type = DAMAGE_TYPE_MAGICAL,
                    ability = self
                }
                ApplyDamage(damageTable)
            end
        end
    end
end
