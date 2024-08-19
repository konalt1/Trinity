LinkLuaModifier('modifier_techies_sticky_bomb_bonus', 'abilities/techies/techies_sticky_bomb_bonus', LUA_MODIFIER_MOTION_NONE)
 
techies_sticky_bomb_bonus = class({})

 
function techies_sticky_bomb_bonus:Spawn()
	if IsClient() then return end

	self:SetLevel(1)
end


function techies_sticky_bomb_bonus:GetIntrinsicModifierName()
	return "modifier_techies_sticky_bomb_bonus"
end

modifier_techies_sticky_bomb_bonus = class({
	IsHidden 				= function(self) return true end,
	IsBuff                  = function(self) return true end,
	RemoveOnDeath 			= function(self) return false end,
    DeclareFunctions        = function(self) return 
    {
        MODIFIER_PROPERTY_TOTALDAMAGEOUTGOING_PERCENTAGE,
    } end,
})

function modifier_techies_sticky_bomb_bonus:GetModifierTotalDamageOutgoing_Percentage(event)
    local parent = self:GetParent()
    local attacker = event.attacker
    local ability = event.inflictor

	if attacker == self:GetParent() and ability:GetName() == "techies_sticky_bomb" then 
  		if event.target:IsCreep() then 
  			return ability:GetSpecialValueFor("bonus_damage_creep_pct") - 100
  		end
	end
end