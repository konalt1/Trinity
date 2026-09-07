LinkLuaModifier(
    "modifier_caravan_aghanim_shards",
    "map_modifications/Bosses/caravan/caravan_aghanim_shards",
    LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
    "modifier_caravan_aghanim_shard",
    "map_modifications/Bosses/caravan/caravan_aghanim_shards",
    LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
    "modifier_caravan_aghanim_shard_slow",
    "map_modifications/Bosses/caravan/caravan_aghanim_shards",
    LUA_MODIFIER_MOTION_NONE
)

caravan_aghanim_shards = class({})

local SHARD_HEIGHT = 100
local SHARD_THINK = 0.03
local CAST_BUSY = 0.45
local SWAP_GESTURE = ACT_DOTA_CAST_ABILITY_5
local SHARD_UNIT = "npc_caravan_shard"
local SHARD_MODEL = "models/props_gameplay/aghanim_gem_centered.vmdl"
local SHARD_SCALE = 3.0

local function IsValidUnit(unit)
    return unit and unit.IsNull and not unit:IsNull() and IsValidEntity(unit)
end

local function OrbitPos(origin, radius, rotation)
    local relative = Vector(-radius, 0, SHARD_HEIGHT)
    return RotatePosition(origin, QAngle(0, -rotation, 0), origin + relative)
end

local function OrbitYaw(origin, radius, rotation)
    local from = OrbitPos(origin, radius, rotation)
    local ahead = OrbitPos(origin, radius, rotation + 2)
    local direction = ahead - from
    direction.z = 0
    if direction:Length2D() < 0.01 then
        return 0
    end
    return math.deg(math.atan2(direction.y, direction.x))
end

local function Assets()
    if not CaravanAssets then
        require("map_modifications/Bosses/caravan/caravan_assets")
    end
    return CaravanAssets
end

function caravan_aghanim_shards:Precache(context)
    local assets = Assets()
    PrecacheResource("particle", assets.PARTICLE.crystal_orbit, context)
    PrecacheResource("particle", assets.PARTICLE.crystal_impact, context)
    PrecacheResource("particle", assets.PARTICLE.crystal_trail, context)
    PrecacheResource("model", SHARD_MODEL, context)
    PrecacheUnitByNameSync(SHARD_UNIT, context)
    PrecacheResource("particle", "particles/generic_gameplay/generic_slowed_cold.vpcf", context)
    PrecacheResource("particle", "particles/status_fx/status_effect_frost_lich.vpcf", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_crystalmaiden.vsndevts", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_ancient_apparition.vsndevts", context)
end

function caravan_aghanim_shards:OnAbilityPhaseStart()
    if not IsServer() then
        return true
    end

    local caster = self:GetCaster()
    if IsValidUnit(caster) then
        caster:StartGesture(SWAP_GESTURE)
        if CourierCaravan and CourierCaravan.MarkAghanimBusy then
            CourierCaravan:MarkAghanimBusy(caster, self:GetCastPoint() + CAST_BUSY)
        end
    end
    return true
end

function caravan_aghanim_shards:OnAbilityPhaseInterrupted()
    if not IsServer() then
        return
    end

    local caster = self:GetCaster()
    if IsValidUnit(caster) then
        caster:RemoveGesture(SWAP_GESTURE)
        if CourierCaravan and CourierCaravan.FinishAghanimCast then
            CourierCaravan:FinishAghanimCast(caster)
        end
    end
end

function caravan_aghanim_shards:OnSpellStart()
    if not IsServer() then
        return
    end

    local caster = self:GetCaster()
    if not IsValidUnit(caster) then
        return
    end

    self:SyncStageLevel()

    local existing = caster:FindModifierByName("modifier_caravan_aghanim_shards")
    if existing then
        if CourierCaravan and CourierCaravan.FinishAghanimCast then
            CourierCaravan:FinishAghanimCast(caster)
        end
        return
    end

    if CourierCaravan and CourierCaravan.MarkAghanimBusy then
        CourierCaravan:MarkAghanimBusy(caster, CAST_BUSY)
    end

    caster:RemoveGesture(SWAP_GESTURE)
    caster:StartGesture(ACT_DOTA_CAST_ABILITY_3)
    caster:EmitSound("Hero_Crystal.CrystalNova")
    caster:AddNewModifier(caster, self, "modifier_caravan_aghanim_shards", {})

    Timers:CreateTimer(CAST_BUSY, function()
        if CourierCaravan and CourierCaravan.FinishAghanimCast then
            CourierCaravan:FinishAghanimCast(caster)
        end
        return nil
    end)
