LinkLuaModifier(
    "modifier_caravan_aghanim_spear_knockback",
    "map_modifications/Bosses/caravan/caravan_aghanim_spears",
    LUA_MODIFIER_MOTION_HORIZONTAL
)

caravan_aghanim_spears = class({})

local function IsValidUnit(unit)
    return unit and not unit:IsNull() and IsValidEntity(unit)
end

local function Assets()
    if not CaravanAssets then
        require("map_modifications/Bosses/caravan/caravan_assets")
    end
    return CaravanAssets
end

function caravan_aghanim_spears:Precache(context)
    local assets = Assets()
    PrecacheResource("particle", assets.PARTICLE.spear, context)
    PrecacheResource("particle", assets.PARTICLE.spear_burst, context)
    PrecacheResource("particle", assets.PARTICLE.spear_spawn, context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_mars.vsndevts", context)
end

function caravan_aghanim_spears:OnSpellStart()
    if not IsServer() then
        return
    end

    local caster = self:GetCaster()
    local spearCount = self:GetSpecialValueFor("spear_count")
    local spawnDelay = self:GetSpecialValueFor("spawn_delay")
    local launchDelay = self:GetSpecialValueFor("launch_delay")
    local orbit = self:GetSpecialValueFor("orbit_radius")
    local sequence = spawnDelay * spearCount + launchDelay * spearCount + 0.4

    if CourierCaravan and CourierCaravan.MarkAghanimBusy then
        CourierCaravan:MarkAghanimBusy(caster, sequence)
    end

    caster:StartGesture(ACT_DOTA_ATTACK)
    caster:EmitSound("Hero_Mars.Spear.Cast")

    local origin = caster:GetAbsOrigin()
    local forward = caster:GetForwardVector()
    local positions = {}
    local previews = {}
    for i = 1, spearCount do
        local dir = RotatePosition(Vector(0, 0, 0), QAngle(0, (i - 1) * (360 / spearCount), 0), forward)
        positions[i] = origin + dir * orbit
    end

    for i = 1, spearCount do
        Timers:CreateTimer((i - 1) * spawnDelay, function()
            if not IsValidUnit(caster) then
                return nil
            end

            previews[i] = self:SpawnSpearPreview(positions[i])
            caster:EmitSound("Hero_Mars.Spear.Cast")
            return nil
        end)
    end

    local firstLaunch = spawnDelay * spearCount
    for i = 1, spearCount do
        Timers:CreateTimer(firstLaunch + (i - 1) * launchDelay, function()
            if not IsValidUnit(caster) then
                return nil
            end

            self:DestroySpearPreview(previews[i])
            previews[i] = nil
            self:LaunchSpear(positions[i])
            return nil
        end)
    end

    Timers:CreateTimer(sequence, function()
        if CourierCaravan and CourierCaravan.FinishAghanimCast then
            CourierCaravan:FinishAghanimCast(caster)
        end
        return nil
    end)
end

function caravan_aghanim_spears:DestroyFx(fx, immediate)
    if not fx then
        return
    end

    ParticleManager:DestroyParticle(fx, immediate == true)
    ParticleManager:ReleaseParticleIndex(fx)
end

function caravan_aghanim_spears:DestroySpearPreview(preview)
    if not preview then
        return
    end

    self:DestroyFx(preview.spear, true)
    self:DestroyFx(preview.ring, false)
end

function caravan_aghanim_spears:SpawnSpearPreview(origin)
    local assets = Assets()
    local ground = GetGroundPosition(origin, nil)
    local base = ground + Vector(0, 0, 40)
    local tip = ground + Vector(0, 0, 260)

    local spear = ParticleManager:CreateParticle(assets.PARTICLE.spear, PATTACH_WORLDORIGIN, nil)
    ParticleManager:SetParticleControl(spear, 0, base)
    ParticleManager:SetParticleControl(spear, 1, tip)
    ParticleManager:SetParticleControl(spear, 2, Vector(0.01, 0, 0))

    local ring = ParticleManager:CreateParticle(assets.PARTICLE.spear_burst, PATTACH_WORLDORIGIN, nil)
    ParticleManager:SetParticleControl(ring, 0, ground + Vector(0, 0, 8))
    ParticleManager:SetParticleControl(ring, 1, ground + Vector(0, 0, 8))

    local bash = ParticleManager:CreateParticle(assets.PARTICLE.spear_spawn, PATTACH_WORLDORIGIN, nil)
    ParticleManager:SetParticleControl(bash, 0, ground)
    ParticleManager:ReleaseParticleIndex(bash)

    return {
        spear = spear,
        ring = ring,
    }
end

function caravan_aghanim_spears:FindNearestHero(position)
    local caster = self:GetCaster()
    local radius = self:GetSpecialValueFor("search_radius")
    local enemies = FindUnitsInRadius(
        caster:GetTeamNumber(),
        position,
        nil,
        radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO,
        DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES + DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE,
        FIND_CLOSEST,
        false
    )

    for _, hero in ipairs(enemies) do
        if hero and hero:IsRealHero() and hero:IsAlive() then
            return hero
        end
    end

    return nil
end

function caravan_aghanim_spears:LaunchSpear(origin)
    local caster = self:GetCaster()
    if not IsValidUnit(caster) then
        return
    end

    local target = self:FindNearestHero(origin)
    local direction
    if target then
        direction = target:GetAbsOrigin() - origin
    else
        direction = origin - caster:GetAbsOrigin()
    end
    direction.z = 0
    if direction:Length2D() < 1 then
        direction = caster:GetForwardVector()
    end
    direction = direction:Normalized()

    local speed = self:GetSpecialValueFor("spear_speed")
    local distance = self:GetSpecialValueFor("spear_distance")
    local width = self:GetSpecialValueFor("spear_width")
    local velocity = direction * speed
    velocity.z = 0

    caster:EmitSound("Hero_Mars.Spear.Cast")
    ProjectileManager:CreateLinearProjectile({
        Ability = self,
        EffectName = Assets().PARTICLE.spear,
        vSpawnOrigin = origin + Vector(0, 0, 80),
        fDistance = distance,
        fStartRadius = width,
        fEndRadius = width,
        Source = caster,
        bHasFrontalCone = false,
        bReplaceExisting = false,
        iUnitTargetTeam = DOTA_UNIT_TARGET_TEAM_ENEMY,
        iUnitTargetFlags = DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
        iUnitTargetType = DOTA_UNIT_TARGET_HERO,
        fExpireTime = GameRules:GetGameTime() + distance / math.max(speed, 1) + 0.5,
        bDeleteOnHit = true,
        vVelocity = velocity,
        bProvidesVision = true,
        iVisionRadius = width,
        iVisionTeamNumber = caster:GetTeamNumber(),
        ExtraData = {
            dir_x = direction.x,
            dir_y = direction.y,
        },
    })
end

function caravan_aghanim_spears:OnProjectileHit_ExtraData(target, location, extraData)
    if not IsServer() or not target then
        return true
    end

    local caster = self:GetCaster()
    ApplyDamage({
        attacker = caster,
        victim = target,
        damage = self:GetSpecialValueFor("damage"),
        damage_type = DAMAGE_TYPE_MAGICAL,
        ability = self,
    })

    target:EmitSound("Hero_Mars.Spear.Target")
    local impact = ParticleManager:CreateParticle(Assets().PARTICLE.spear_burst, PATTACH_ABSORIGIN_FOLLOW, target)
    ParticleManager:ReleaseParticleIndex(impact)

    local dir = Vector(extraData and extraData.dir_x or 1, extraData and extraData.dir_y or 0, 0)
    if dir:Length2D() < 1 then
        dir = caster:GetForwardVector()
    end
    dir = dir:Normalized()

    target:AddNewModifier(caster, self, "modifier_caravan_aghanim_spear_knockback", {
        duration = 0.6,
        dir_x = dir.x,
        dir_y = dir.y,
        speed = self:GetSpecialValueFor("knockback_speed"),
        distance = self:GetSpecialValueFor("knockback_distance"),
        pin_stun = self:GetSpecialValueFor("pin_stun"),
    })

    return true
end

modifier_caravan_aghanim_spear_knockback = class({})

function modifier_caravan_aghanim_spear_knockback:IsHidden()
    return true
end

function modifier_caravan_aghanim_spear_knockback:IsDebuff()
    return true
end

function modifier_caravan_aghanim_spear_knockback:IsPurgable()
    return false
end

function modifier_caravan_aghanim_spear_knockback:OnCreated(kv)
    if not IsServer() then
        return
    end

    kv = kv or {}
    self.dir = Vector(tonumber(kv.dir_x) or 1, tonumber(kv.dir_y) or 0, 0)
    if self.dir:Length2D() < 1 then
        self.dir = Vector(1, 0, 0)
    end
    self.dir = self.dir:Normalized()
    self.speed = tonumber(kv.speed) or 1200
    self.distance = tonumber(kv.distance) or 400
    self.pin_stun = tonumber(kv.pin_stun) or 1.6
    self.traveled = 0

    if self:ApplyHorizontalMotionController() == false then
        self:StartIntervalThink(0.03)
    end
end

function modifier_caravan_aghanim_spear_knockback:OnDestroy()
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if parent and not parent:IsNull() then
        parent:RemoveHorizontalMotionController(self)
        FindClearSpaceForUnit(parent, parent:GetAbsOrigin(), false)
    end
end

function modifier_caravan_aghanim_spear_knockback:DeclareFunctions()
    return {}
end

function modifier_caravan_aghanim_spear_knockback:CheckState()
    return {
        [MODIFIER_STATE_STUNNED] = true,
    }
end

function modifier_caravan_aghanim_spear_knockback:CheckObstacle(pos)
    local parent = self:GetParent()
    if GridNav:IsNearbyTree(pos, 80, false) then
        return true
    end

    if not GridNav:IsTraversable(pos) then
        return true
    end

    local nextGround = GetGroundHeight(pos, parent)
    local currentGround = GetGroundHeight(parent:GetAbsOrigin(), parent)
    if nextGround - currentGround > 40 then
        return true
    end

    local caster = self:GetCaster()
    local team = caster and caster:GetTeamNumber() or parent:GetTeamNumber()
    local buildings = FindUnitsInRadius(
        team,
        pos,
        nil,
        90,
        DOTA_UNIT_TARGET_TEAM_BOTH,
        DOTA_UNIT_TARGET_BUILDING,
        DOTA_UNIT_TARGET_FLAG_INVULNERABLE + DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
        FIND_ANY_ORDER,
        false
    )
    return #buildings > 0
end

function modifier_caravan_aghanim_spear_knockback:Pin()
    local parent = self:GetParent()
    local caster = self:GetCaster()
    local ability = self:GetAbility()
    if IsValidUnit(parent) then
        parent:AddNewModifier(caster, ability, "modifier_stunned", { duration = self.pin_stun })
        local fx = ParticleManager:CreateParticle(Assets().PARTICLE.spear_burst, PATTACH_ABSORIGIN_FOLLOW, parent)
        ParticleManager:ReleaseParticleIndex(fx)
        parent:EmitSound("Hero_Mars.Spear.Root")
    end
    self:Destroy()
end

function modifier_caravan_aghanim_spear_knockback:Advance(dt)
    local parent = self:GetParent()
    if not IsValidUnit(parent) then
        self:Destroy()
        return
    end

    local step = self.speed * dt
    local nextPos = parent:GetAbsOrigin() + self.dir * step
    if self:CheckObstacle(nextPos) then
        self:Pin()
        return
    end

    nextPos.z = GetGroundHeight(nextPos, parent)
    parent:SetAbsOrigin(nextPos)
    self.traveled = self.traveled + step
    if self.traveled >= self.distance then
        self:Destroy()
    end
end

function modifier_caravan_aghanim_spear_knockback:UpdateHorizontalMotion(me, dt)
    self:Advance(dt)
end

function modifier_caravan_aghanim_spear_knockback:OnHorizontalMotionInterrupted()
    if IsServer() then
        self:Destroy()
    end
end

function modifier_caravan_aghanim_spear_knockback:OnIntervalThink()
    self:Advance(0.03)
end
