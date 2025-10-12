LinkLuaModifier('modifier_ogre_magi_strength_boost', 'abilities/ogre_magi/ogre_magi_strength_boost', LUA_MODIFIER_MOTION_NONE)

ogre_magi_strength_boost = class({})

function ogre_magi_strength_boost:Precache(context)
	-- Звуки для способности
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_ogre_magi.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_alchemist.vsndevts", context)
	
	-- Частицы для эффектов
	PrecacheResource("particle", "particles/units/heroes/hero_ogre_magi/ogre_magi_bloodlust.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_alchemist/alchemist_chemical_rage.vpcf", context)
	PrecacheResource("particle", "particles/generic_gameplay/generic_buff.vpcf", context)
end

function ogre_magi_strength_boost:IsStealable()
	return false
end

function ogre_magi_strength_boost:IsHidden()
	return false
end

function ogre_magi_strength_boost:OnSpellStart()
	local caster = self:GetCaster()
	local duration = self:GetSpecialValueFor("duration")
	
	-- Прерываем анимацию уменьшения, если она идет
	if caster.ogre_shrinking then
		caster.ogre_shrinking = nil
		caster.ogre_scale_step = nil
		caster.ogre_shrink_ability = nil
		-- Текущий размер сохраняем для плавного перехода
	end
	
	-- Применяем модификатор к кастеру
	caster:AddNewModifier(
		caster,
		self,
		"modifier_ogre_magi_strength_boost",
		{ duration = duration }
	)
	
	-- Звуковые эффекты
	EmitSoundOn("Hero_OgreMagi.Bloodlust.Cast", caster)
	EmitSoundOn("Hero_Alchemist.ChemicalRage.Cast", caster)
	
	-- Убираем проблемный эффект каста, который улетает в центр карты
end

function ogre_magi_strength_boost:StartShrinkAnimation(hero, current_scale)
	if not hero or not IsValidEntity(hero) then return end
	
	-- Проверяем, не идет ли уже анимация уменьшения
	if hero.ogre_shrinking then return end
	
	-- Если размер уже нормальный, ничего не делаем
	if current_scale <= 1.05 then  -- небольшая погрешность
		hero:SetModelScale(1.0)
		return
	end
	
	-- Настройки анимации уменьшения
	hero.ogre_shrinking = true
	hero.ogre_current_scale = current_scale
	hero.ogre_scale_step = (current_scale - 1.0) / 15  -- 15 шагов
	hero.ogre_shrink_ability = self
	
	-- Запускаем таймер уменьшения
	Timers:CreateTimer(0.05, function()
		return self:ShrinkAnimationThink(hero)
	end)
end

function ogre_magi_strength_boost:ShrinkAnimationThink(hero)
	if not hero or not IsValidEntity(hero) or not hero.ogre_shrinking then
		return nil  -- Останавливаем таймер
	end
	
	-- Уменьшаем размер
	hero.ogre_current_scale = hero.ogre_current_scale - hero.ogre_scale_step
	
	-- Проверяем, достигли ли нормального размера
	if hero.ogre_current_scale <= 1.0 then
		hero.ogre_current_scale = 1.0
		hero:SetModelScale(1.0)
		-- Очищаем переменные
		hero.ogre_shrinking = nil
		hero.ogre_current_scale = nil
		hero.ogre_scale_step = nil
		hero.ogre_shrink_ability = nil
		return nil  -- Останавливаем таймер
	end
	
	-- Применяем новый размер
	hero:SetModelScale(hero.ogre_current_scale)
	
	-- Продолжаем анимацию
	return 0.05
end

-- Модификатор для усиления силы
modifier_ogre_magi_strength_boost = class({
	IsHidden 				= function(self) return false end,
	IsPurgable 				= function(self) return true end,
	IsBuff                  = function(self) return true end,
	RemoveOnDeath 			= function(self) return true end,
	DeclareFunctions        = function(self) return 
    {
    	MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
    } end,
})

