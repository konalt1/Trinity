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
	-- Звуки для Ogre Magi
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_ogre_magi.vsndevts", context)
	
	-- Звуки для героев из списка способностей
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_ancient_apparition.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_axe.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_bane.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_centaur.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_chaos_knight.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_chen.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_crystal_maiden.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_dark_willow.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_dazzle.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_death_prophet.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_disruptor.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_grimstroke.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_gyrocopter.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_kunkka.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_lion.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_medusa.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_furion.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_oracle.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_obsidian_destroyer.vsndevts", context)
	
	-- Частицы для эффектов способностей
	PrecacheResource("particle", "particles/units/heroes/hero_ogre_magi/ogre_magi_fireblast.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_ancient_apparition/ancient_apparition_cold_feet.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_axe/axe_battle_hunger.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_bane/bane_nightmare.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_centaur/centaur_double_edge.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_chaos_knight/chaos_knight_chaos_bolt.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_chen/chen_penitence.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_crystal_maiden/maiden_frostbite.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_dark_willow/dark_willow_cursed_crown.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_dazzle/dazzle_shallow_grave.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_death_prophet/death_prophet_spirit_siphon.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_disruptor/disruptor_glimpse.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_grimstroke/grimstroke_phantom_embrace.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_gyrocopter/gyro_homing_missile.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_kunkka/kunkka_x_marks_the_spot.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_lion/lion_spell_voodoo.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_medusa/medusa_mystic_snake.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_furion/furion_sprout.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_oracle/oracle_fortunes_end.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_obsidian_destroyer/obsidian_destroyer_astral_imprisonment.vpcf", context)
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
	return 0
end

