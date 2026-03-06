LinkLuaModifier('modifier_weaver_cucaracha', 'abilities/Weaver/Cucaracha', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_weaver_cucaracha_invis', 'abilities/Weaver/Cucaracha', LUA_MODIFIER_MOTION_NONE)

weaver_cucaracha = class({})

function weaver_cucaracha:Precache(context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_weaver.vsndevts", context)
	PrecacheResource("particle", "particles/units/heroes/hero_weaver/weaver_shukuchi.vpcf", context)
	PrecacheResource("particle", "particles/generic_gameplay/generic_buff.vpcf", context)
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
		MODIFIER_PROPERTY_STATS_AGILITY_BONUS,
		MODIFIER_PROPERTY_TOOLTIP,
	} end,
})

function modifier_weaver_cucaracha:OnCreated()
	local ability = self:GetAbility()
	if not ability then return end

	if not IsServer() then return end

	local caster = self:GetCaster()
	local parent = self:GetParent()

	self.base_agility_bonus = ability:GetSpecialValueFor("base_agility_bonus")
	self.target_scale = ability:GetSpecialValueFor("model_scale")

	local mind_power_multiplier = ability:GetSpecialValueFor("mind_power_multiplier")
	local mind_power = GetHeroMindPower(caster)
	self.total_agility_bonus = math.max(0, self.base_agility_bonus + (mind_power * mind_power_multiplier))

	self:SetStackCount(math.floor(self.total_agility_bonus))

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

	self:PlayEffects()

	-- Shard: применяем модификатор невидимости
	if HasShard(parent) then
		local duration = self:GetRemainingTime()
		parent:AddNewModifier(caster, ability, "modifier_weaver_cucaracha_invis", { duration = duration })
	end
end

function modifier_weaver_cucaracha:OnRefresh()
	if not IsServer() then return end

	local ability = self:GetAbility()
	if not ability then return end

	local caster = self:GetCaster()

	self.base_agility_bonus = ability:GetSpecialValueFor("base_agility_bonus")
	local mind_power_multiplier = ability:GetSpecialValueFor("mind_power_multiplier")
	local mind_power = GetHeroMindPower(caster)
	self.total_agility_bonus = math.max(0, self.base_agility_bonus + (mind_power * mind_power_multiplier))
	self:SetStackCount(math.floor(self.total_agility_bonus))
end

function modifier_weaver_cucaracha:GetMindPower(hero)
	if not hero then return 0 end

	local intelligence_bonus = hero:GetIntellect(false)

	local item_bonus = 0
	for i = 0, 8 do
		local item = hero:GetItemInSlot(i)
		if item then
			local mind_power_bonus_value = item:GetSpecialValueFor("mind_power_bonus")
			if mind_power_bonus_value and mind_power_bonus_value > 0 then
				item_bonus = item_bonus + mind_power_bonus_value
			end
		end
	end

	local local_bonus = 0
	for _, modifier in pairs(hero:FindAllModifiers()) do
		if modifier.GetModifierMindPowerBonus and modifier ~= self then
			local bonus = modifier:GetModifierMindPowerBonus()
			if bonus and bonus > 0 then
				local_bonus = local_bonus + bonus
			end
		end
	end

	return intelligence_bonus + item_bonus + local_bonus
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
		self:StartIntervalThink(-1)
		return
	end

	parent:SetModelScale(self.current_scale)
end

function modifier_weaver_cucaracha:GetModifierBonusStats_Agility()
	if IsServer() then
		return self.total_agility_bonus or 0
	end
	return self:GetStackCount()
end

function modifier_weaver_cucaracha:OnTooltip()
	if IsServer() then
		return self.total_agility_bonus or 0
	end
	return self:GetStackCount()
end

function modifier_weaver_cucaracha:GetTexture()
	return "weaver_shukuchi"
end

function modifier_weaver_cucaracha:PlayEffects()
	local parent = self:GetParent()
	if not parent or not IsValidEntity(parent) then return end

	-- Визуальный эффект баффа без "хвоста"
	local particle = ParticleManager:CreateParticle(
		"particles/generic_gameplay/generic_buff.vpcf",
		PATTACH_ABSORIGIN_FOLLOW,
		parent
	)
	ParticleManager:ReleaseParticleIndex(particle)
end

function modifier_weaver_cucaracha:OnDestroy()
	if not IsServer() then return end

	local parent = self:GetParent()
	if not parent or not IsValidEntity(parent) then return end

	-- Удаляем модификатор невидимости при окончании Cucaracha
	parent:RemoveModifierByName("modifier_weaver_cucaracha_invis")

	local ability = self:GetAbility()
	if ability then
		ability:StartGrowAnimation(parent, self.current_scale or self.target_scale or 0.5)
	else
		parent:SetModelScale(1.0)
	end

	EmitSoundOn("Hero_Weaver.Shukuchi.End", parent)
