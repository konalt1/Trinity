LinkLuaModifier('modifier_tinker_rearm_custom', 'abilities/tinker/tinker_rearm_custom', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_tinker_rearm_custom_passive', 'abilities/tinker/tinker_rearm_custom', LUA_MODIFIER_MOTION_NONE)

tinker_rearm_custom = class({})

function tinker_rearm_custom:GetIntrinsicModifierName()
	return "modifier_tinker_rearm_custom_passive"
end

function tinker_rearm_custom:OnSpellStart()
	local caster = self:GetCaster()

	caster:AddNewModifier(caster, self, "modifier_tinker_rearm_custom", {duration = self:GetSpecialValueFor("duration")})

	if self:GetSpecialValueFor("avatar") ~= 0 then 
	    target:Purge(false, true, false, true, false)
	end
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
		MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS,
    } end,
    CheckState 				= function(self) return 
    {
    	[MODIFIER_STATE_DEBUFF_IMMUNE] = self.hasAvatar,
    } end,
})

function modifier_tinker_rearm_custom:OnCreated()
	local ability = self:GetAbility()
	self.cooldown = ability:GetSpecialValueFor("cooldown")
	self.hasAvatar = ability:GetSpecialValueFor("avatar") ~= 0

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

 
 modifier_tinker_rearm_custom_passive = class({
	IsHidden 				= function(self) return true end,
    DeclareFunctions        = function(self) return 
    {
    	MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE,
    } end,
})

function modifier_tinker_rearm_custom_passive:OnCreated()
	self.bonusSpellAmp = self:GetAbility():GetSpecialValueFor("spell_amp")
end

function modifier_tinker_rearm_custom_passive:OnRefresh()
	self:OnCreated()
end

function modifier_tinker_rearm_custom_passive:GetModifierSpellAmplify_Percentage()
	if not self:GetParent():HasModifier("modifier_tinker_rearm_custom") then 
		return self.bonusSpellAmp
	end
end
