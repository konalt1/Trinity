LinkLuaModifier("modifier_ability_thirsty_blade_buff", "Juggernaut/ability_thirsty_blade", 0)
LinkLuaModifier("modifier_ability_thirsty_blade", "Juggernaut/ability_thirsty_blade", 0)
LinkLuaModifier("modifier_ability_thirsty_blade_debuff", "Juggernaut/ability_thirsty_blade", 0)

ability_thirsty_blade = class({})

--------------------------------------------------------------------------------
-- Initializations

function ability_thirsty_blade:IsHidden( kv )
	return false
end

function ability_thirsty_blade:IsDebuff( kv )
	return false
end

function ability_thirsty_blade:IsPurgable( kv )
	return false
end

function ability_thirsty_blade:RemoveOnDeath( kv )
	return false
end

function ability_thirsty_blade:GetIntrinsicModifierName()
	return "modifier_ability_thirsty_blade"
end
modifier_ability_thirsty_blade = class({})

function modifier_ability_thirsty_blade:DeclareFunctions()
	return{
		MODIFIER_EVENT_ON_ATTACK_LANDED
	}
end

function modifier_ability_thirsty_blade:OnAttackLanded( params )
	if IsServer() then
		local pass = false
		if params.attacker==self:GetParent() and params.target:IsHero() then
			self:GetParent():AddNewModifier(self:GetParent(), self:GetAbility(),"modifier_ability_thirsty_blade_buff" , {duration = 5})
			local stackPerSlow = self:GetAbility():GetSpecialValueFor("stack_per_slow")

			if stackPerSlow ~= 0 then 
				local modifier = self:GetParent():FindModifierByName("modifier_ability_thirsty_blade_buff")

				if modifier:GetStackCount() >= self:GetAbility():GetSpecialValueFor("stack_per_slow") then 
					params.target:AddNewModifier(self:GetParent(), self:GetAbility(), "modifier_ability_thirsty_blade_debuff", {duration = self:GetAbility():GetSpecialValueFor("duration_debuff")})
				end
			end
		end
	end
end

modifier_ability_thirsty_blade_buff = class({})

function modifier_ability_thirsty_blade_buff:DeclareFunctions()
	return{
		MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE
	}
end

function modifier_ability_thirsty_blade_buff:OnCreated(table)
	self:SetStackCount(0)
	self.stack_multiplier = self:GetAbility():GetSpecialValueFor("attack_damage")
	self.max_stacks = self:GetAbility():GetSpecialValueFor("max_stacks")
	self.currentTarget = {}
end

function modifier_ability_thirsty_blade_buff:GetModifierPreAttack_BonusDamage()
	return self:GetStackCount() * self.stack_multiplier	
end


function modifier_ability_thirsty_blade_buff:OnRefresh( kv )
	if self:GetStackCount() < self.max_stacks then
		self:IncrementStackCount()
	end
end

modifier_ability_thirsty_blade_debuff = class({
	IsHidden 				= function(self) return false end,
	IsPurgable 				= function(self) return true end,
	IsDebuff 				= function(self) return true end,
    DeclareFunctions        = function(self) return 
    {
    	MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
    } end,
})

function modifier_ability_thirsty_blade_debuff:OnCreated()
	self.slowMoveSpeed = self:GetAbility():GetSpecialValueFor("slow_move_speed")
end

function modifier_ability_thirsty_blade_debuff:GetModifierMoveSpeedBonus_Percentage()
	return self.slowMoveSpeed
end