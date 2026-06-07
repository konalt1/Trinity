modifier_chen_barrack_unit = class({})
modifier_chen_barrack_carrier = class({})
modifier_chen_barrack_gold_display = class({})

local function IsValidUnit(unit)
    return unit and not unit:IsNull()
end

function modifier_chen_barrack_unit:IsHidden()
    return true
end

function modifier_chen_barrack_unit:IsPurgable()
    return false
end

function modifier_chen_barrack_unit:OnCreated(kv)
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if kv and kv.gold_mode then
        parent.chen_gold_mode = kv.gold_mode
    end
end

function modifier_chen_barrack_carrier:IsHidden()
    return false
end

function modifier_chen_barrack_carrier:IsPurgable()
    return false
end

function modifier_chen_barrack_carrier:GetTexture()
    return "alchemist_goblins_greed"
end

function modifier_chen_barrack_carrier:OnCreated()
    if not IsServer() then
        return
    end

    self:SetStackCount(ChenBarrackGold.GetCarriedGold(self:GetParent()))
    self:StartIntervalThink(0.25)
end

function modifier_chen_barrack_carrier:OnIntervalThink()
    if not IsServer() then
        return
    end

    local unit = self:GetParent()
    if not IsValidUnit(unit) or not unit:IsAlive() then
        return
    end

    self:SetStackCount(ChenBarrackGold.GetCarriedGold(unit))

    local carried = ChenBarrackGold.GetCarriedGold(unit)
    if carried <= 0 then
        return
    end

    local barrack = ChenBarrackGold.GetHomeBarrack(unit)
    if not IsValidUnit(barrack) or not barrack:IsAlive() then
        return
    end

    local deliveryRadius = ChenBarrackGold.GetDeliveryRadius(barrack)
    if (unit:GetAbsOrigin() - barrack:GetAbsOrigin()):Length2D() <= deliveryRadius then
        ChenBarrackGold.DepositCarrierGold(unit)
    end
end

function modifier_chen_barrack_carrier:OnTooltip()
    return ChenBarrackGold.GetCarriedGold(self:GetParent())
end

function modifier_chen_barrack_gold_display:IsHidden()
    return false
end

function modifier_chen_barrack_gold_display:IsPurgable()
    return false
end

function modifier_chen_barrack_gold_display:GetTexture()
    return "alchemist_goblins_greed"
end

function modifier_chen_barrack_gold_display:OnTooltip()
    return ChenBarrackGold.Get(self:GetParent())
end
