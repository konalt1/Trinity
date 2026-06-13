chen_ancient_black_dragon_fire_puddle = class({})
modifier_chen_ancient_black_dragon_fire_puddle = class({})
modifier_chen_ancient_black_dragon_fire_puddle_thinker = class({})

local SCRIPT_PATH = "abilities/chen/barrack/units/chen_ancient_black_dragon_fire_puddle"
local FIRE_PUDDLE_PARTICLE = "particles/units/neutral/black_dragon/black_dragon_fireball.vpcf"

LinkLuaModifier("modifier_chen_ancient_black_dragon_fire_puddle", SCRIPT_PATH, LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_chen_ancient_black_dragon_fire_puddle_thinker", SCRIPT_PATH, LUA_MODIFIER_MOTION_NONE)

local function IsValidUnit(unit)
    return unit and not unit:IsNull()
end

local function GetGroundPoint(origin, unit)
    if GetGroundPosition then
        return GetGroundPosition(origin, unit)
    end
    return origin
end

function chen_ancient_black_dragon_fire_puddle:Precache(context)
    PrecacheResource("particle", FIRE_PUDDLE_PARTICLE, context)
    PrecacheResource("particle", "particles/neutral_fx/black_dragon_attack.vpcf", context)
    PrecacheResource("soundfile", "soundevents/game_sounds_creeps.vsndevts", context)
end

function chen_ancient_black_dragon_fire_puddle:GetIntrinsicModifierName()
    return "modifier_chen_ancient_black_dragon_fire_puddle"
end

function modifier_chen_ancient_black_dragon_fire_puddle:IsHidden()
    return true
end

function modifier_chen_ancient_black_dragon_fire_puddle:IsPurgable()
    return false
end

function modifier_chen_ancient_black_dragon_fire_puddle:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_ATTACK_LANDED,
    }
end

function modifier_chen_ancient_black_dragon_fire_puddle:OnAttackLanded(params)
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    local ability = self:GetAbility()
    if not IsValidUnit(parent) or not ability or ability:IsNull() then
        return
    end

    if params.attacker ~= parent then
        return
    end

    local target = params.target
    if not IsValidUnit(target) or target:IsInvulnerable() or target:IsBuilding() then
        return
    end

    if target:GetTeamNumber() == parent:GetTeamNumber() then
        return
    end

    local ground = GetGroundPoint(target:GetAbsOrigin(), target)
    local duration = ability:GetSpecialValueFor("duration")
    local radius = ability:GetSpecialValueFor("radius")

    CreateModifierThinker(
        parent,
        ability,
        "modifier_chen_ancient_black_dragon_fire_puddle_thinker",
        {
            duration = duration,
            radius = radius,
        },
        ground,
        parent:GetTeamNumber(),
        false
    )
end

function modifier_chen_ancient_black_dragon_fire_puddle_thinker:IsHidden()
    return true
end

function modifier_chen_ancient_black_dragon_fire_puddle_thinker:IsPurgable()
    return false
end

function modifier_chen_ancient_black_dragon_fire_puddle_thinker:OnCreated(kv)
    if not IsServer() then
        return
    end

    local ability = self:GetAbility()
    if not ability or ability:IsNull() then
        return
    end

    self.radius = kv.radius or ability:GetSpecialValueFor("radius")
    self.burn_interval = ability:GetSpecialValueFor("burn_interval")
    self.damage_per_tick = ability:GetSpecialValueFor("damage_per_second") * self.burn_interval

    self.position = self:GetParent():GetAbsOrigin()

    self.damageTable = {
        attacker = self:GetCaster(),
        damage = self.damage_per_tick,
        damage_type = DAMAGE_TYPE_MAGICAL,
        ability = ability,
        damage_flags = DOTA_DAMAGE_FLAG_NONE,
    }

    self:PlayEffects()
    self:BurnEnemies()
    self:StartIntervalThink(self.burn_interval)
end

function modifier_chen_ancient_black_dragon_fire_puddle_thinker:OnIntervalThink()
    if not IsServer() then
        return
    end

    self:BurnEnemies()
end

function modifier_chen_ancient_black_dragon_fire_puddle_thinker:BurnEnemies()
    local caster = self:GetCaster()
    if not IsValidUnit(caster) then
        return
    end

    local enemies = FindUnitsInRadius(
        caster:GetTeamNumber(),
        self.position,
        nil,
        self.radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )

    for _, enemy in pairs(enemies) do
        self.damageTable.victim = enemy
        ApplyDamage(self.damageTable)
    end
end

function modifier_chen_ancient_black_dragon_fire_puddle_thinker:PlayEffects()
    local particle = ParticleManager:CreateParticle(FIRE_PUDDLE_PARTICLE, PATTACH_WORLDORIGIN, nil)
    ParticleManager:SetParticleControl(particle, 0, self.position)
    ParticleManager:SetParticleControl(particle, 1, Vector(self.radius, 0, 0))
    self:AddParticle(particle, false, false, -1, false, false)
end
