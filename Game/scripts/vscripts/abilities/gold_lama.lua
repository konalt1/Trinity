LinkLuaModifier('modifier_gold_lama', 'abilities/gold_lama', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_gold_lama_buff', 'abilities/gold_lama', LUA_MODIFIER_MOTION_NONE)

gold_lama = class({})

function gold_lama:GetIntrinsicModifierName()
	return "modifier_gold_lama"
end

modifier_gold_lama = class({
	IsHidden 				= function(self) return false end,
	IsBuff                  = function(self) return true end,
	IsAura 				= function(self) return true end,
	GetModifierAura 				= function(self) return "modifier_gold_lama_buff" end,
	GetAuraSearchTeam 				= function(self) return DOTA_UNIT_TARGET_TEAM_FRIENDLY end,
	GetAuraRadius 				= function(self) return self:GetAbility():GetSpecialValueFor("radius") end,
	GetAuraSearchType 				= function(self) return DOTA_UNIT_TARGET_CREEP end,
    DeclareFunctions        = function(self) return 
    {
    	MODIFIER_EVENT_ON_TAKEDAMAGE,
    } end,
    CheckState      = function(self) return 
    {
     	[MODIFIER_STATE_SPECIALLY_UNDENIABLE] = true,
    } end,
})

function modifier_gold_lama:OnCreated()
	local ability = self:GetAbility()

	self:SetStackCount(ability:GetSpecialValueFor("gold"))	
end

function modifier_gold_lama:OnTakeDamage(event)
	if event.unit ~= self:GetParent() then return end
	local attacker = event.attacker

	if not attacker:IsRealHero() then return end

	local damage = event.damage
	local stack = self:GetStackCount()

	if stack <= 0 then return end

	attacker:ModifyGold(math.min(damage, stack), false, DOTA_ModifyGold_CreepKill)
	self:SetStackCount(math.max(stack - damage, 0))
end

modifier_gold_lama_buff = class({
	IsHidden 				= function(self) return true end,
    DeclareFunctions        = function(self) return 
    {
    	MODIFIER_PROPERTY_DAMAGEOUTGOING_PERCENTAGE
    } end,
})

function modifier_gold_lama_buff:OnCreated()
	self.bonusDamagePct = self:GetAbility():GetSpecialValueFor("bonus_damage_pct")
end


function modifier_gold_lama_buff:GetModifierDamageOutgoing_Percentage()
    return self.bonusDamagePct
end
