modifier_caravan_aghanim_leash = class({})

function modifier_caravan_aghanim_leash:IsHidden()
    return true
end

function modifier_caravan_aghanim_leash:IsPurgable()
    return false
end

function modifier_caravan_aghanim_leash:RemoveOnDeath()
    return true
end

function modifier_caravan_aghanim_leash:OnCreated(keys)
    if not IsServer() then
        return
    end

    self.leash_radius = (keys and keys.radius) or 700
    self:StartIntervalThink(0.1)
end

function modifier_caravan_aghanim_leash:OnIntervalThink()
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if not parent or parent:IsNull() or not parent:IsAlive() then
        return
    end

    local aghanim = parent.caravanAghanim
    if not aghanim or aghanim:IsNull() or not aghanim:IsAlive() then
        return
    end

    local distance = (parent:GetAbsOrigin() - aghanim:GetAbsOrigin()):Length2D()
    if distance > self.leash_radius then
        parent.caravanLeashPull = true
        parent:MoveToPosition(aghanim:GetAbsOrigin())
    else
        parent.caravanLeashPull = false
    end
end

modifier_caravan_courier = class({})

function modifier_caravan_courier:IsHidden()
    return true
end

function modifier_caravan_courier:IsPurgable()
    return false
end

function modifier_caravan_courier:RemoveOnDeath()
    return true
end

function modifier_caravan_courier:OnCreated(keys)
    self.pips = (keys and tonumber(keys.hits)) or 0
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if not parent or parent:IsNull() then
        return
    end

    local hits = self.pips
    if hits <= 0 then
        hits = math.max(1, math.floor(parent:GetMaxHealth() / 100))
    end

    parent:SetBaseMaxHealth(hits)
    parent:SetMaxHealth(hits)
    parent:SetHealth(hits)
    self.pips = hits
end

function modifier_caravan_courier:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_HEALTHBAR_PIPS,
        MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_MAGICAL,
        MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PHYSICAL,
        MODIFIER_PROPERTY_ABSOLUTE_NO_DAMAGE_PURE,
        MODIFIER_PROPERTY_DISABLE_HEALING,
        MODIFIER_EVENT_ON_ATTACKED,
    }
end

function modifier_caravan_courier:GetAbsoluteNoDamageMagical()
    return 1
end

function modifier_caravan_courier:GetAbsoluteNoDamagePhysical()
    return 1
end

function modifier_caravan_courier:GetAbsoluteNoDamagePure()
    return 1
end

function modifier_caravan_courier:GetDisableHealing()
    return 1
end

function modifier_caravan_courier:GetModifierHealthBarPips()
    local parent = self:GetParent()
    if parent and not parent:IsNull() then
        return parent:GetMaxHealth()
    end
    return self.pips or 0
end

function modifier_caravan_courier:OnAttacked(params)
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if not params or not parent or parent:IsNull() then
        return
    end

    if params.target ~= parent then
        return
    end

    local attacker = params.attacker
    if not attacker or attacker:IsNull() or attacker == parent then
        return
    end

    if CourierCaravan and CourierCaravan.OnCourierDamaged then
        CourierCaravan:OnCourierDamaged(parent, attacker)
    end

    local remaining = parent:GetHealth() - 1
    if remaining <= 0 then
        parent:Kill(nil, attacker)
        return
    end

    parent:SetHealth(remaining)
end

modifier_caravan_global_vision = class({})

local CARAVAN_REVEAL_RADIUS = 1100

function modifier_caravan_global_vision:IsHidden()
    return true
end

function modifier_caravan_global_vision:IsPurgable()
    return false
end

function modifier_caravan_global_vision:RemoveOnDeath()
    return true
end

function modifier_caravan_global_vision:OnCreated()
    if not IsServer() then
        return
    end

    self:Reveal()
    self:StartIntervalThink(0.1)
end

function modifier_caravan_global_vision:OnIntervalThink()
    self:Reveal()
end

function modifier_caravan_global_vision:Reveal()
    local parent = self:GetParent()
    if not parent or parent:IsNull() then
        return
    end

    local position = parent:GetAbsOrigin()
    AddFOWViewer(DOTA_TEAM_GOODGUYS, position, CARAVAN_REVEAL_RADIUS, 0.3, false)
    AddFOWViewer(DOTA_TEAM_BADGUYS, position, CARAVAN_REVEAL_RADIUS, 0.3, false)
end