end

--------------------------------------------------------------------------------
-- Shard Modifier: Невидимость во время Cucaracha
--------------------------------------------------------------------------------
modifier_weaver_cucaracha_invis = class({
	IsHidden = function(self) return false end,
	IsPurgable = function(self) return false end,
	IsBuff = function(self) return true end,
	RemoveOnDeath = function(self) return true end,
	GetAttributes = function(self) return MODIFIER_ATTRIBUTE_NONE end,
})

function modifier_weaver_cucaracha_invis:DeclareFunctions()
	return {
		MODIFIER_EVENT_ON_ATTACK,
		MODIFIER_EVENT_ON_ABILITY_EXECUTED,
	}
end

function modifier_weaver_cucaracha_invis:CheckState()
	if self.is_visible then
		return {}
	end
	return {
		[MODIFIER_STATE_INVISIBLE] = true,
	}
end

function modifier_weaver_cucaracha_invis:OnCreated()
	if not IsServer() then return end

	self.fade_time = 1.0
	self.is_visible = true -- Начинаем видимыми, fade time до невидимости

	-- Запускаем таймер для перехода в невидимость
	self:StartFadeTimer()
end

function modifier_weaver_cucaracha_invis:OnRefresh()
	if not IsServer() then return end
	-- При рефреше обновляем длительность, но не сбрасываем состояние
end

function modifier_weaver_cucaracha_invis:StartFadeTimer()
	if self.fade_timer then
		Timers:RemoveTimer(self.fade_timer)
		self.fade_timer = nil
	end

	local parent = self:GetParent()
	self.fade_timer = Timers:CreateTimer(self.fade_time, function()
		if not self or self:IsNull() then return nil end
		if not parent or not IsValidEntity(parent) then return nil end

		self.is_visible = false
		self:PlayInvisEffects()
		return nil
	end)
end

function modifier_weaver_cucaracha_invis:BreakInvisibility()
	if not IsServer() then return end

	-- Если уже видимы, просто перезапускаем таймер (сброс при повторных атаках)
	if self.is_visible then
		self:StartFadeTimer()
		return
	end

	self.is_visible = true
	self:StopInvisEffects()
	self:StartFadeTimer()
end

-- Отслеживание атаки
function modifier_weaver_cucaracha_invis:OnAttack(event)
	if not IsServer() then return end
	if event.attacker ~= self:GetParent() then return end

	self:BreakInvisibility()
end

-- Отслеживание применения способностей
function modifier_weaver_cucaracha_invis:OnAbilityExecuted(event)
	if not IsServer() then return end
	if event.unit ~= self:GetParent() then return end

	-- Проверяем, что это не предмет (предметы обрабатываются отдельно через OnInventoryContentsChanged)
	local ability = event.ability
	if ability and ability:IsItem() then
		self:BreakInvisibility()
		return
	end

	self:BreakInvisibility()
end

function modifier_weaver_cucaracha_invis:PlayInvisEffects()
	local parent = self:GetParent()
	if not parent or not IsValidEntity(parent) then return end

	-- Стандартный эффект Shukuchi невидимости
	if self.invis_particle then
		ParticleManager:DestroyParticle(self.invis_particle, false)
		ParticleManager:ReleaseParticleIndex(self.invis_particle)
	end

	self.invis_particle = ParticleManager:CreateParticle(
		"particles/units/heroes/hero_weaver/weaver_shukuchi.vpcf",
		PATTACH_ABSORIGIN_FOLLOW,
		parent
	)
	ParticleManager:SetParticleControl(self.invis_particle, 0, parent:GetAbsOrigin())
end

function modifier_weaver_cucaracha_invis:StopInvisEffects()
	if self.invis_particle then
		ParticleManager:DestroyParticle(self.invis_particle, false)
		ParticleManager:ReleaseParticleIndex(self.invis_particle)
		self.invis_particle = nil
	end
end

function modifier_weaver_cucaracha_invis:OnDestroy()
	if not IsServer() then return end

	if self.fade_timer then
		Timers:RemoveTimer(self.fade_timer)
		self.fade_timer = nil
	end

	self:StopInvisEffects()
end

function modifier_weaver_cucaracha_invis:GetTexture()
	return "weaver_shukuchi"
end

function modifier_weaver_cucaracha_invis:GetEffectName()
	return ""
end
