item_caravan_gold_bag = class({})

function item_caravan_gold_bag:OnSpellStart()
    if not IsServer() then
        return
    end

    local caster = self:GetCaster()
    if not caster or caster:IsNull() then
        return
    end

    local gold = self:GetCurrentCharges()
    if gold <= 0 then
        gold = self:GetSpecialValueFor("gold_amount")
    end
    if gold <= 0 then
        gold = 50
    end

    local playerID = caster:GetPlayerOwnerID()
    if playerID ~= nil and playerID >= 0 then
        PlayerResource:ModifyGold(playerID, gold, true, DOTA_ModifyGold_Unspecified)
        SendOverheadEventMessage(nil, OVERHEAD_ALERT_GOLD, caster, gold, nil)
        local player = PlayerResource:GetPlayer(playerID)
        if player then
            EmitSoundOnClient("General.Coins", player)
        end
    end

    caster:RemoveItem(self)
end
