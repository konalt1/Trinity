LinkLuaModifier('modifier_ogre_magi_aghanim_club', 'abilities/ogre_magi/ogre_magi_aghanim_club', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_ogre_magi_aghanim_club_attack_speed', 'abilities/ogre_magi/ogre_magi_aghanim_club', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_ogre_magi_aghanim_club_damage', 'abilities/ogre_magi/ogre_magi_aghanim_club', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_ogre_magi_aghanim_club_shield', 'abilities/ogre_magi/ogre_magi_aghanim_club', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_ogre_magi_aghanim_club_regen', 'abilities/ogre_magi/ogre_magi_aghanim_club', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_ogre_magi_aghanim_club_speed', 'abilities/ogre_magi/ogre_magi_aghanim_club', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_ogre_magi_aghanim_club_magic_resist', 'abilities/ogre_magi/ogre_magi_aghanim_club', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_ogre_magi_aghanim_club_lifesteal', 'abilities/ogre_magi/ogre_magi_aghanim_club', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_ogre_magi_aghanim_club_cooldown', 'abilities/ogre_magi/ogre_magi_aghanim_club', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_ogre_magi_aghanim_club_armor', 'abilities/ogre_magi/ogre_magi_aghanim_club', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_ogre_aghanim_club_borrowed_cast', 'abilities/ogre_magi/ogre_magi_aghanim_club', LUA_MODIFIER_MOTION_NONE)

ogre_magi_aghanim_club = class({})

function ogre_magi_aghanim_club:Precache(context)
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
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_sven.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_lion.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_medusa.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_furion.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_oracle.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_obsidian_destroyer.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_tidehunter.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_zuus.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_silencer.vsndevts", context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_enigma.vsndevts", context)
	
	-- Частицы прока + полные папки героев (ванильные скиллы тянут десятки vpcf)
	PrecacheResource("particle", "particles/units/heroes/hero_ogre_magi/ogre_magi_fireblast.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_ogre_magi/ogre_magi_bloodlust_cast.vpcf", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_ancient_apparition", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_axe", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_bane", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_centaur", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_chaos_knight", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_chen", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_crystal_maiden", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_dark_willow", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_dazzle", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_death_prophet", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_disruptor", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_grimstroke", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_sven", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_lion", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_medusa", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_oracle", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_obsidian_destroyer", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_tidehunter", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_zuus", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_silencer", context)
	PrecacheResource("particle_folder", "particles/units/heroes/hero_enigma", context)
end

function ogre_magi_aghanim_club:GetIntrinsicModifierName()
	return "modifier_ogre_magi_aghanim_club"
end

function ogre_magi_aghanim_club:IsStealable()
	return false
end

function ogre_magi_aghanim_club:IsHidden()
	return false
end

function ogre_magi_aghanim_club:GetCooldown(level)
	return 0
end

