LinkLuaModifier('modifier_ogre_magi_bonk', 'abilities/ogre_magi/ogre_magi_bonk', LUA_MODIFIER_MOTION_NONE)

ogre_magi_bonk = class({})

function ogre_magi_bonk:GetIntrinsicModifierName()
	return "modifier_ogre_magi_bonk"
end

modifier_ogre_magi_bonk = class({
	IsHidden 				= function(self) return true end,
    DeclareFunctions        = function(self) return 
    {
    	MODIFIER_EVENT_ON_ATTACK_LANDED,
    } end,
})


function modifier_ogre_magi_bonk:OnCreated()
	self.reduceCoolodwn = self:GetAbility():GetSpecialValueFor("reduce_cooldown")
end

function modifier_ogre_magi_bonk:OnRefresh()
	self:OnCreated()
end

function modifier_ogre_magi_bonk:OnAttackLanded(event)
	local parent = self:GetParent()

	if event.attacker == parent and event.target:IsHero() then
		for i=0,6 do
			local ability = parent:GetAbilityByIndex(i)

			if ability then
				local abilityTime = ability:GetCooldownTimeRemaining()
		        ability:EndCooldown()
		        ability:StartCooldown(abilityTime - self.reduceCoolodwn)
			end
		end
	end		
end