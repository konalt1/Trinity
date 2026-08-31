caravan_aghanim_shards = class({})

local function IsValidUnit(unit)
    return unit and not unit:IsNull() and IsValidEntity(unit)
end

local function Assets()
    if not CaravanAssets then
        require("map_modifications/Bosses/caravan/caravan_assets")
    end
    return CaravanAssets
end

function caravan_aghanim_shards:Precache(context)
    local assets = Assets()
    PrecacheResource("particle", assets.PARTICLE.crystal_trail, context)
    PrecacheResource("particle", assets.PARTICLE.crystal_impact, context)
    PrecacheResource("particle", assets.PARTICLE.crystal_telegraph, context)
    PrecacheResource("particle", assets.PARTICLE.shard_proj, context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_crystalmaiden.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_ancient_apparition.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_tusk.vsndevts", context)
end

function caravan_aghanim_shards:OnSpellStart()
    if not IsServer() then
        return
    end

    local caster = self:GetCaster()
    if CourierCaravan and CourierCaravan.MarkAghanimBusy then
        CourierCaravan:MarkAghanimBusy(caster, 1.8)
    end

    caster:StartGesture(ACT_DOTA_CAST_ABILITY_3)

    local radius = self:GetSpecialValueFor("radius")
    local enemies = FindUnitsInRadius(
        caster:GetTeamNumber(),
        caster:GetAbsOrigin(),
        nil,
        radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO,
        DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES + DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE,
        FIND_CLOSEST,
        false
    )

    caster:EmitSound("Hero_Crystal.CrystalNova")

    local launched = 0
    for _, hero in ipairs(enemies) do
        if hero and hero:IsRealHero() and hero:IsAlive() then
            self:LaunchShard(hero)
            launched = launched + 1
        end
    end

    if launched == 0 then
        if CourierCaravan and CourierCaravan.FinishAghanimCast then
            CourierCaravan:FinishAghanimCast(caster)
        end
        return
    end

    Timers:CreateTimer(1.6, function()
        if CourierCaravan and CourierCaravan.FinishAghanimCast then
            CourierCaravan:FinishAghanimCast(caster)
        end
        return nil
    end)
end

function caravan_aghanim_shards:PlaceTelegraph(location)
    local assets = Assets()
    local fx = ParticleManager:CreateParticle(assets.PARTICLE.crystal_telegraph, PATTACH_WORLDORIGIN, nil)
    ParticleManager:SetParticleControl(fx, 0, location)
    ParticleManager:SetParticleControl(fx, 1, Vector(180, 0, 0))
    ParticleManager:ReleaseParticleIndex(fx)
end

function caravan_aghanim_shards:LaunchLinear(origin, direction, speed, distance, width, effectName, isSplit)
    local caster = self:GetCaster()
    direction = Vector(direction.x, direction.y, 0)
    if direction:Length2D() < 1 then
        direction = Vector(1, 0, 0)
    end
    direction = direction:Normalized()

    local velocity = direction * speed
    velocity.z = 0

    ProjectileManager:CreateLinearProjectile({
        Ability = self,
        EffectName = effectName,
        vSpawnOrigin = origin,
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
            split = isSplit and 1 or 0,
        },
    })
end

function caravan_aghanim_shards:LaunchShard(target)
    local caster = self:GetCaster()
    if not IsValidUnit(caster) or not IsValidUnit(target) then
        return
    end

    local assets = Assets()
    local origin = assets:GetAttachOrigin(caster)
    local dest = target:GetAbsOrigin()
    local direction = dest - origin
    direction.z = 0
    if direction:Length2D() < 1 then
        direction = caster:GetForwardVector()
        direction.z = 0
    end

    local speed = self:GetSpecialValueFor("projectile_speed")
    local width = self:GetSpecialValueFor("projectile_width")
    if width <= 0 then
        width = 90
    end
    local distance = math.max((Vector(dest.x, dest.y, 0) - Vector(origin.x, origin.y, 0)):Length2D() + 175, 250)

    self:PlaceTelegraph(dest)
    self:LaunchLinear(origin, direction, speed, distance, width, assets.PARTICLE.shard_proj, false)
end

function caravan_aghanim_shards:LaunchSplitShards(origin, fromTarget)
    local caster = self:GetCaster()
    if not IsValidUnit(caster) then
        return
    end

    local assets = Assets()
    caster:EmitSound("Hero_Crystal.CrystalNova")
    local explode = ParticleManager:CreateParticle(assets.PARTICLE.crystal_impact, PATTACH_WORLDORIGIN, caster)
    ParticleManager:SetParticleControl(explode, 0, origin)
    ParticleManager:ReleaseParticleIndex(explode)

    local spread = self:GetSpecialValueFor("split_spread")
    local distance = self:GetSpecialValueFor("split_distance")
    local speed = self:GetSpecialValueFor("split_speed")
    local radius = self:GetSpecialValueFor("split_width")
    local baseDir = fromTarget and not fromTarget:IsNull()
        and (fromTarget:GetAbsOrigin() - caster:GetAbsOrigin())
        or Vector(1, 0, 0)
    baseDir.z = 0
    if baseDir:Length2D() < 1 then
        baseDir = Vector(1, 0, 0)
    end
    baseDir = baseDir:Normalized()

    for i = 0, 2 do
        local angle = -spread + (spread * i)
        local dir = RotatePosition(Vector(0, 0, 0), QAngle(0, angle, 0), baseDir)
        self:LaunchLinear(origin + Vector(0, 0, 60), dir, speed, distance, radius, assets.PARTICLE.shard_proj, true)
    end
end

function caravan_aghanim_shards:HitTarget(target, isSplit)
    if not IsValidUnit(target) or not target:IsAlive() then
        return
    end

    local caster = self:GetCaster()
    local damage = isSplit and self:GetSpecialValueFor("split_damage") or self:GetSpecialValueFor("damage")
    local stun = isSplit and self:GetSpecialValueFor("split_stun") or self:GetSpecialValueFor("stun")

    ApplyDamage({
        attacker = caster,
        victim = target,
        damage = damage,
        damage_type = DAMAGE_TYPE_MAGICAL,
        ability = self,
    })
    target:AddNewModifier(caster, self, "modifier_stunned", { duration = stun })
    target:EmitSound("Hero_Crystal.CrystalNova")
end

function caravan_aghanim_shards:OnProjectileHit_ExtraData(target, location, extraData)
    if not IsServer() then
        return true
    end

    local isSplit = extraData and extraData.split == 1
    if target then
        self:HitTarget(target, isSplit)
        if not isSplit then
            self:LaunchSplitShards(target:GetAbsOrigin(), target)
        end
    end

    return true
end