end

function caravan_aghanim_shards:SyncStageLevel()
    local caster = self:GetCaster()
    local stage = caster and caster.caravanStage or self:GetLevel()
    stage = math.min(3, math.max(1, math.floor(tonumber(stage) or 1)))
    if self:GetLevel() ~= stage then
        self:SetLevel(stage)
    end
end

function caravan_aghanim_shards:HitHero(target, location)
    if not IsValidUnit(target) or not target:IsAlive() then
        return
    end

    local caster = self:GetCaster()
    if not IsValidUnit(caster) then
        return
    end

    local origin = location or target:GetAbsOrigin()
    local fx = ParticleManager:CreateParticle(Assets().PARTICLE.crystal_impact, PATTACH_WORLDORIGIN, nil)
    ParticleManager:SetParticleControl(fx, 0, origin)
    ParticleManager:ReleaseParticleIndex(fx)

    ApplyDamage({
        attacker = caster,
        victim = target,
        damage = self:GetSpecialValueFor("damage"),
        damage_type = DAMAGE_TYPE_MAGICAL,
        ability = self,
    })
    local duration = self:GetSpecialValueFor("slow_duration")
    if target.GetStatusResistance then
        duration = duration * (1 - target:GetStatusResistance())
    end
    target:AddNewModifier(caster, self, "modifier_caravan_aghanim_shard_slow", {
        duration = duration,
    })
    target:EmitSound("Hero_Crystal.CrystalNova")
end

function caravan_aghanim_shards:FindHitHero(position, radius)
    local caster = self:GetCaster()
    if not IsValidUnit(caster) then
        return nil
    end

    local closest, closestDist = nil, radius
    for i = 0, HeroList:GetHeroCount() - 1 do
        local hero = HeroList:GetHero(i)
        if IsValidUnit(hero)
            and hero:IsRealHero()
            and hero:IsAlive()
            and not hero:IsIllusion()
            and not hero:IsMagicImmune()
            and not hero:IsInvulnerable()
            and hero:GetTeamNumber() ~= caster:GetTeamNumber()
        then
            local dist = (hero:GetAbsOrigin() - position):Length2D()
            if dist <= closestDist then
                closest = hero
                closestDist = dist
            end
        end
    end

    return closest
end

modifier_caravan_aghanim_shards = class({})

function modifier_caravan_aghanim_shards:IsHidden()
    return true
end

function modifier_caravan_aghanim_shards:IsPurgable()
    return false
end

function modifier_caravan_aghanim_shards:RemoveOnDeath()
    return true
end

function modifier_caravan_aghanim_shards:GetAttributes()
    return MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE
end

function modifier_caravan_aghanim_shards:OnCreated()
    if not IsServer() then
        return
    end

    local ability = self:GetAbility()
    local caster = self:GetCaster()
    if not ability or not IsValidUnit(caster) then
        self:Destroy()
        return
    end

    self.shards = {}
    local count = math.max(1, ability:GetSpecialValueFor("shard_count"))
    local radius = ability:GetSpecialValueFor("orbit_radius")
    local origin = caster:GetOrigin()

    for i = 1, count do
        local rotation = (i - 1) * (360 / count)
        local pos = OrbitPos(origin, radius, rotation)
        local yaw = OrbitYaw(origin, radius, rotation)
        local dummy = CreateUnitByName(SHARD_UNIT, pos, false, nil, nil, caster:GetTeamNumber())
        if IsValidUnit(dummy) then
            dummy:AddNoDraw()
            dummy:SetAbsAngles(0, yaw, 0)
            dummy.shardProp = Assets():CreateIceShardProp(pos, yaw, SHARD_SCALE, dummy, SHARD_MODEL)
            dummy:AddNewModifier(caster, ability, "modifier_phased", {})
            dummy:AddNewModifier(caster, ability, "modifier_caravan_aghanim_shard", { angle = rotation })
            table.insert(self.shards, dummy)
        end
    end

    if #self.shards == 0 then
        self:Destroy()
        return
    end

    self:StartIntervalThink(0.2)
