LinkLuaModifier("modifier_lion_soul_collector_tracker", "abilities/lion/lion_soul_collector", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_lion_soul_collector_temp", "abilities/lion/lion_soul_collector", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_lion_soul_collector_permanent", "abilities/lion/lion_soul_collector", LUA_MODIFIER_MOTION_NONE)

local function LionAddStackedModifier(parent, ability, modifier_name, amount)
    if not parent or parent:IsNull() or amount <= 0 then
        return nil
    end

    local modifier = parent:FindModifierByName(modifier_name)
    if not modifier then
        modifier = parent:AddNewModifier(parent, ability, modifier_name, {})
    end
    if modifier and not modifier:IsNull() then
        modifier:SetStackCount(modifier:GetStackCount() + amount)
        modifier:ForceRefresh()
    end

    return modifier
end

lion_soul_collector = class({})

function lion_soul_collector:GetIntrinsicModifierName()
    return "modifier_lion_soul_collector_tracker"
end

modifier_lion_soul_collector_tracker = class({})

function modifier_lion_soul_collector_tracker:IsHidden() return true end
function modifier_lion_soul_collector_tracker:IsPurgable() return false end
function modifier_lion_soul_collector_tracker:RemoveOnDeath() return false end
function modifier_lion_soul_collector_tracker:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_DEATH,
    }
end

function modifier_lion_soul_collector_tracker:OnDeath(params)
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    local ability = self:GetAbility()
    local victim = params.unit
    local attacker = params.attacker

    if not parent or parent:IsNull() or parent:IsIllusion() then return end
    if not ability or ability:IsNull() then return end
    if not victim or victim:IsNull() or victim == parent then return end
    if not attacker or attacker:IsNull() or attacker ~= parent then return end
    if victim:GetTeamNumber() == parent:GetTeamNumber() then return end

    if victim:IsRealHero() then
        local bonus = ability:GetSpecialValueFor("hero_mind_power")
        LionAddStackedModifier(parent, ability, "modifier_lion_soul_collector_permanent", bonus)
        return
    end

    if victim:IsCreep() or victim:IsNeutralUnitType() then
        local bonus = ability:GetSpecialValueFor("creep_mind_power")
        local duration = ability:GetSpecialValueFor("creep_duration")
        local modifier = LionAddStackedModifier(parent, ability, "modifier_lion_soul_collector_temp", bonus)

        if modifier and duration > 0 then
            Timers:CreateTimer(duration, function()
                if not parent or parent:IsNull() then
                    return nil
                end

                local current = parent:FindModifierByName("modifier_lion_soul_collector_temp")
                if not current or current:IsNull() then
                    return nil
                end

                local next_stack = math.max(0, current:GetStackCount() - bonus)
                current:SetStackCount(next_stack)
                current:ForceRefresh()
                if next_stack <= 0 then
                    current:Destroy()
                end

                return nil
            end)
        end
    end
end

modifier_lion_soul_collector_temp = class({})

function modifier_lion_soul_collector_temp:IsHidden() return false end
function modifier_lion_soul_collector_temp:IsPurgable() return false end
function modifier_lion_soul_collector_temp:IsBuff() return true end
function modifier_lion_soul_collector_temp:RemoveOnDeath() return false end
function modifier_lion_soul_collector_temp:GetTexture() return "lion_soul_collector" end

modifier_lion_soul_collector_permanent = class({})

function modifier_lion_soul_collector_permanent:IsHidden() return false end
function modifier_lion_soul_collector_permanent:IsPurgable() return false end
function modifier_lion_soul_collector_permanent:IsBuff() return true end
function modifier_lion_soul_collector_permanent:RemoveOnDeath() return false end
function modifier_lion_soul_collector_permanent:IsPermanent() return true end
function modifier_lion_soul_collector_permanent:GetTexture() return "lion_soul_collector" end

MIND_POWER_MODIFIER_REGISTRY = MIND_POWER_MODIFIER_REGISTRY or {}
MIND_POWER_MODIFIER_REGISTRY["modifier_lion_soul_collector_temp"] = function(modifier)
    return modifier:GetStackCount()
end
MIND_POWER_MODIFIER_REGISTRY["modifier_lion_soul_collector_permanent"] = function(modifier)
    return modifier:GetStackCount()
end

