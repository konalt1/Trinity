require("items/caravan_boons")

item_caravan_aegis = class({})

function item_caravan_aegis:OnSpellStart()
    if not IsServer() then
        return
    end

    local caster = self:GetCaster()
    if not caster or caster:IsNull() then
        return
    end

    if caster.caravanId or self.caravanDisplay then
        return
    end

    local duration = self:GetSpecialValueFor("duration")
    if duration <= 0 then
        duration = 120
    end

    -- Общая выдача с бунами: ванильный modifier_aegis, а если движок его не создал — modifier_trinity_aegis.
    CaravanBoons.GiveAegis(caster, duration)
    caster:RemoveItem(self)
end