end

function modifier_caravan_aghanim_shards:OnIntervalThink()
    if not IsServer() then
        return
    end

    local caster = self:GetCaster()
    if not IsValidUnit(caster) or not caster:IsAlive() then
        self:Destroy()
        return
    end

    self:PruneShards()
    if #self.shards == 0 then
        self:Destroy()
    end
end

function modifier_caravan_aghanim_shards:PruneShards()
    local alive = {}
    for _, thinker in ipairs(self.shards or {}) do
        if IsValidUnit(thinker) then
            table.insert(alive, thinker)
        end
    end
    self.shards = alive
end

function modifier_caravan_aghanim_shards:OnShardRemoved()
    if not IsServer() or self.destroyed then
        return
    end

    self:PruneShards()
    if #self.shards == 0 then
        self:Destroy()
    end
end

function modifier_caravan_aghanim_shards:OnDestroy()
    if not IsServer() then
        return
    end

    self.destroyed = true
    for _, thinker in ipairs(self.shards or {}) do
        if IsValidUnit(thinker) then
            local shard = thinker:FindModifierByName("modifier_caravan_aghanim_shard")
            if shard then
                shard.silent = true
            end
            Assets():DestroyIceShardProp(thinker.shardProp)
            thinker.shardProp = nil
            UTIL_Remove(thinker)
        end
    end
    self.shards = {}
end

modifier_caravan_aghanim_shard = class({})

function modifier_caravan_aghanim_shard:IsHidden()
    return true
end

function modifier_caravan_aghanim_shard:IsPurgable()
    return false
end

function modifier_caravan_aghanim_shard:GetAttributes()
    return MODIFIER_ATTRIBUTE_IGNORE_INVULNERABLE
end

function modifier_caravan_aghanim_shard:CheckState()
    return {
        [MODIFIER_STATE_INVULNERABLE] = true,
        [MODIFIER_STATE_UNSELECTABLE] = true,
        [MODIFIER_STATE_NOT_ON_MINIMAP] = true,
        [MODIFIER_STATE_NO_HEALTH_BAR] = true,
        [MODIFIER_STATE_NO_UNIT_COLLISION] = true,
        [MODIFIER_STATE_ATTACK_IMMUNE] = true,
        [MODIFIER_STATE_MAGIC_IMMUNE] = true,
        [MODIFIER_STATE_NO_TEAM_MOVE_TO] = true,
        [MODIFIER_STATE_NO_TEAM_SELECT] = true,
        [MODIFIER_STATE_COMMAND_RESTRICTED] = true,
        [MODIFIER_STATE_FLYING] = true,
    }
end

function modifier_caravan_aghanim_shard:OnCreated(keys)
    if not IsServer() then
        return
    end

    self.rotation = tonumber(keys.angle) or 0
    self.silent = false
    self.removed = false

    local parent = self:GetParent()
    parent:AddNoDraw()
    if not parent.shardProp then
        local caster = self:GetCaster()
        local ability = self:GetAbility()
        local origin = caster and caster:GetOrigin() or parent:GetAbsOrigin()
        local radius = ability and ability:GetSpecialValueFor("orbit_radius") or 0
        parent.shardProp = Assets():CreateIceShardProp(
            parent:GetAbsOrigin(),
            OrbitYaw(origin, radius, self.rotation),
            SHARD_SCALE,
            parent,
            SHARD_MODEL
        )
    end

    self.fx = ParticleManager:CreateParticle(Assets().PARTICLE.crystal_trail, PATTACH_ABSORIGIN_FOLLOW, parent)
    ParticleManager:SetParticleControlEnt(
        self.fx,
        0,
        parent,
        PATTACH_ABSORIGIN_FOLLOW,
        nil,
        parent:GetAbsOrigin(),
        true
    )

    self:StartIntervalThink(SHARD_THINK)
