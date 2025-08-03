require("utils/util")

tusk_ice = class({})

function tusk_ice:IsStealable()
    return true
end

function tusk_ice:IsHiddenWhenStolen()
    return false
end

function tusk_ice:GetCooldown(iLvl)
    local cooldown = self.BaseClass.GetCooldown(self, iLvl)
    if self:GetCaster():HasTalent("special_bonus_unique_tusk_ice_1") then cooldown = cooldown + self:GetCaster():FindTalentValue("special_bonus_unique_tusk_ice_1") end
    return cooldown
end

function tusk_ice:OnSpellStart()
    local caster = self:GetCaster()
    local point = self:GetCursorPosition()
    if self:GetCursorTarget() then
        local point = self:GetCursorTarget():GetAbsOrigin()
    end

    local direction = CalculateDirection(point, caster:GetAbsOrigin())
    local speed = self:GetSpecialValueFor("speed")
    local vel = direction * speed
    local distance = CalculateDistance(point, caster:GetAbsOrigin())

    EmitSoundOn("Hero_Tusk.IceShards.Cast", caster)
    
    local projectileInfo = {
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
        bDeleteOnHit = false,
        vVelocity = vel * Vector(1, 1, 0),
        bProvidesVision = true,
        iVisionRadius = 400,
        iVisionTeamNumber = caster:GetTeamNumber()
    }
    self.projectileID = ProjectileManager:CreateLinearProjectile(projectileInfo)

    self.dummy = CreateUnitByName("npc_dota_thinker", caster:GetAbsOrigin(), false, nil, nil, caster:GetTeamNumber())
    self.dummy:AddNewModifier(self.dummy, nil, "modifier_phased", {})
    EmitSoundOn("Hero_Tusk.IceShards.Projectile", self.dummy)
end

function tusk_ice:OnProjectileThink(vLocation)
    self.dummy:SetAbsOrigin(vLocation)
end

function tusk_ice:OnProjectileHit(hTarget, vLocation)
    local caster = self:GetCaster()
    local hitEnemy = {}

    if hTarget ~= nil and not hTarget:TriggerSpellAbsorb( self ) then
        ApplyDamage({
            victim = hTarget,
            attacker = caster,
            damage = self:GetSpecialValueFor("damage"),
            damage_type = DAMAGE_TYPE_MAGICAL,
            ability = self
        })
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

        --Center
        local position = vLocation + direction * radius
        ParticleManager:SetParticleControl(nfx, 1, position)
        local pso = SpawnEntityFromTableSynchronous('point_simple_obstruction', {origin = position})
        table.insert(deleteTable, pso)

        local angle = self:GetSpecialValueFor("angle")
        --left
        local left_QAngle = QAngle(0, angle, 0)
        for i=2,4 do
            local left_spawn_point = RotatePosition(vLocation, left_QAngle, position)
            ParticleManager:SetParticleControl(nfx, i, left_spawn_point)
            local pso = SpawnEntityFromTableSynchronous('point_simple_obstruction', {origin = left_spawn_point})
            table.insert(deleteTable, pso)
            left_QAngle = left_QAngle + QAngle(0, angle, 0)
        end
        
        --right           
        local right_QAngle = QAngle(0, -angle, 0)
        for i=5,7 do
            local right_spawn_point = RotatePosition(vLocation, right_QAngle, position)
            ParticleManager:SetParticleControl(nfx, i, right_spawn_point)
            local pso = SpawnEntityFromTableSynchronous('point_simple_obstruction', {origin = right_spawn_point})
            table.insert(deleteTable, pso)
            right_QAngle = right_QAngle + QAngle(0, -angle, 0)
        end

        Timers:CreateTimer(self:GetSpecialValueFor("duration"), function()
            for _,entity in pairs(deleteTable) do
                if not entity:IsNull() then UTIL_Remove(entity) end
            end
        end)

        local enemies = caster:FindEnemyUnitsInRadius(vLocation, self:GetSpecialValueFor("radius"))
        for _,enemy in pairs(enemies) do
            for _,hTarget in pairs(hitEnemy) do
                if enemy ~= hTarget and not enemy:TriggerSpellAbsorb( self ) then
                    self:DealDamage(caster, enemy, self:GetSpecialValueFor("damage"), {}, 0)
                end
            end
        end
    end
end