function modifier_ogre_magi_strength_boost:OnCreated()
	if not IsServer() then return end
	
	local ability = self:GetAbility()
	local caster = self:GetCaster()
	
	-- Базовый бонус силы от уровня способности
	self.base_strength_bonus = ability:GetSpecialValueFor("base_strength_bonus")
	
	-- Множитель Mind Power
	local mind_power_multiplier = ability:GetSpecialValueFor("mind_power_multiplier")
	
	-- Получаем Mind Power кастера
	local mind_power = self:GetMindPower(caster)
	
	-- Вычисляем бонус от Mind Power
	local mind_power_bonus = mind_power * mind_power_multiplier
	
	-- Итоговый бонус силы
	self.total_strength_bonus = self.base_strength_bonus + mind_power_bonus
	
	-- Рассчитываем размер модели: 100% + X%, где X = полученная сила, максимум 200%
	local size_bonus = 100 + self.total_strength_bonus
	self.target_scale = math.min(size_bonus, 200) / 100  -- Переводим в множитель (2.0 максимум)
	
	local parent = self:GetParent()
	-- Начинаем с текущего размера (если был прерван shrink) или с нормального
	if parent and parent.ogre_current_scale then
		self.current_scale = parent.ogre_current_scale
		parent.ogre_current_scale = nil  -- Очищаем
	else
		self.current_scale = 1.0
	end
	
	self.scale_increment = (self.target_scale - self.current_scale) / 20  -- 20 шагов для плавности
	self.scale_timer = 0.05  -- Интервал обновления (50мс)
	
	-- Проверяем, что increment не равен нулю
	if math.abs(self.scale_increment) < 0.001 then
		-- Если разница маленькая, сразу устанавливаем целевой размер
		local parent = self:GetParent()
		if parent and IsValidEntity(parent) then
			parent:SetModelScale(self.target_scale)
		end
		return
	end
	
	
	-- Запускаем анимацию увеличения
	self:StartThinking()
	
	-- Создаем визуальный эффект
	self:PlayEffects()
end

function modifier_ogre_magi_strength_boost:GetMindPower(hero)
	if not hero then return 0 end
	
	-- Базовый Mind Power от интеллекта
	local intelligence_bonus = hero:GetIntellect(false)
	
	-- Бонусы от предметов
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
	
	-- Локальные бонусы от других модификаторов
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

function modifier_ogre_magi_strength_boost:OnRefresh()
	self:OnCreated()
end

function modifier_ogre_magi_strength_boost:OnIntervalThink()
	if not IsServer() then return end
	
	local parent = self:GetParent()
	if not parent or not IsValidEntity(parent) then return end
	
	
	-- Если уменьшаемся (при окончании баффа)
	if self.shrinking then
		self.current_scale = self.current_scale - math.abs(self.scale_increment)
		if self.current_scale <= 1.0 then
			self.current_scale = 1.0
			parent:SetModelScale(self.current_scale)
			self:StopThinking()
			return
		end
	-- Если увеличиваемся (при активации)
	else
		self.current_scale = self.current_scale + self.scale_increment
		if self.current_scale >= self.target_scale then
			self.current_scale = self.target_scale
			parent:SetModelScale(self.current_scale)
			self:StopThinking()
			return
		end
	end
	
	-- Применяем текущий размер
	parent:SetModelScale(self.current_scale)
	
	-- Планируем следующее обновление
	self:StartIntervalThink(self.scale_timer)
end

function modifier_ogre_magi_strength_boost:StartThinking()
	self:StartIntervalThink(self.scale_timer)
end

function modifier_ogre_magi_strength_boost:StopThinking()
	self:StartIntervalThink(-1)
end

function modifier_ogre_magi_strength_boost:GetModifierBonusStats_Strength()
	return self.total_strength_bonus or 0
end

function modifier_ogre_magi_strength_boost:GetModifierDescription()
	local display_value = math.floor(self.total_strength_bonus or 0)
	return "Increases Strength by " .. display_value .. " points."
end

function modifier_ogre_magi_strength_boost:GetTexture()
	return "ogre_magi_strength_boost"
end

function modifier_ogre_magi_strength_boost:PlayEffects()
	local parent = self:GetParent()
	
	if not parent or not IsValidEntity(parent) then return end
	
	-- Пока убираем эффекты и оставляем только звук
	EmitSoundOn("Hero_OgreMagi.Bloodlust.Target", parent)
end

function modifier_ogre_magi_strength_boost:OnDestroy()
	if not IsServer() then return end
	
	local parent = self:GetParent()
	if not parent or not IsValidEntity(parent) then return end
	
	local ability = self:GetAbility()
	if ability then
		-- Запускаем анимацию уменьшения через способность
		ability:StartShrinkAnimation(parent, self.current_scale or 1.0)
	else
		-- Если способности нет, просто возвращаем нормальный размер
		parent:SetModelScale(1.0)
	end
	
	-- Звук окончания баффа
	EmitSoundOn("Hero_Alchemist.ChemicalRage.End", parent)
end