-- Список возможных способностей для применения на врагов
function ogre_magi_aghanim_club:GetRandomBuff()
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
			duration = 7,
			linked_abilities = { "bane_nightmare_end" },
		},
		{
			name = "Double Edge",
			ability = "centaur_double_edge",
			duration = 1
		},
		{
			name = "Chaos Bolt",
			ability = "chaos_knight_chaos_bolt",
			duration = 2
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
			name = "Crystal Nova",
			ability = "crystal_maiden_crystal_nova",
			duration = 5,
			cast = "position",
		},
		{
			name = "Cursed Crown",
			ability = "dark_willow_cursed_crown",
			duration = 4
		},
		{
			name = "Shallow Grave",
			ability = "dazzle_shallow_grave",
			duration = 5,
			ally_only = true,
		},
		{
			name = "Spirit Siphon",
			ability = "death_prophet_spirit_siphon",
			duration = 6
		},
		{
			name = "Malefice",
			ability = "enigma_malefice",
			duration = 3
		},
		{
			name = "Glimpse",
			ability = "disruptor_glimpse",
			duration = 2,
			hero_only = true,
		},
		{
			name = "Phantom Embrace",
			ability = "grimstroke_phantom_embrace",
			duration = 5
		},
		{
			name = "Last Word",
			ability = "silencer_last_word",
			duration = 6
		},
		{
			name = "Storm Bolt",
			ability = "sven_storm_bolt",
			duration = 2
		},
		{
			name = "Hex",
			ability = "lion_voodoo",
			duration = 4
		},
		{
			name = "Mystic Snake",
			ability = "medusa_mystic_snake",
			duration = 5
		},

		{
			name = "Gush",
			ability = "tidehunter_gush",
			duration = 4
		},
		{
			name = "Arc Lightning",
			ability = "zuus_arc_lightning",
			duration = 1
		},
		{
			name = "Fortune's End",
			ability = "oracle_fortunes_end",
			duration = 3,
			channel = 3,
		},
		{
			name = "Astral Imprisonment",
			ability = "obsidian_destroyer_astral_imprisonment",
			duration = 4
		}
	}
	
	return abilities[RandomInt(1, #abilities)]
end

-- Сколько держать одолженную способность на герое: duration/channel — время эффекта, + буфер на каст.
local BORROWED_ABILITY_MIN_KEEP = 1.5
local BORROWED_ABILITY_KEEP_BUFFER = 1.0

function ogre_magi_aghanim_club:GetBorrowedAbilityKeepDuration(entry)
	local effect_duration = entry.duration or 0
	local channel = entry.channel or 0
	return math.max(BORROWED_ABILITY_MIN_KEEP, effect_duration + channel + BORROWED_ABILITY_KEEP_BUFFER)
end

-- Небольшая задержка после AddAbility: способность и цель атаки должны успеть инициализироваться.
local BORROWED_ABILITY_CAST_DELAY = 0.03
local BORROWED_ABILITY_PROC_ATTEMPTS = 6

-- Скрытые sub-ability (kunkka_return, bane_nightmare_end): SetHidden/RemoveAbility только по одному имени ломает слоты.
local BORROWED_ABILITY_LINKED = {
	kunkka_x_marks_the_spot = { "kunkka_return" },
	bane_nightmare = { "bane_nightmare_end" },
}

function ogre_magi_aghanim_club:GetBorrowedAbilityNames(entry)
	local names = { entry.ability }
	local linked = entry.linked_abilities or BORROWED_ABILITY_LINKED[entry.ability]
	if linked then
		for _, name in ipairs(linked) do
			table.insert(names, name)
		end
	end
	return names
end

function ogre_magi_aghanim_club:RemoveBorrowedAbilityBundle(caster, entry_or_key)
	if not IsValidEntity(caster) then
		return
	end

	local names
	if type(entry_or_key) == "table" then
		names = self:GetBorrowedAbilityNames(entry_or_key)
	else
		names = { entry_or_key }
		local linked = BORROWED_ABILITY_LINKED[entry_or_key]
		if linked then
			for _, name in ipairs(linked) do
				table.insert(names, name)
			end
		end
	end

	for _, name in ipairs(names) do
		while caster:HasAbility(name) do
			caster:RemoveAbility(name)
		end
	end
end

function ogre_magi_aghanim_club:CleanupStaleBorrowedAbilities(caster)
	for primary, _ in pairs(BORROWED_ABILITY_LINKED) do
		self:RemoveBorrowedAbilityBundle(caster, primary)
	end
end

function ogre_magi_aghanim_club:IsValidClubTarget(unit, caster)
	return unit
		and IsValidEntity(unit)
		and unit:IsAlive()
		and unit ~= caster
		and not unit:IsBuilding()
		and not unit:IsCourier()
		and unit:GetTeamNumber() ~= caster:GetTeamNumber()
end

function ogre_magi_aghanim_club:GetCastTargetForEntry(caster, attack_target, entry, borrowed)
	if entry.ally_only then
		return caster:IsAlive() and caster or nil
	end

	if self:IsValidClubTarget(attack_target, caster) then
		return attack_target
	end

	local cast_range = 800
	if borrowed then
		local level = borrowed:GetLevel()
		if level <= 0 then
			level = 1
		end
		cast_range = borrowed:GetCastRange(level)
		if cast_range <= 0 then
			cast_range = 800
		end
	end

	local search_origin = (attack_target and IsValidEntity(attack_target)) and attack_target:GetAbsOrigin() or caster:GetAbsOrigin()
	local targets = FindUnitsInRadius(
		caster:GetTeamNumber(),
		search_origin,
		nil,
		cast_range + 200,
		DOTA_UNIT_TARGET_TEAM_BOTH,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE + DOTA_UNIT_TARGET_FLAG_NO_INVIS,
		FIND_CLOSEST,
		false
	)

	for _, unit in ipairs(targets) do
		if self:IsValidClubTarget(unit, caster) then
			return unit
		end
	end

	return nil
end

function ogre_magi_aghanim_club:ResolveRandomBuffForTarget(attack_target, max_attempts)
	max_attempts = max_attempts or 8
	for _ = 1, max_attempts do
		local entry = self:GetRandomBuff()
		if not entry.hero_only or (attack_target and attack_target:IsHero()) then
			return entry
		end
	end
	return self:GetRandomBuff()
end

function ogre_magi_aghanim_club:ResolveBorrowedCastType(borrowed, entry)
	if entry.cast then
		return entry.cast
	end

	local behavior = borrowed:GetBehavior()
	if bit.band(behavior, DOTA_ABILITY_BEHAVIOR_NO_TARGET) ~= 0 then
		return "no_target"
	end
	if bit.band(behavior, DOTA_ABILITY_BEHAVIOR_UNIT_TARGET) ~= 0 then
		return "target"
	end
	if bit.band(behavior, DOTA_ABILITY_BEHAVIOR_POINT) ~= 0 then
		return "position"
	end

	return "target"
end

-- SetCursor + OnSpellStart: не зависит от очереди приказов и анимации атаки (см. moddota.com/abilities/calling-spells-with-setcursor).
function ogre_magi_aghanim_club:CastBorrowedVanillaAbility(caster, borrowed, entry, attack_target, cast_target)
	if not IsValidEntity(caster) or not borrowed or borrowed:IsNull() then
		return false
	end

	local max_level = borrowed:GetMaxLevel()
	if max_level <= 0 then
		max_level = 1
	end
	borrowed:SetLevel(max_level)
	borrowed:EndCooldown()

	local cast_type = self:ResolveBorrowedCastType(borrowed, entry)
	caster:Stop()

	if cast_type == "no_target" then
		borrowed:OnSpellStart()
		return true
	end

	if cast_type == "position" then
		local position_target = self:GetCastTargetForEntry(caster, attack_target, entry, borrowed)
		if not position_target then
			return false
		end
		caster:SetCursorPosition(position_target:GetAbsOrigin())
		borrowed:OnSpellStart()
		return true
	end

	cast_target = cast_target or self:GetCastTargetForEntry(caster, attack_target, entry, borrowed)
	if not cast_target or not IsValidEntity(cast_target) or not cast_target:IsAlive() then
		return false
	end

	caster:SetCursorCastTarget(cast_target)
	borrowed:OnSpellStart()
	return true
end

--------------------------------------------------------------------------------
-- Временно «одалживаем» ванильную способность на героя; манакост обнуляется (как у reroll), без dummy.
modifier_ogre_aghanim_club_borrowed_cast = class({
	IsHidden = function() return true end,
	IsPurgable = function() return false end,
	IsDebuff = function() return false end,
	RemoveOnDeath = function() return true end,
	DeclareFunctions = function()
		return { MODIFIER_PROPERTY_MANACOST_PERCENTAGE_STACKING }
	end,
})

function modifier_ogre_aghanim_club_borrowed_cast:OnCreated(kv)
	if IsServer() then
		self.borrowed = kv.borrowed or ""
	end
end

function modifier_ogre_aghanim_club_borrowed_cast:GetModifierPercentageManacostStacking(params)
	local ab = params.ability
	if not ab or not self.borrowed or self.borrowed == "" then
		return 0
	end
	if ab:GetAbilityName() == self.borrowed then
		return 100
	end
	return 0
end

--------------------------------------------------------------------------------
-- Основной модификатор для отслеживания атак
modifier_ogre_magi_aghanim_club = class({
	IsHidden 				= function(self) return false end,
	IsPurgable 				= function(self) return false end,
	IsBuff                  = function(self) return true end,
	RemoveOnDeath 			= function(self) return false end,
    DeclareFunctions        = function(self) return 
    {
    	MODIFIER_EVENT_ON_ATTACK_LANDED,
    } end,
})

function modifier_ogre_magi_aghanim_club:OnCreated()
	if IsServer() then
		self.attack_count = 0
		local ab = self:GetAbility()
		if ab then
			ab:CleanupStaleBorrowedAbilities(self:GetParent())
		end
		self.attacks_needed = ab and ab:GetSpecialValueFor("attacks_needed") or 10
		if self.attacks_needed <= 0 then
			self.attacks_needed = 10
		end
		self:SetStackCount(self.attack_count)
	else
		self.attack_count = self:GetStackCount()
		self.attacks_needed = 10
	end
end

function modifier_ogre_magi_aghanim_club:OnRefresh()
	self:OnCreated()
end

function modifier_ogre_magi_aghanim_club:GetTexture()
	return "ogre_magi_multicast"
end

function modifier_ogre_magi_aghanim_club:OnAttackLanded(event)
	if not IsServer() then return end
	
	local parent = self:GetParent()
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
	
	self.attack_count = self.attack_count + 1
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
	print("Ogre Aghanim Club: " .. self.attack_count .. "/" .. self.attacks_needed .. " attacks vs " .. target:GetUnitName() .. " (" .. target_type .. ")")
	
	if self.attack_count >= self.attacks_needed then
		self.attack_count = 0
		self:SetStackCount(0)
		self:PlayAghanimClubProcEffects()
		self:DispatchStolenSpellFromAttack(target)
	end
end

function modifier_ogre_magi_aghanim_club:PlayAghanimClubProcEffects()
	if not IsServer() then return end
	local parent = self:GetParent()
	EmitSoundOn("Hero_OgreMagi.Fireblast.Target", parent)
	EmitSoundOn("Hero_OgreMagi.Multicast.x3", parent)
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
	local explosion_particle = ParticleManager:CreateParticle(
		"particles/units/heroes/hero_ogre_magi/ogre_magi_bloodlust_cast.vpcf",
		PATTACH_ABSORIGIN_FOLLOW,
		parent
	)
	ParticleManager:ReleaseParticleIndex(explosion_particle)
end

-- Каст с героя: временная ванильная способность + модификатор с нулевым манакостом (см. ogre_magi_reroll).
-- SetHidden ломает способности со скрытыми sub-ability (kunkka_return и т.п.) — не прячем одолженные скиллы.

function modifier_ogre_magi_aghanim_club:DispatchStolenSpellFromAttack(attack_target)
	if not IsServer() then return end
	local parent = self:GetParent()
	local src_ability = self:GetAbility()
	if not src_ability or not attack_target or not IsValidEntity(attack_target) then
		return
	end

	local function cleanup_borrowed(entry, mana_modifier)
		if IsValidEntity(parent) then
			src_ability:RemoveBorrowedAbilityBundle(parent, entry)
		end
		if mana_modifier and not mana_modifier:IsNull() then
			mana_modifier:Destroy()
		end
	end

	local function try_proc(attempt)
		local entry = src_ability:ResolveRandomBuffForTarget(attack_target)
		local ability_key = entry.ability

		src_ability:RemoveBorrowedAbilityBundle(parent, entry)

		local mana_modifier = parent:AddNewModifier(parent, src_ability, "modifier_ogre_aghanim_club_borrowed_cast", { borrowed = ability_key })
		local borrowed = parent:AddAbility(ability_key)
		if not borrowed then
			print("Ogre Aghanim Club: failed to add ability " .. ability_key)
			if mana_modifier and not mana_modifier:IsNull() then
				mana_modifier:Destroy()
			end
			if attempt < BORROWED_ABILITY_PROC_ATTEMPTS then
				try_proc(attempt + 1)
			end
			return
		end

		local keep_duration = src_ability:GetBorrowedAbilityKeepDuration(entry)

		Timers:CreateTimer(BORROWED_ABILITY_CAST_DELAY, function()
			if not IsValidEntity(parent) then
				cleanup_borrowed(entry, mana_modifier)
				return
			end

			local ab = parent:FindAbilityByName(ability_key)
			if not ab then
				cleanup_borrowed(entry, mana_modifier)
				if attempt < BORROWED_ABILITY_PROC_ATTEMPTS then
					try_proc(attempt + 1)
				end
				return
			end

			local max_level = ab:GetMaxLevel()
			if max_level <= 0 then
				max_level = 1
			end
			ab:SetLevel(max_level)

			local resolved_target = src_ability:GetCastTargetForEntry(parent, attack_target, entry, ab)
			local cast_ok = src_ability:CastBorrowedVanillaAbility(parent, ab, entry, attack_target, resolved_target)
			if not cast_ok then
				print("Ogre Aghanim Club: cast failed for " .. ability_key)
				cleanup_borrowed(entry, mana_modifier)
				if attempt < BORROWED_ABILITY_PROC_ATTEMPTS then
					try_proc(attempt + 1)
				end
				return
			end

			Timers:CreateTimer(keep_duration, function()
				cleanup_borrowed(entry, mana_modifier)
			end)

			local fx_unit = resolved_target
			if fx_unit and IsValidEntity(fx_unit) then
				EmitSoundOn("Hero_OgreMagi.Fireblast.Target", fx_unit)
				local particle = ParticleManager:CreateParticle(
					"particles/units/heroes/hero_ogre_magi/ogre_magi_fireblast.vpcf",
					PATTACH_ABSORIGIN_FOLLOW,
					fx_unit
				)
				ParticleManager:SetParticleControlEnt(
					particle,
					0,
					fx_unit,
					PATTACH_POINT_FOLLOW,
					"attach_hitloc",
					fx_unit:GetOrigin(),
					true
				)
				ParticleManager:ReleaseParticleIndex(particle)
			end

			print("Ogre Aghanim Club proc: " .. entry.name .. " -> " .. (resolved_target and resolved_target:GetUnitName() or "?"))
		end)
	end

	try_proc(1)
end

--------------------------------------------------------------------------------
-- Модификаторы баффов

-- Замедление скорости атаки
modifier_ogre_magi_aghanim_club_attack_speed = class({
	IsHidden 				= function(self) return false end,
	IsPurgable 				= function(self) return true end,
	IsBuff                  = function(self) return false end,
	RemoveOnDeath 			= function(self) return true end,
	DeclareFunctions        = function(self) return 
    {
    	MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
    } end,
})

function modifier_ogre_magi_aghanim_club_attack_speed:OnCreated()
	self.attack_speed_reduction = -30
end

function modifier_ogre_magi_aghanim_club_attack_speed:GetModifierAttackSpeedBonus_Constant()
	return self.attack_speed_reduction
end

function modifier_ogre_magi_aghanim_club_attack_speed:GetTexture()
	return "ogre_magi_bloodlust"
end

-- Уменьшение урона
modifier_ogre_magi_aghanim_club_damage = class({
	IsHidden 				= function(self) return false end,
	IsPurgable 				= function(self) return true end,
	IsBuff                  = function(self) return false end,
	RemoveOnDeath 			= function(self) return true end,
	DeclareFunctions        = function(self) return 
    {
    	MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
    } end,
})

function modifier_ogre_magi_aghanim_club_damage:OnCreated()
	self.damage_reduction = -40
end

function modifier_ogre_magi_aghanim_club_damage:GetModifierPreAttack_BonusDamage()
	return self.damage_reduction
end

function modifier_ogre_magi_aghanim_club_damage:GetTexture()
	return "ogre_magi_multicast"
end

-- Периодический урон (DOT)
modifier_ogre_magi_aghanim_club_shield = class({
	IsHidden 				= function(self) return false end,
	IsPurgable 				= function(self) return true end,
	IsBuff                  = function(self) return false end,
	RemoveOnDeath 			= function(self) return true end,
	DeclareFunctions        = function(self) return {} end,
})

function modifier_ogre_magi_aghanim_club_shield:OnCreated()
	if not IsServer() then return end
	self.dot_damage = 25
	self.tick_interval = 1.0
	
	-- Начинаем периодический урон
	self:StartIntervalThink(self.tick_interval)
end

function modifier_ogre_magi_aghanim_club_shield:OnIntervalThink()
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

function modifier_ogre_magi_aghanim_club_shield:GetTexture()
	return "abaddon_aphotic_shield"
end

-- Регенерация здоровья
modifier_ogre_magi_aghanim_club_regen = class({
	IsHidden 				= function(self) return false end,
	IsPurgable 				= function(self) return true end,
	IsBuff                  = function(self) return true end,
	RemoveOnDeath 			= function(self) return true end,
	DeclareFunctions        = function(self) return 
    {
    	MODIFIER_PROPERTY_HEALTH_REGEN_PERCENTAGE,
    } end,
})

function modifier_ogre_magi_aghanim_club_regen:OnCreated()
	self.health_regen_pct = 5
end

function modifier_ogre_magi_aghanim_club_regen:GetModifierHealthRegenPercentage()
	return self.health_regen_pct
end

function modifier_ogre_magi_aghanim_club_regen:GetTexture()
	return "alchemist_chemical_rage"
end

-- Замедление скорости передвижения
modifier_ogre_magi_aghanim_club_speed = class({
	IsHidden 				= function(self) return false end,
	IsPurgable 				= function(self) return true end,
	IsBuff                  = function(self) return false end,
	RemoveOnDeath 			= function(self) return true end,
	DeclareFunctions        = function(self) return 
    {
    	MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
    } end,
})

function modifier_ogre_magi_aghanim_club_speed:OnCreated()
	self.move_speed_reduction = -25
end

function modifier_ogre_magi_aghanim_club_speed:GetModifierMoveSpeedBonus_Percentage()
	return self.move_speed_reduction
end

function modifier_ogre_magi_aghanim_club_speed:GetTexture()
	return "bloodseeker_thirst"
end

-- Уменьшение сопротивления магии
modifier_ogre_magi_aghanim_club_magic_resist = class({
	IsHidden 				= function(self) return false end,
	IsPurgable 				= function(self) return true end,
	IsBuff                  = function(self) return false end,
	RemoveOnDeath 			= function(self) return true end,
	DeclareFunctions        = function(self) return 
    {
    	MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS,
    } end,
})

function modifier_ogre_magi_aghanim_club_magic_resist:OnCreated()
	self.magic_resist_reduction = -25
end

function modifier_ogre_magi_aghanim_club_magic_resist:GetModifierMagicalResistanceBonus()
	return self.magic_resist_reduction
end

function modifier_ogre_magi_aghanim_club_magic_resist:GetTexture()
	return "anti_mage_spell_shield"
end

-- Вампиризм
modifier_ogre_magi_aghanim_club_lifesteal = class({
	IsHidden 				= function(self) return false end,
	IsPurgable 				= function(self) return true end,
	IsBuff                  = function(self) return true end,
	RemoveOnDeath 			= function(self) return true end,
	DeclareFunctions        = function(self) return 
    {
    	MODIFIER_EVENT_ON_ATTACK_LANDED,
    } end,
})

function modifier_ogre_magi_aghanim_club_lifesteal:OnCreated()
	self.lifesteal_pct = 20
end

function modifier_ogre_magi_aghanim_club_lifesteal:OnAttackLanded(event)
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

function modifier_ogre_magi_aghanim_club_lifesteal:GetTexture()
	return "item_mask_of_madness"
end

-- Уменьшение перезарядки способностей
modifier_ogre_magi_aghanim_club_cooldown = class({
	IsHidden 				= function(self) return false end,
	IsPurgable 				= function(self) return true end,
	IsBuff                  = function(self) return true end,
	RemoveOnDeath 			= function(self) return true end,
	DeclareFunctions        = function(self) return 
    {
    	MODIFIER_PROPERTY_COOLDOWN_PERCENTAGE,
    } end,
})

function modifier_ogre_magi_aghanim_club_cooldown:OnCreated()
	self.cooldown_reduction = 20
end

function modifier_ogre_magi_aghanim_club_cooldown:GetModifierPercentageCooldown()
	return self.cooldown_reduction
end

function modifier_ogre_magi_aghanim_club_cooldown:GetTexture()
	return "item_refresher"
end

-- Уменьшение брони
modifier_ogre_magi_aghanim_club_armor = class({
	IsHidden 				= function(self) return false end,
	IsPurgable 				= function(self) return true end,
	IsBuff                  = function(self) return false end,
	RemoveOnDeath 			= function(self) return true end,
	DeclareFunctions        = function(self) return 
    {
    	MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
    } end,
})

function modifier_ogre_magi_aghanim_club_armor:OnCreated()
	self.armor_reduction = -8
end

function modifier_ogre_magi_aghanim_club_armor:GetModifierPhysicalArmorBonus()
	return self.armor_reduction
end

function modifier_ogre_magi_aghanim_club_armor:GetTexture()
	return "dragon_knight_dragon_blood"
end
