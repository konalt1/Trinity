LinkLuaModifier('modifier_tinker_rearm_custom', 'abilities/tinker/tinker_rearm_custom', LUA_MODIFIER_MOTION_NONE)

tinker_rearm_custom = class({})

function tinker_rearm_custom:OnSpellStart()
	local caster = self:GetCaster()

	caster:AddNewModifier(caster, self, "modifier_tinker_rearm_custom", {duration = self:GetSpecialValueFor("duration")})
end

modifier_tinker_rearm_custom = class({
	IsHidden 				= function(self) return false end,
	IsPurgable 				= function(self) return false end,
	-- IsBuff                  = function(self) return true end,
	-- RemoveOnDeath 			= function(self) return true end,
    DeclareFunctions        = function(self) return 
    {
    	MODIFIER_PROPERTY_OVERRIDE_ANIMATION,
		MODIFIER_EVENT_ON_ABILITY_FULLY_CAST,
    } end,
})

function modifier_tinker_rearm_custom:OnCreated()
	self.cooldown = self:GetAbility():GetSpecialValueFor("cooldown")

	self:OnIntervalThink()
	self:StartIntervalThink(1.7)
end

function modifier_tinker_rearm_custom:OnAbilityFullyCast(event)
	if IsClient() then return end 

	local unit = event.unit
    local parent = self:GetParent()

    if unit ~= parent then return end
 	
 	local ability = event.ability

 	if ability ~= self:GetAbility() then 
 		ability:EndCooldown()
 		ability:StartCooldown(self.cooldown)
 	end
end

function modifier_tinker_rearm_custom:OnIntervalThink()
	if IsClient() then return end
	
	local parent = self:GetParent()
	EmitSoundOn("sounds/weapons/hero/tinker/rearm.vsnd", parent)

	parent:StartGesture(ACT_DOTA_TINKER_REARM3)
end

 