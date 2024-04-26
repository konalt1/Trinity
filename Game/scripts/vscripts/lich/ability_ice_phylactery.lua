ability_ice_phylactery = ability_ice_phylactery or class({})

function ability_ice_phylactery:OnSpellStart(event)
    CreateUnitByNameAsync(
        "npc_dota_lich_ice_spire",
        self:GetCursorPosition(),
        true,
        self:GetCaster(),
        self:GetCaster(),
        self:GetCaster():GetTeam(),
        function (unit)
            self:OnIceSpireCreated(unit)
        end
    )
end

function ability_ice_phylactery:OnIceSpireCreated(unit)
    -- unit:AddNewModifier()
end
