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

    caster:RemoveModifierByName("modifier_aegis")
    local modifier = caster:AddNewModifier(caster, nil, "modifier_aegis", { duration = duration })
    if modifier and modifier.SetDuration then
        modifier:SetDuration(duration, true)
    end
    EmitSoundOn("Aegis.Activate", caster)
    caster:RemoveItem(self)
end
