LinkLuaModifier("modifier_lion_impale_custom_stun", "abilities/lion/lion_impale_custom", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_lion_impale_knockup", "abilities/lion/lion_impale_custom", LUA_MODIFIER_MOTION_VERTICAL)

local function LionGetMindPower(unit)
    if GetHeroMindPower then
        return GetHeroMindPower(unit) or 0
    end
    if unit and not unit:IsNull() and unit.GetIntellect then
        return unit:GetIntellect(false) or 0
    end
    return 0
end

local function LionHasShard(unit)
    if not unit or unit:IsNull() then
        return false
    end
    if HasShard then
        return HasShard(unit)
    end
    return unit:HasModifier("modifier_item_aghanims_shard")
end

local function LionRotateDirection2D(direction, degrees)
    local radians = math.rad(degrees)
    local cos = math.cos(radians)
    local sin = math.sin(radians)
    return Vector(
        direction.x * cos - direction.y * sin,
        direction.x * sin + direction.y * cos,
        0
    ):Normalized()
end

lion_impale_custom = class({})

function lion_impale_custom:GetAOERadius()
    return self:GetSpecialValueFor("width")
end

function lion_impale_custom:GetMindScaledDamage()
    local caster = self:GetCaster()
    local base = self:GetSpecialValueFor("damage")
    local multiplier = self:GetSpecialValueFor("mind_power_multiplier")
    return math.max(0, base + LionGetMindPower(caster) * multiplier)
end

function lion_impale_custom:CreateImpaleProjectile(origin, direction, length, width, speed)
    local caster = self:GetCaster()

    ProjectileManager:CreateLinearProjectile({
        Ability = self,
        EffectName = "particles/units/heroes/hero_lion/lion_spell_impale.vpcf",
        vSpawnOrigin = origin,
        fDistance = length,
        fStartRadius = width,
        fEndRadius = width,
        Source = caster,
        bHasFrontalCone = false,
        bReplaceExisting = false,
        iUnitTargetTeam = DOTA_UNIT_TARGET_TEAM_ENEMY,
        iUnitTargetFlags = DOTA_UNIT_TARGET_FLAG_NONE,
        iUnitTargetType = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        fExpireTime = GameRules:GetGameTime() + length / speed + 0.5,
        bDeleteOnHit = false,
        vVelocity = direction * speed,
        bProvidesVision = true,
        iVisionRadius = width,
        iVisionTeamNumber = caster:GetTeamNumber(),
    })
end

function lion_impale_custom:OnSpellStart()
    local caster = self:GetCaster()
    local target = self:GetCursorTarget()
    local point = self:GetCursorPosition()
    local origin = caster:GetAbsOrigin()

    if target and not target:IsNull() then
        point = target:GetAbsOrigin()
    end

    local direction = point - origin
    direction.z = 0
    if direction:Length2D() < 1 then
        direction = caster:GetForwardVector()
    else
        direction = direction:Normalized()
    end

    local length = self:GetSpecialValueFor("length")
    local width = self:GetSpecialValueFor("width")
    local speed = self:GetSpecialValueFor("speed")
    self.impale_hit_targets = {}

    local has_shard = LionHasShard(caster)
    local spike_count = has_shard and math.max(1, self:GetSpecialValueFor("shard_spike_count")) or 1
    local cone_angle = has_shard and self:GetSpecialValueFor("shard_cone_angle") or 0

    if spike_count <= 1 or cone_angle <= 0 then
        self:CreateImpaleProjectile(origin, direction, length, width, speed)
    else
        for i = 1, spike_count do
            local t = (i - 1) / math.max(1, spike_count - 1)
            local angle_offset = -cone_angle / 2 + cone_angle * t
            self:CreateImpaleProjectile(origin, LionRotateDirection2D(direction, angle_offset), length, width, speed)
        end
    end

    Timers:CreateTimer(length / speed + 0.6, function()
        if self and not self:IsNull() then
            self.impale_hit_targets = nil
        end
        return nil
    end)

    EmitSoundOn("Hero_Lion.Impale", caster)
end

function lion_impale_custom:OnProjectileHit(target, location)
    if not target or target:IsNull() then
        return false
    end

    local caster = self:GetCaster()
    self.impale_hit_targets = self.impale_hit_targets or {}
    local target_index = target:entindex()
    if self.impale_hit_targets[target_index] then
        return false
    end
    self.impale_hit_targets[target_index] = true

    if target:TriggerSpellAbsorb(self) then
        return false
    end

    ApplyDamage({
        victim = target,
        attacker = caster,
        damage = self:GetMindScaledDamage(),
        damage_type = self:GetAbilityDamageType(),
        ability = self,
    })

    local stun_duration = self:GetSpecialValueFor("stun_duration") * (1 - target:GetStatusResistance())
    target:AddNewModifier(caster, self, "modifier_lion_impale_custom_stun", {
        duration = stun_duration,
    })
    target:AddNewModifier(caster, self, "modifier_lion_impale_knockup", {
        duration = self:GetSpecialValueFor("knockup_duration"),
        height = self:GetSpecialValueFor("knockup_height"),
    })

    return false
end

modifier_lion_impale_custom_stun = class({})

function modifier_lion_impale_custom_stun:IsHidden() return false end
function modifier_lion_impale_custom_stun:IsDebuff() return true end
function modifier_lion_impale_custom_stun:IsPurgable() return true end
function modifier_lion_impale_custom_stun:CheckState()
    return {
        [MODIFIER_STATE_STUNNED] = true,
    }
end
function modifier_lion_impale_custom_stun:GetEffectName()
    return "particles/generic_gameplay/generic_stunned.vpcf"
end
function modifier_lion_impale_custom_stun:GetEffectAttachType()
    return PATTACH_OVERHEAD_FOLLOW
end

modifier_lion_impale_knockup = class({})

function modifier_lion_impale_knockup:IsHidden() return true end
function modifier_lion_impale_knockup:IsPurgable() return false end
function modifier_lion_impale_knockup:IsDebuff() return true end
function modifier_lion_impale_knockup:GetAttributes() return MODIFIER_ATTRIBUTE_MULTIPLE end

function modifier_lion_impale_knockup:OnCreated(kv)
    if not IsServer() then
        return
    end

    self.duration = math.max(0.03, tonumber(kv.duration) or 0.45)
    self.height = math.max(0, tonumber(kv.height) or 220)
    self.elapsed = 0

    if not self:ApplyVerticalMotionController() then
        self:Destroy()
    end
end

function modifier_lion_impale_knockup:OnDestroy()
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if parent and not parent:IsNull() then
        local position = parent:GetAbsOrigin()
        position.z = GetGroundHeight(position, parent)
        parent:SetAbsOrigin(position)
        parent:RemoveVerticalMotionController(self)
    end
end

function modifier_lion_impale_knockup:UpdateVerticalMotion(parent, dt)
    if not IsServer() then
        return
    end
    if not parent or parent:IsNull() then
        self:Destroy()
        return
    end

    self.elapsed = math.min(self.duration, (self.elapsed or 0) + dt)
    local progress = self.elapsed / self.duration
    local lift = 4 * self.height * progress * (1 - progress)
    local position = parent:GetAbsOrigin()
    position.z = GetGroundHeight(position, parent) + lift
    parent:SetAbsOrigin(position)

    if self.elapsed >= self.duration then
        self:Destroy()
    end
end

function modifier_lion_impale_knockup:OnVerticalMotionInterrupted()
    if not IsServer() then
        return
    end

    self:Destroy()
end