-- Список возможных способностей для применения на врагов
function ogre_magi_berserker_rage:GetRandomBuff()
	local abilities = {
		{
			name = "Cold Feet",
			ability = "ancient_apparition_cold_feet",
			duration = 4
		},
		{
			name = "Battle Hunger",
			ability = "axe_battle_hunger",
			duration = 10
		},
		{
			name = "Nightmare",
			ability = "bane_nightmare",
			duration = 7
		},
		{
			name = "Double Edge",
			ability = "centaur_double_edge",
			duration = 0
		},
		{
			name = "Chaos Bolt",
			ability = "chaos_knight_chaos_bolt",
			duration = 0
		},
		{
			name = "Penitence",
			ability = "chen_penitence",
			duration = 8
		},
		{
			name = "Frostbite",
			ability = "crystal_maiden_frostbite",
			duration = 3
		},
		{
			name = "Cursed Crown",
			ability = "dark_willow_cursed_crown",
			duration = 4
		},
		{
			name = "Shallow Grave",
			ability = "dazzle_shallow_grave",
			duration = 5
		},
		{
			name = "Spirit Siphon",
			ability = "death_prophet_spirit_siphon",
			duration = 6
		},
		{
			name = "Glimpse",
			ability = "disruptor_glimpse",
			duration = 0
		},
		{
			name = "Phantom Embrace",
			ability = "grimstroke_phantom_embrace",
			duration = 5
		},
		{
			name = "Homing Missile",
			ability = "gyrocopter_homing_missile",
			duration = 0
		},
		{
			name = "X Marks the Spot",
			ability = "kunkka_x_marks_the_spot",
			duration = 8
		},
		{
			name = "Hex",
			ability = "lion_hex",
			duration = 4
		},
		{
			name = "Mystic Snake",
			ability = "medusa_mystic_snake",
			duration = 0
		},
		{
			name = "Sprout",
			ability = "furion_sprout",
			duration = 6
		},
		{
			name = "Fortune's End",
			ability = "oracle_fortunes_end",
			duration = 0
		},
		{
			name = "Astral Imprisonment",
			ability = "obsidian_destroyer_astral_imprisonment",
			duration = 4
		}
	}
	
	return abilities[RandomInt(1, #abilities)]
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
		self.next_attack_charged = false
		self.charged_buff = nil
		
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
	
	-- Проверяем, заряжена ли следующая атака
	if self.next_attack_charged and self.charged_buff then
		-- Применяем заряженный эффект на цель
		self:ApplyChargedEffectToTarget(target)
		self.next_attack_charged = false
		self.charged_buff = nil
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
	
	-- Получаем случайный бафф и заряжаем следующую атаку
	local random_buff = ability:GetRandomBuff()
	self.next_attack_charged = true
	self.charged_buff = random_buff
	
	-- Большой эффект активации на огре
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
	
	print("Ogre Berserker Rage charged! Next attack will apply: " .. random_buff.name)
end

function modifier_ogre_magi_berserker_rage:ApplyChargedEffectToTarget(target)
	if not IsServer() then return end
	
	local parent = self:GetParent()
	local ability = self:GetAbility()
	local selected_ability = self.charged_buff
	
	-- Создаем временную способность для применения
	local temp_ability = parent:AddAbility(selected_ability.ability)
	if temp_ability then
		temp_ability:SetLevel(1)
		
		-- Применяем способность на цель
		if temp_ability:CanAbilityBeUpgraded() then
			temp_ability:CastAbility()
		else
			-- Для таргетных способностей
			parent:SetCursorCastTarget(target)
			temp_ability:OnSpellStart()
		end
		
		-- Удаляем временную способность
		Timers:CreateTimer(0.1, function()
			if temp_ability and IsValidEntity(temp_ability) then
				parent:RemoveAbility(selected_ability.ability)
			end
		end)
	end
	
	-- Эффекты применения на цель
	EmitSoundOn("Hero_OgreMagi.Fireblast.Target", target)
	
	-- Визуальный эффект на цели
	local particle = ParticleManager:CreateParticle(
		"particles/units/heroes/hero_ogre_magi/ogre_magi_fireblast.vpcf",
		PATTACH_ABSORIGIN_FOLLOW,
		target
	)
	ParticleManager:SetParticleControlEnt(
		particle,
		0,
		target,
		PATTACH_POINT_FOLLOW,
		"attach_hitloc",
		target:GetOrigin(),
		true
	)
	ParticleManager:ReleaseParticleIndex(particle)
	
	print("Applied charged ability '" .. selected_ability.name .. "' to " .. target:GetUnitName())
end

--------------------------------------------------------------------------------
-- Модификаторы баффов

-- Замедление скорости атаки
modifier_ogre_magi_berserker_rage_attack_speed = class({
	IsHidden 				= function(self) return false end,
	IsPurgable 				= function(self) return true end,
	IsBuff                  = function(self) return false end,
	RemoveOnDeath 			= function(self) return true end,
	DeclareFunctions        = function(self) return 
    {
    	MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
    } end,
})

function modifier_ogre_magi_berserker_rage_attack_speed:OnCreated()
	self.attack_speed_reduction = -30
end

function modifier_ogre_magi_berserker_rage_attack_speed:GetModifierAttackSpeedBonus_Constant()
	return self.attack_speed_reduction
end

function modifier_ogre_magi_berserker_rage_attack_speed:GetTexture()
	return "ogre_magi_bloodlust"
end

-- Уменьшение урона
modifier_ogre_magi_berserker_rage_damage = class({
	IsHidden 				= function(self) return false end,
	IsPurgable 				= function(self) return true end,
	IsBuff                  = function(self) return false end,
	RemoveOnDeath 			= function(self) return true end,
	DeclareFunctions        = function(self) return 
    {
    	MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
    } end,
})

function modifier_ogre_magi_berserker_rage_damage:OnCreated()
	self.damage_reduction = -40
end

function modifier_ogre_magi_berserker_rage_damage:GetModifierPreAttack_BonusDamage()
	return self.damage_reduction
end

function modifier_ogre_magi_berserker_rage_damage:GetTexture()
	return "ogre_magi_multicast"
end

-- Периодический урон (DOT)
modifier_ogre_magi_berserker_rage_shield = class({
	IsHidden 				= function(self) return false end,
	IsPurgable 				= function(self) return true end,
	IsBuff                  = function(self) return false end,
	RemoveOnDeath 			= function(self) return true end,
	DeclareFunctions        = function(self) return {} end,
})

function modifier_ogre_magi_berserker_rage_shield:OnCreated()
	if not IsServer() then return end
	self.dot_damage = 25
	self.tick_interval = 1.0
	
	-- Начинаем периодический урон
	self:StartIntervalThink(self.tick_interval)
end

function modifier_ogre_magi_berserker_rage_shield:OnIntervalThink()
	if not IsServer() then return end
	
	local parent = self:GetParent()
	local ability = self:GetAbility()
	local caster = ability:GetCaster()
	
	-- Наносим урон
	local damageTable = {
		victim = parent,
		attacker = caster,
		damage = self.dot_damage,
		damage_type = DAMAGE_TYPE_MAGICAL,
		ability = ability,
		damage_flags = DOTA_DAMAGE_FLAG_NONE
	}
	ApplyDamage(damageTable)
	
	-- Эффект при каждом тике
	local particle = ParticleManager:CreateParticle(
		"particles/units/heroes/hero_ogre_magi/ogre_magi_fireblast.vpcf",
		PATTACH_OVERHEAD_FOLLOW,
		parent
	)
	ParticleManager:ReleaseParticleIndex(particle)
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

-- Замедление скорости передвижения
modifier_ogre_magi_berserker_rage_speed = class({
	IsHidden 				= function(self) return false end,
	IsPurgable 				= function(self) return true end,
	IsBuff                  = function(self) return false end,
	RemoveOnDeath 			= function(self) return true end,
	DeclareFunctions        = function(self) return 
    {
    	MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
    } end,
})

function modifier_ogre_magi_berserker_rage_speed:OnCreated()
	self.move_speed_reduction = -25
end

function modifier_ogre_magi_berserker_rage_speed:GetModifierMoveSpeedBonus_Percentage()
	return self.move_speed_reduction
end

function modifier_ogre_magi_berserker_rage_speed:GetTexture()
	return "bloodseeker_thirst"
end

-- Уменьшение сопротивления магии
modifier_ogre_magi_berserker_rage_magic_resist = class({
	IsHidden 				= function(self) return false end,
	IsPurgable 				= function(self) return true end,
	IsBuff                  = function(self) return false end,
	RemoveOnDeath 			= function(self) return true end,
	DeclareFunctions        = function(self) return 
    {
    	MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS,
    } end,
})

function modifier_ogre_magi_berserker_rage_magic_resist:OnCreated()
	self.magic_resist_reduction = -25
end

function modifier_ogre_magi_berserker_rage_magic_resist:GetModifierMagicalResistanceBonus()
	return self.magic_resist_reduction
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

-- Уменьшение брони
modifier_ogre_magi_berserker_rage_armor = class({
	IsHidden 				= function(self) return false end,
	IsPurgable 				= function(self) return true end,
	IsBuff                  = function(self) return false end,
	RemoveOnDeath 			= function(self) return true end,
	DeclareFunctions        = function(self) return 
    {
    	MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
    } end,
})

function modifier_ogre_magi_berserker_rage_armor:OnCreated()
	self.armor_reduction = -8
end

function modifier_ogre_magi_berserker_rage_armor:GetModifierPhysicalArmorBonus()
	return self.armor_reduction
end

function modifier_ogre_magi_berserker_rage_armor:GetTexture()
	return "dragon_knight_dragon_blood"
end
