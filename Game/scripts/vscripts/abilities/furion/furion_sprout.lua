-- Простой Sprout: кольцо деревьев + рут. Без DoT.
LinkLuaModifier("modifier_furion_sprout_root", "abilities/furion/furion_sprout", LUA_MODIFIER_MOTION_NONE)

furion_sprout              = class({})
modifier_furion_sprout_root = class({})

--------------------------------------------------------------------------------
-- Ability
--------------------------------------------------------------------------------
function furion_sprout:GetAOERadius()
    return self:GetSpecialValueFor("radius")
end

function furion_sprout:OnSpellStart()
    if not IsServer() then return end

    local caster   = self:GetCaster()
    local target   = self:GetCursorTarget()
    local duration = self:GetSpecialValueFor("duration")
    local radius   = self:GetSpecialValueFor("radius")
    local team     = caster:GetTeamNumber()

    -- Кольцо деревьев (8 штук) вокруг цели
    local treePositions = {}
    local treeCount = 8
    for i = 0, treeCount - 1 do
        local angle   = (2 * math.pi / treeCount) * i
        local treePos = target:GetAbsOrigin() + Vector(math.cos(angle), math.sin(angle), 0) * radius
        CreateTempTree(treePos, duration + 0.5)
        table.insert(treePositions, treePos)
    end

    -- Рут-модификатор
    local mod = target:AddNewModifier(caster, self, "modifier_furion_sprout_root",
        { duration = duration })
    if mod then
        mod._treePositions = treePositions
        mod._centerPos     = target:GetAbsOrigin()
        mod._visionTeam    = team
        mod._visionRadius  = 200
    end

    -- Частицы (реальные из Dota)
    local fxGround = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_furion/furion_sprout.vpcf",
        PATTACH_ABSORIGIN_FOLLOW, target)
    ParticleManager:SetParticleControl(fxGround, 0, target:GetAbsOrigin())
    ParticleManager:SetParticleControl(fxGround, 1, Vector(radius, 0, 0))
    ParticleManager:ReleaseParticleIndex(fxGround)

    local fxCast = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_furion/furion_sprout_ambient.vpcf",
        PATTACH_ABSORIGIN, target)
    ParticleManager:SetParticleControl(fxCast, 0, target:GetAbsOrigin())
    ParticleManager:ReleaseParticleIndex(fxCast)

    EmitSoundOn("Hero_Furion.Sprout", target)
end

--------------------------------------------------------------------------------
-- Root modifier
--------------------------------------------------------------------------------
function modifier_furion_sprout_root:IsHidden()    return false end
function modifier_furion_sprout_root:IsDebuff()    return true  end
function modifier_furion_sprout_root:IsPurgable()  return true  end

function modifier_furion_sprout_root:OnCreated(kv)
    if IsServer() then
        self:RefreshVision()
        self:StartIntervalThink(0.9)
    end
end

function modifier_furion_sprout_root:OnIntervalThink()
    if IsServer() then self:RefreshVision() end
end

function modifier_furion_sprout_root:RefreshVision()
    local team   = self._visionTeam
    local radius = self._visionRadius or 200
    local dur    = 1.1
    if not team then return end
    if self._centerPos then
        AddFOWViewer(team, self._centerPos, radius, dur, false)
    end
    if self._treePositions then
        for _, pos in ipairs(self._treePositions) do
            AddFOWViewer(team, pos, radius, dur, false)
        end
    end
end

function modifier_furion_sprout_root:CheckState()
    return { [MODIFIER_STATE_ROOTED] = true }
end

function modifier_furion_sprout_root:GetEffectName()
    return "particles/units/heroes/hero_furion/furion_sprout_ambient.vpcf"
end

function modifier_furion_sprout_root:GetEffectAttachType()
    return PATTACH_ABSORIGIN_FOLLOW
end
