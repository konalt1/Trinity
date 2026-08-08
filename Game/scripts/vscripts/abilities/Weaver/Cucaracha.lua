LinkLuaModifier('modifier_weaver_cucaracha', 'abilities/Weaver/Cucaracha', LUA_MODIFIER_MOTION_NONE)

weaver_cucaracha = class({})

function weaver_cucaracha:Precache(context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_weaver.vsndevts", context)
end

function weaver_cucaracha:IsStealable()
	return false
end

function weaver_cucaracha:IsHidden()
	return false
end

function weaver_cucaracha:OnSpellStart()
	local caster = self:GetCaster()
	local duration = self:GetSpecialValueFor("duration")

	-- Прерываем анимацию восстановления размера, если она идет
	if caster.cucaracha_growing then
		caster.cucaracha_growing = nil
		caster.cucaracha_scale_step = nil
		caster.cucaracha_ability = nil
	end

	caster:AddNewModifier(caster, self, "modifier_weaver_cucaracha", { duration = duration })
	EmitSoundOn("Hero_Weaver.Shukuchi", caster)
end

-- Плавное восстановление размера после окончания эффекта
function weaver_cucaracha:StartGrowAnimation(hero, current_scale)
	if not hero or not IsValidEntity(hero) then return end
	if hero.cucaracha_growing then return end

	if current_scale >= 0.95 then
		hero:SetModelScale(1.0)
		return
	end

	hero.cucaracha_growing = true
	hero.cucaracha_current_scale = current_scale
	hero.cucaracha_scale_step = (1.0 - current_scale) / 15
	hero.cucaracha_ability = self

	Timers:CreateTimer(0.03, function()
		return self:GrowAnimationThink(hero)
	end)
end

function weaver_cucaracha:GrowAnimationThink(hero)
	if not hero or not IsValidEntity(hero) or not hero.cucaracha_growing then
		return nil
	end

	hero.cucaracha_current_scale = hero.cucaracha_current_scale + hero.cucaracha_scale_step

	if hero.cucaracha_current_scale >= 1.0 then
		hero.cucaracha_current_scale = 1.0
		hero:SetModelScale(1.0)
		hero.cucaracha_growing = nil
		hero.cucaracha_current_scale = nil
		hero.cucaracha_scale_step = nil
		hero.cucaracha_ability = nil
		return nil
	end

	hero:SetModelScale(hero.cucaracha_current_scale)
	return 0.03
end

--------------------------------------------------------------------------------
-- Modifier
--------------------------------------------------------------------------------
modifier_weaver_cucaracha = class({
	IsHidden = function(self) return false end,
	IsPurgable = function(self) return true end,
	IsBuff = function(self) return true end,
	RemoveOnDeath = function(self) return true end,
	GetAttributes = function(self) return MODIFIER_ATTRIBUTE_NONE end,
	DeclareFunctions = function(self) return
	{
		MODIFIER_PROPERTY_MOVESPEED_ABSOLUTE,
		MODIFIER_PROPERTY_PREATTACK_CRITICALSTRIKE,
		MODIFIER_PROPERTY_TOOLTIP,
	} end,
})

function modifier_weaver_cucaracha:CheckState()
	return {
		[MODIFIER_STATE_NO_HEALTH_BAR] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
	}
end

function modifier_weaver_cucaracha:OnCreated()
	local ability = self:GetAbility()
	if not ability then return end
	self.crit_damage = ability:GetSpecialValueFor("crit_damage")

	if not IsServer() then return end

	local parent = self:GetParent()

	self.move_speed = ability:GetSpecialValueFor("move_speed")
	self.target_scale = ability:GetSpecialValueFor("model_scale")

	self:SetStackCount(math.floor(self.move_speed))

	if parent and parent.cucaracha_current_scale then
		self.current_scale = parent.cucaracha_current_scale
		parent.cucaracha_current_scale = nil
	else
		self.current_scale = 1.0
	end

	-- Плавное уменьшение размера
	if self.target_scale and self.target_scale > 0 and self.current_scale > self.target_scale + 0.001 then
		self.scale_decrement = (self.current_scale - self.target_scale) / 15
		self:StartIntervalThink(0.03)
	else
		self.current_scale = self.target_scale or self.current_scale
		if parent and IsValidEntity(parent) and self.current_scale then
			parent:SetModelScale(self.current_scale)
		end
	end

end

function modifier_weaver_cucaracha:OnRefresh()
	if not IsServer() then return end

	local ability = self:GetAbility()
	if not ability then return end

	self.crit_damage = ability:GetSpecialValueFor("crit_damage")
	self.move_speed = ability:GetSpecialValueFor("move_speed")
	self.target_scale = ability:GetSpecialValueFor("model_scale")
	self:SetStackCount(math.floor(self.move_speed))

end

function modifier_weaver_cucaracha:OnIntervalThink()
	if not IsServer() then return end

	local parent = self:GetParent()
	if not parent or not IsValidEntity(parent) then return end

	if not self.scale_decrement or not self.target_scale then
		self:StartIntervalThink(-1)
		return
	end

	self.current_scale = self.current_scale - self.scale_decrement

	if self.current_scale <= self.target_scale then
		self.current_scale = self.target_scale
		parent:SetModelScale(self.current_scale)
		self.scale_decrement = nil
		self:StartIntervalThink(-1)
		return
	end

	parent:SetModelScale(self.current_scale)
end

function modifier_weaver_cucaracha:GetModifierMoveSpeed_Absolute()
	if IsServer() then
		return self.move_speed or 0
	end
	return self:GetStackCount()
end

function modifier_weaver_cucaracha:GetModifierPreAttack_CriticalStrike(params)
	if params.attacker ~= self:GetParent() then return end
	return self.crit_damage or 0
end

function modifier_weaver_cucaracha:OnTooltip()
	if IsServer() then
		return self.move_speed or 0
	end
	return self:GetStackCount()
end

function modifier_weaver_cucaracha:GetTexture()
	return "weaver_shukuchi"
end

function modifier_weaver_cucaracha:OnDestroy()
	if not IsServer() then return end

	local parent = self:GetParent()
	if not parent or not IsValidEntity(parent) then return end
	local ability = self:GetAbility()
	if ability then
		ability:StartGrowAnimation(parent, self.current_scale or self.target_scale or 0.5)
	else
		parent:SetModelScale(1.0)
	end

	EmitSoundOn("Hero_Weaver.Shukuchi.End", parent)
end
