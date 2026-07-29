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

local LION_SOUL_COLLECTOR_DAMAGE_WINDOW = 3

local function LionIsScepterClawDamage(parent, params)
    if params.inflictor ~= nil then
        return false
    end

    local claw = parent:FindModifierByName("modifier_lion_finger_scepter_claw")
    return claw and not claw:IsNull() and claw.IsMeleeMode and claw:IsMeleeMode()
end

local function LionIsAbilityDamage(parent, params)
    if not parent or parent:IsNull() or params.attacker ~= parent then
        return false
    end

    local inflictor = params.inflictor
    if inflictor and not inflictor:IsNull() then
        if inflictor.IsItem and inflictor:IsItem() then
            return false
        end

        local caster = inflictor.GetCaster and inflictor:GetCaster() or nil
        return caster == parent
    end

    -- The empowered melee hand granted by Finger of Death's Scepter modifier
    -- is treated as an ability for Soul Collector.
    return LionIsScepterClawDamage(parent, params)
end

function modifier_lion_soul_collector_tracker:IsHidden() return true end
function modifier_lion_soul_collector_tracker:IsPurgable() return false end
function modifier_lion_soul_collector_tracker:RemoveOnDeath() return false end
function modifier_lion_soul_collector_tracker:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_TAKEDAMAGE,
        MODIFIER_EVENT_ON_DEATH,
    }
end

function modifier_lion_soul_collector_tracker:OnCreated()
    if IsServer() then
        self.last_ability_damage = {}
    end
end

function modifier_lion_soul_collector_tracker:OnTakeDamage(params)
    if not IsServer() or not params.damage or params.damage <= 0 then
        return
    end

    local parent = self:GetParent()
    local victim = params.unit
    if not parent or parent:IsNull() or parent:IsIllusion() then return end
    if not victim or victim:IsNull() or victim == parent then return end
    if victim:GetTeamNumber() == parent:GetTeamNumber() then return end
    if not LionIsAbilityDamage(parent, params) then return end

    self.last_ability_damage = self.last_ability_damage or {}
    self.last_ability_damage[victim:entindex()] = GameRules:GetGameTime()
end

function modifier_lion_soul_collector_tracker:OnDeath(params)
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    local ability = self:GetAbility()
    local victim = params.unit

    if not parent or parent:IsNull() or parent:IsIllusion() then return end
    if not ability or ability:IsNull() then return end
    if not victim or victim:IsNull() or victim == parent then return end
    if victim:GetTeamNumber() == parent:GetTeamNumber() then return end

    local victim_index = victim:entindex()
    local last_damage_time = self.last_ability_damage and self.last_ability_damage[victim_index] or nil
    local died_from_ability = LionIsAbilityDamage(parent, params)
    local died_after_ability_damage = last_damage_time ~= nil
        and GameRules:GetGameTime() - last_damage_time <= LION_SOUL_COLLECTOR_DAMAGE_WINDOW

    if self.last_ability_damage then
        self.last_ability_damage[victim_index] = nil
    end
    if not died_from_ability and not died_after_ability_damage then return end

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