end

function modifier_caravan_aghanim_shard:OnIntervalThink()
    if not IsServer() then
        return
    end

    local caster = self:GetCaster()
    local parent = self:GetParent()
    local ability = self:GetAbility()
    if not IsValidUnit(caster) or not caster:IsAlive() or not IsValidUnit(parent) or not ability then
        self:RemoveShard(true)
        return
    end

    local radius = ability:GetSpecialValueFor("orbit_radius")
    local speed = ability:GetSpecialValueFor("rotate_speed")
    self.rotation = (self.rotation or 0) + speed * SHARD_THINK
    local origin = caster:GetOrigin()
    local pos = OrbitPos(origin, radius, self.rotation)
    local yaw = OrbitYaw(origin, radius, self.rotation)
    parent:SetAbsOrigin(pos)
    parent:SetAbsAngles(0, yaw, 0)
    Assets():PlaceIceShardProp(parent.shardProp, pos, yaw)

    local hero = ability:FindHitHero(pos, ability:GetSpecialValueFor("hit_radius"))
    if hero then
        ability:HitHero(hero, pos)
        self:RemoveShard(false)
    end
end

function modifier_caravan_aghanim_shard:RemoveShard(silent)
    if self.removed then
        return
    end

    self.silent = silent == true
    self.removed = true
    if self.fx then
        ParticleManager:DestroyParticle(self.fx, false)
        ParticleManager:ReleaseParticleIndex(self.fx)
        self.fx = nil
    end
    local parent = self:GetParent()
    if IsValidUnit(parent) then
        Assets():DestroyIceShardProp(parent.shardProp)
        parent.shardProp = nil
        UTIL_Remove(parent)
    else
        self:Destroy()
    end
end

function modifier_caravan_aghanim_shard:OnDestroy()
    if not IsServer() then
        return
    end

    if self.fx then
        ParticleManager:DestroyParticle(self.fx, false)
        ParticleManager:ReleaseParticleIndex(self.fx)
        self.fx = nil
    end

    local caster = self:GetCaster()
    if not self.silent and IsValidUnit(caster) then
        local owner = caster:FindModifierByName("modifier_caravan_aghanim_shards")
        if owner and owner.OnShardRemoved then
            owner:OnShardRemoved()
        end
    end
end

modifier_caravan_aghanim_shard_slow = class({})

function modifier_caravan_aghanim_shard_slow:IsHidden()
    return false
end

function modifier_caravan_aghanim_shard_slow:IsDebuff()
    return true
end

function modifier_caravan_aghanim_shard_slow:IsPurgable()
    return true
end

function modifier_caravan_aghanim_shard_slow:GetAttributes()
    return MODIFIER_ATTRIBUTE_MULTIPLE
end

function modifier_caravan_aghanim_shard_slow:OnCreated()
    self:CacheSlow()
end

function modifier_caravan_aghanim_shard_slow:OnRefresh()
    self:CacheSlow()
end

function modifier_caravan_aghanim_shard_slow:CacheSlow()
    local ability = self:GetAbility()
    self.ms_slow = ability and ability:GetSpecialValueFor("slow_movement_speed") or 0
    self.as_slow = ability and ability:GetSpecialValueFor("slow_attack_speed") or 0
end

function modifier_caravan_aghanim_shard_slow:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
    }
end

function modifier_caravan_aghanim_shard_slow:GetModifierMoveSpeedBonus_Percentage()
    return self.ms_slow or 0
end

function modifier_caravan_aghanim_shard_slow:GetModifierAttackSpeedBonus_Constant()
    return self.as_slow or 0
end

function modifier_caravan_aghanim_shard_slow:GetEffectName()
    return "particles/generic_gameplay/generic_slowed_cold.vpcf"
end

function modifier_caravan_aghanim_shard_slow:GetEffectAttachType()
    return PATTACH_ABSORIGIN_FOLLOW
end

function modifier_caravan_aghanim_shard_slow:GetStatusEffectName()
    return "particles/status_fx/status_effect_frost_lich.vpcf"
end
