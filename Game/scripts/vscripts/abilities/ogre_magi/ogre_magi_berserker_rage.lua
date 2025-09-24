LinkLuaModifier('modifier_ogre_magi_berserker_rage', 'abilities/ogre_magi/ogre_magi_berserker_rage', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_ogre_magi_berserker_rage_attack_speed', 'abilities/ogre_magi/ogre_magi_berserker_rage', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_ogre_magi_berserker_rage_damage', 'abilities/ogre_magi/ogre_magi_berserker_rage', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_ogre_magi_berserker_rage_shield', 'abilities/ogre_magi/ogre_magi_berserker_rage', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_ogre_magi_berserker_rage_regen', 'abilities/ogre_magi/ogre_magi_berserker_rage', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_ogre_magi_berserker_rage_speed', 'abilities/ogre_magi/ogre_magi_berserker_rage', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_ogre_magi_berserker_rage_magic_resist', 'abilities/ogre_magi/ogre_magi_berserker_rage', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_ogre_magi_berserker_rage_lifesteal', 'abilities/ogre_magi/ogre_magi_berserker_rage', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_ogre_magi_berserker_rage_cooldown', 'abilities/ogre_magi/ogre_magi_berserker_rage', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_ogre_magi_berserker_rage_armor', 'abilities/ogre_magi/ogre_magi_berserker_rage', LUA_MODIFIER_MOTION_NONE)

ogre_magi_berserker_rage = class({})

function ogre_magi_berserker_rage:Precache(context)
	-- Звуки для разных эффектов
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_ogre_magi.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_abaddon.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_alchemist.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_antimage.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_bloodseeker.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_dragon_knight.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_items/game_sounds_items.vsndevts", context)
	
	-- Частицы для эффектов баффов
	PrecacheResource("particle", "particles/units/heroes/hero_ogre_magi/ogre_magi_fireblast.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_abaddon/abaddon_aphotic_shield_explosion.vpcf", context)
	PrecacheResource("particle", "particles/generic_gameplay/generic_lifesteal.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_ogre_magi/ogre_magi_bloodlust.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_alchemist/alchemist_chemical_rage.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_bloodseeker/bloodseeker_thirst.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_antimage/antimage_spell_shield.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_dragon_knight/dragon_knight_dragon_blood.vpcf", context)
	PrecacheResource("particle", "particles/items_fx/refresher_orb.vpcf", context)
end

function ogre_magi_berserker_rage:GetIntrinsicModifierName()
	return "modifier_ogre_magi_berserker_rage"
end

function ogre_magi_berserker_rage:IsStealable()
	return false
end

function ogre_magi_berserker_rage:IsHidden()
	return false
end

function ogre_magi_berserker_rage:GetCooldown(level)
	local cooldowns = {20, 15, 10}
	return cooldowns[level] or 20
end

-- Список возможных баффов
function ogre_magi_berserker_rage:GetRandomBuff()
	local buffs = {
		{
			name = "attack_speed",
			modifier = "modifier_ogre_magi_berserker_rage_attack_speed",
			duration = 10
		},
		{
			name = "damage",
			modifier = "modifier_ogre_magi_berserker_rage_damage",
			duration = 10
		},
		{
			name = "shield",
			modifier = "modifier_ogre_magi_berserker_rage_shield",
			duration = 15
		},
		{
			name = "regen",
			modifier = "modifier_ogre_magi_berserker_rage_regen",
			duration = 10
		},
		{
			name = "speed",
			modifier = "modifier_ogre_magi_berserker_rage_speed",
			duration = 10
		},
		{
			name = "magic_resist",
			modifier = "modifier_ogre_magi_berserker_rage_magic_resist",
			duration = 10
		},
		{
			name = "lifesteal",
			modifier = "modifier_ogre_magi_berserker_rage_lifesteal",
			duration = 10
		},
		{
			name = "cooldown",
			modifier = "modifier_ogre_magi_berserker_rage_cooldown",
			duration = 10
		},
		{
			name = "armor",
			modifier = "modifier_ogre_magi_berserker_rage_armor",
			duration = 10
		}
	}
	
	return buffs[RandomInt(1, #buffs)]
end

--------------------------------------------------------------------------------
-- Основной модификатор для отслеживания атак
modifier_ogre_magi_berserker_rage = class({
	IsHidden 				= function(self) return false end,
	IsPurgable 				= function(self) return false end,
	IsBuff                  = function(self) return true end,
	RemoveOnDeath 			= function(self) return false end,
    DeclareFunctions        = function(self) return 
    {
    	MODIFIER_EVENT_ON_ATTACK_LANDED,
    } end,
})

function modifier_ogre_magi_berserker_rage:OnCreated()
	if IsServer() then
		self.attack_count = 0
		self.attacks_needed = 10
		self.is_on_cooldown = false
		
		-- Устанавливаем начальный стек для отображения
		self:SetStackCount(self.attack_count)
	else
		-- На клиенте получаем значения из стеков
		self.attack_count = self:GetStackCount()
		self.attacks_needed = 10
	end
end

function modifier_ogre_magi_berserker_rage:OnRefresh()
	self:OnCreated()
end

function modifier_ogre_magi_berserker_rage:GetTexture()
	return "ogre_magi_multicast"
end

function modifier_ogre_magi_berserker_rage:OnAttackLanded(event)
	if not IsServer() then return end
	
	local parent = self:GetParent()
	local ability = self:GetAbility()
	local target = event.target
	local attacker = event.attacker
	
	-- Строгая проверка: только наш герой атакует
	if attacker ~= parent then 
		return 
	end
	
	-- Проверяем, что цель существует
	if not target or not IsValidEntity(target) then
		return
	end
	
	-- Проверяем, что цель - враг (не союзник)
	if target:GetTeamNumber() == parent:GetTeamNumber() then
		return
	end
	
	-- Проверяем, что цель жива
	if not target:IsAlive() then
		return
	end
	
	-- Исключаем здания и другие неподходящие цели
	if target:IsBuilding() or target:IsCourier() then
		return
	end
	
	-- Если способность на кулдауне, не накапливаем атаки
	if self.is_on_cooldown then
		return
	end
	
	-- Увеличиваем счётчик
	self.attack_count = self.attack_count + 1
	
	-- Обновляем визуальный счётчик
	self:SetStackCount(self.attack_count)
	
	-- Определяем тип цели для логирования
	local target_type = "unknown"
	if target:IsHero() then
		target_type = "hero"
	elseif target:IsCreep() then
		target_type = "creep"
	elseif target:IsNeutralUnitType() then
		target_type = "neutral"
	end
	
	-- Отображаем прогресс
	print("Ogre Berserker Rage: " .. self.attack_count .. "/" .. self.attacks_needed .. " attacks vs " .. target:GetUnitName() .. " (" .. target_type .. ")")
	
	-- Показываем эффект при атаке (только каждую 2-ю атаку, чтобы не спамить)
	if self.attack_count % 2 == 0 or self.attack_count >= self.attacks_needed then
		local particle = ParticleManager:CreateParticle(
			"particles/units/heroes/hero_ogre_magi/ogre_magi_fireblast.vpcf",
			PATTACH_OVERHEAD_FOLLOW,
			parent
		)
		ParticleManager:SetParticleControl(particle, 1, Vector(self.attack_count, 0, 0))
		ParticleManager:ReleaseParticleIndex(particle)
	end
	
	-- Если достигли нужного количества атак
	if self.attack_count >= self.attacks_needed then
		self:TriggerBerserkerRage()
	end
end

function modifier_ogre_magi_berserker_rage:TriggerBerserkerRage()
	if not IsServer() then return end
	
	local parent = self:GetParent()
	local ability = self:GetAbility()
	
	-- Сброс счётчика атак
	self.attack_count = 0
	self:SetStackCount(self.attack_count)
	
	-- Активируем кулдаун
	self.is_on_cooldown = true
	local cooldown_duration = ability:GetCooldown(ability:GetLevel())
	ability:StartCooldown(cooldown_duration)
	
	-- Получаем случайный бафф
	local random_buff = ability:GetRandomBuff()
	
	-- Применяем бафф
	parent:AddNewModifier(
		parent,
		ability,
		random_buff.modifier,
		{ duration = random_buff.duration }
	)
	
	-- Большой эффект активации
	EmitSoundOn("Hero_OgreMagi.Fireblast.Target", parent)
	EmitSoundOn("Hero_OgreMagi.Multicast.x3", parent)
	
	-- Яркий particle effect при активации
	local particle = ParticleManager:CreateParticle(
		"particles/units/heroes/hero_ogre_magi/ogre_magi_fireblast.vpcf",
		PATTACH_ABSORIGIN_FOLLOW,
		parent
	)
	ParticleManager:SetParticleControlEnt(
		particle,
		0,
		parent,
		PATTACH_POINT_FOLLOW,
		"attach_hitloc",
		parent:GetOrigin(),
		true
	)
	ParticleManager:ReleaseParticleIndex(particle)
	
	-- Дополнительный эффект взрыва
	local explosion_particle = ParticleManager:CreateParticle(
		"particles/units/heroes/hero_ogre_magi/ogre_magi_bloodlust_cast.vpcf",
		PATTACH_ABSORIGIN_FOLLOW,
		parent
	)
	ParticleManager:ReleaseParticleIndex(explosion_particle)
	
	-- Снимаем кулдаун через заданное время
	Timers:CreateTimer(cooldown_duration, function()
		if self and not self:IsNull() then
			self.is_on_cooldown = false
		end
	end)
	
	print("Ogre Berserker Rage activated! Buff: " .. random_buff.name)
end

--------------------------------------------------------------------------------
-- Модификаторы баффов

-- Увеличение скорости атаки
modifier_ogre_magi_berserker_rage_attack_speed = class({
	IsHidden 				= function(self) return false end,
	IsPurgable 				= function(self) return true end,
	IsBuff                  = function(self) return true end,
	RemoveOnDeath 			= function(self) return true end,
	DeclareFunctions        = function(self) return 
    {
    	MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
    } end,
})

function modifier_ogre_magi_berserker_rage_attack_speed:OnCreated()
	self.attack_speed_bonus = 20
end

function modifier_ogre_magi_berserker_rage_attack_speed:GetModifierAttackSpeedBonus_Constant()
	return self.attack_speed_bonus
end

function modifier_ogre_magi_berserker_rage_attack_speed:GetTexture()
	return "ogre_magi_bloodlust"
end

-- Увеличение урона
modifier_ogre_magi_berserker_rage_damage = class({
	IsHidden 				= function(self) return false end,
	IsPurgable 				= function(self) return true end,
	IsBuff                  = function(self) return true end,
	RemoveOnDeath 			= function(self) return true end,
	DeclareFunctions        = function(self) return 
    {
    	MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
    } end,
})

function modifier_ogre_magi_berserker_rage_damage:OnCreated()
	self.damage_bonus = 25
end

function modifier_ogre_magi_berserker_rage_damage:GetModifierPreAttack_BonusDamage()
	return self.damage_bonus
end

function modifier_ogre_magi_berserker_rage_damage:GetTexture()
	return "ogre_magi_multicast"
end

-- Щит (аналог Aphotic Shield)
modifier_ogre_magi_berserker_rage_shield = class({
	IsHidden 				= function(self) return false end,
	IsPurgable 				= function(self) return true end,
	IsBuff                  = function(self) return true end,
	RemoveOnDeath 			= function(self) return true end,
	DeclareFunctions        = function(self) return 
    {
    	MODIFIER_PROPERTY_INCOMING_DAMAGE_CONSTANT,
    } end,
})

function modifier_ogre_magi_berserker_rage_shield:OnCreated()
	if not IsServer() then return end
	self.damage_absorbed = 0
	self.max_absorb = 200
	self.explosion_radius = 675
	self.explosion_damage = 100
end

function modifier_ogre_magi_berserker_rage_shield:GetModifierIncomingDamageConstant(params)
	if not IsServer() then return 0 end
	
	local damage = params.damage
	local remaining_absorb = self.max_absorb - self.damage_absorbed
	
	if remaining_absorb <= 0 then
		return 0
	end
	
	local absorbed = math.min(damage, remaining_absorb)
	self.damage_absorbed = self.damage_absorbed + absorbed
	
	-- Если щит полностью поглотил урон, взрываем его
	if self.damage_absorbed >= self.max_absorb then
		self:ExplodeShield()
		self:Destroy()
	end
	
	return absorbed
end

function modifier_ogre_magi_berserker_rage_shield:ExplodeShield()
	if not IsServer() then return end
	
	local parent = self:GetParent()
	local ability = self:GetAbility()
	
	-- Находим врагов в радиусе
	local enemies = FindUnitsInRadius(
		parent:GetTeamNumber(),
		parent:GetOrigin(),
		nil,
		self.explosion_radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)
	
	-- Наносим урон
	for _, enemy in pairs(enemies) do
		local damageTable = {
			victim = enemy,
			attacker = parent,
			damage = self.explosion_damage,
			damage_type = DAMAGE_TYPE_MAGICAL,
			ability = ability,
			damage_flags = DOTA_DAMAGE_FLAG_NONE
		}
		ApplyDamage(damageTable)
	end
	
	-- Эффекты взрыва
	local particle = ParticleManager:CreateParticle(
		"particles/units/heroes/hero_abaddon/abaddon_aphotic_shield_explosion.vpcf",
		PATTACH_WORLDORIGIN,
		nil
	)
	ParticleManager:SetParticleControl(particle, 0, parent:GetOrigin())
	ParticleManager:SetParticleControl(particle, 1, Vector(self.explosion_radius, 0, 0))
	ParticleManager:ReleaseParticleIndex(particle)
	
	EmitSoundOn("Hero_Abaddon.AphoticShield.Destroy", parent)
end

function modifier_ogre_magi_berserker_rage_shield:OnDestroy()
	if not IsServer() then return end
	-- Если щит истёк естественным образом, тоже взрываем
	if self.damage_absorbed < self.max_absorb then
		self:ExplodeShield()
	end
end

function modifier_ogre_magi_berserker_rage_shield:GetTexture()
	return "abaddon_aphotic_shield"
end

-- Регенерация здоровья
modifier_ogre_magi_berserker_rage_regen = class({
	IsHidden 				= function(self) return false end,
	IsPurgable 				= function(self) return true end,
	IsBuff                  = function(self) return true end,
	RemoveOnDeath 			= function(self) return true end,
	DeclareFunctions        = function(self) return 
    {
    	MODIFIER_PROPERTY_HEALTH_REGEN_PERCENTAGE,
    } end,
})

function modifier_ogre_magi_berserker_rage_regen:OnCreated()
	self.health_regen_pct = 5
end

function modifier_ogre_magi_berserker_rage_regen:GetModifierHealthRegenPercentage()
	return self.health_regen_pct
end

function modifier_ogre_magi_berserker_rage_regen:GetTexture()
	return "alchemist_chemical_rage"
end

-- Увеличение скорости передвижения
modifier_ogre_magi_berserker_rage_speed = class({
	IsHidden 				= function(self) return false end,
	IsPurgable 				= function(self) return true end,
	IsBuff                  = function(self) return true end,
	RemoveOnDeath 			= function(self) return true end,
	DeclareFunctions        = function(self) return 
    {
    	MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
    } end,
})

function modifier_ogre_magi_berserker_rage_speed:OnCreated()
	self.move_speed_bonus = 15
end

function modifier_ogre_magi_berserker_rage_speed:GetModifierMoveSpeedBonus_Percentage()
	return self.move_speed_bonus
end

function modifier_ogre_magi_berserker_rage_speed:GetTexture()
	return "bloodseeker_thirst"
end

-- Сопротивление магии
modifier_ogre_magi_berserker_rage_magic_resist = class({
	IsHidden 				= function(self) return false end,
	IsPurgable 				= function(self) return true end,
	IsBuff                  = function(self) return true end,
	RemoveOnDeath 			= function(self) return true end,
	DeclareFunctions        = function(self) return 
    {
    	MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS,
    } end,
})

function modifier_ogre_magi_berserker_rage_magic_resist:OnCreated()
	self.magic_resist_bonus = 30
end

function modifier_ogre_magi_berserker_rage_magic_resist:GetModifierMagicalResistanceBonus()
	return self.magic_resist_bonus
end

function modifier_ogre_magi_berserker_rage_magic_resist:GetTexture()
	return "anti_mage_spell_shield"
end

-- Вампиризм
modifier_ogre_magi_berserker_rage_lifesteal = class({
	IsHidden 				= function(self) return false end,
	IsPurgable 				= function(self) return true end,
	IsBuff                  = function(self) return true end,
	RemoveOnDeath 			= function(self) return true end,
	DeclareFunctions        = function(self) return 
    {
    	MODIFIER_EVENT_ON_ATTACK_LANDED,
    } end,
})

function modifier_ogre_magi_berserker_rage_lifesteal:OnCreated()
	self.lifesteal_pct = 20
end

function modifier_ogre_magi_berserker_rage_lifesteal:OnAttackLanded(event)
	if not IsServer() then return end
	
	local parent = self:GetParent()
	
	if event.attacker == parent and not parent:IsIllusion() then
		local heal = event.damage * self.lifesteal_pct / 100
		parent:Heal(heal, self:GetAbility())
		
		-- Эффект лечения
		local particle = ParticleManager:CreateParticle(
			"particles/generic_gameplay/generic_lifesteal.vpcf",
			PATTACH_ABSORIGIN_FOLLOW,
			parent
		)
		ParticleManager:ReleaseParticleIndex(particle)
	end
end

function modifier_ogre_magi_berserker_rage_lifesteal:GetTexture()
	return "item_mask_of_madness"
end

-- Уменьшение перезарядки способностей
modifier_ogre_magi_berserker_rage_cooldown = class({
	IsHidden 				= function(self) return false end,
	IsPurgable 				= function(self) return true end,
	IsBuff                  = function(self) return true end,
	RemoveOnDeath 			= function(self) return true end,
	DeclareFunctions        = function(self) return 
    {
    	MODIFIER_PROPERTY_COOLDOWN_PERCENTAGE,
    } end,
})

function modifier_ogre_magi_berserker_rage_cooldown:OnCreated()
	self.cooldown_reduction = 20
end

function modifier_ogre_magi_berserker_rage_cooldown:GetModifierPercentageCooldown()
	return self.cooldown_reduction
end

function modifier_ogre_magi_berserker_rage_cooldown:GetTexture()
	return "item_refresher"
end

-- Увеличение брони
modifier_ogre_magi_berserker_rage_armor = class({
	IsHidden 				= function(self) return false end,
	IsPurgable 				= function(self) return true end,
	IsBuff                  = function(self) return true end,
	RemoveOnDeath 			= function(self) return true end,
	DeclareFunctions        = function(self) return 
    {
    	MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
    } end,
})

function modifier_ogre_magi_berserker_rage_armor:OnCreated()
	self.armor_bonus = 10
end

function modifier_ogre_magi_berserker_rage_armor:GetModifierPhysicalArmorBonus()
	return self.armor_bonus
end

function modifier_ogre_magi_berserker_rage_armor:GetTexture()
	return "dragon_knight_dragon_blood"
end
