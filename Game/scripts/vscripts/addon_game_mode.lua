print("=== ADDON GAME MODE LOADING ===")

require ("Timers")
require ("game_settings")
require ("utils/util")
require ("test_mind_power") -- Тестовый файл для проверки функции
require ("game_managers/creep_bounty_comeback")
require ("game_managers/killfeed_system")
require ("gamemode")
require ("item_drop")
require ("game_managers/config")

-- Загружаем способности
require ("abilities/mind_power")
require ("abilities/mind_power_buff")
require ("abilities/empty_ability")
require ("abilities/xp_shrine_gold")
require ("abilities/DOOM/doom_soul_devour")
require ("abilities/DOOM/doom_scorched_earth_lua")
require ("items/item_kaya_mind_power")
require ("items/item_mage_slayer")

-- Загружаем способности Чена
require ("abilities/chen/chen_holy_persuasion")
require ("modifiers/chen/modifier_chen_holy_persuasion_mind_hp")
require ("abilities/chen/barrack/chen_barrack_gold")
require ("abilities/chen/chen_barrack")
require ("abilities/chen/chen_sub_barrack")
require ("abilities/chen/chen_worker_build")
require ("abilities/chen/chen_whip")
require ("abilities/chen/chen_martyr_mark")
require ("abilities/chen/chen_ultimate_aura")

-- Загружаем способности Лича
require ("lich/frost_shield/lich_frost_shield_lua")
require ("abilities/lich/ability_sinister_gaze")

require ("abilities/ogre_magi/ogre_magi_reroll")
require ("abilities/ogre_magi/ogre_magi_aghanim_club")
require ("lich/frost_blast/lich_frost_blast_lua")

-- Загружаем способности Tusk
print("=== LOADING TUSK ABILITIES ===")
require ("Tusk/test_tusk")
require ("Tusk/tusk_channeled_snowball")
print("=== TUSK ABILITIES LOADED ===")

-- Загружаем модификаторы
require ("modifiers/modifier_leash_to_spawn")

-- Загружаем AI Рошана
require ("ai_roshan_custom")

-- Загружаем спавнер Pathway Roshan
require ("map_modifications/roshan_pathway_spawner")

function Precache( context )
	--[[
		Precache things we know we'll use.  Possible file types include (but not limited to):
			PrecacheResource( "model", "*.vmdl", context )
			PrecacheResource( "soundfile", "*.vsndevts", context )
			PrecacheResource( "particle", "*.vpcf", context )
			PrecacheResource( "particle_folder", "particles/folder", context )
	]]

	PrecacheResource( "particle", "particles/econ/events/plus/high_five/high_five_impact.vpcf", context )
	PrecacheResource( "particle", "particles/generic_gameplay/launchpad_progress_ring.vpcf", context )
	PrecacheResource( "particle", "particles/items5_fx/repair_kit.vpcf", context )
	PrecacheResource( "particle", "particles/base_attacks/ranged_tower_good.vpcf", context )
	PrecacheResource( "particle", "particles/base_attacks/ranged_tower_bad.vpcf", context )
	
	-- Precache Trinity custom sounds
	PrecacheResource( "soundfile", "soundevents/trinity_sounds.vsndevts", context )

	-- Phantom Assassin Phantom Cloud (Aghanim's Shard)
	PrecacheResource( "soundfile", "soundevents/game_sounds_heroes/game_sounds_phantom_assassin.vsndevts", context )
	PrecacheResource( "soundfile", "soundevents/game_sounds_heroes/game_sounds_slark.vsndevts", context )
	PrecacheResource( "soundfile", "sounds/weapons/creep/roshan/revenge_roar_layer.vsnd", context )
	PrecacheResource( "particle", "particles/units/heroes/hero_phantom_assassin/phantom_assassin_blur.vpcf", context )
	PrecacheResource( "particle", "particles/units/heroes/hero_slark/slark_shard_depth_shroud.vpcf", context )
	PrecacheResource( "particle", "particles/generic_gameplay/generic_smoke.vpcf", context )

	-- Roshan sounds
	PrecacheResource( "soundfile", "soundevents/game_sounds_creeps.vsndevts", context )
 
	-- for _, ability in pairs(abilities) do
	-- 	local hero_name = string.gsub(ability, "_.*", "")
	-- 	print(hero_name)
	-- 	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_" .. hero_name .. ".vsndevts", context)
	-- 	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_" .. hero_name .. ".vsndevts", context)
	-- 	PrecacheResource("particle_folder", "particles/units/heroes/hero_" .. hero_name, context)
	-- end
	
end

-- Create the game mode when we activate
function Activate()
	GameRules.AddonTemplate = CAddonTemplateGameMode()
	GameRules.AddonTemplate:InitGameMode()
end
-- ============== Copyright © 2026, DagonRanchi, All rights reserved. =============

-- Version 1.1
-- Author: https://steamcommunity.com/profiles/76561198874901314/
-- Git: https://github.com/DagonRanchi
-- ===================================================================================

local CUSTOM_ACTION_THROTTLE_MAX_PER_TICK = 3

_G.__cod_action_throttle_states = _G.__cod_action_throttle_states or setmetatable({}, { __mode = "k" })
_G.__cod_action_throttle_fallback_source = _G.__cod_action_throttle_fallback_source or {}
_G.__cod_action_throttle_original_apply_damage = _G.__cod_action_throttle_original_apply_damage or ApplyDamage
_G.__cod_action_throttle_original_perform_attack = _G.__cod_action_throttle_original_perform_attack or CDOTA_BaseNPC.PerformAttack

local function CustomActionThrottle_IsValidEntity(entity)
    return entity and (not entity.IsNull or not entity:IsNull())
end

local function CustomActionThrottle_GetTime()
    if Time then
        return Time()
    end

    if GameRules and GameRules.GetGameTime then
        return GameRules:GetGameTime()
    end

    return 0
end

local function CustomActionThrottle_GetDelay()
    if FrameTime then
        local delay = FrameTime()
        if delay and delay > 0 then
            return delay
        end
    end

    return 0.03
end

local function CustomActionThrottle_CopyTable(source)
    local copy = {}

    for key, value in pairs(source) do
        copy[key] = value
    end

    return copy
end

local function CustomActionThrottle_GetSource(source)
    if CustomActionThrottle_IsValidEntity(source) then
        return source
    end

    if GameRules and GameRules.GetGameModeEntity then
        local game_mode = GameRules:GetGameModeEntity()
        if CustomActionThrottle_IsValidEntity(game_mode) then
            return game_mode
        end
    end

    return _G.__cod_action_throttle_fallback_source
end

local function CustomActionThrottle_GetState(source)
    local state = _G.__cod_action_throttle_states[source]

    if not state then
        state = {
            queue = {},
            count = 0,
            tick_time = nil,
            scheduled = false,
        }

        _G.__cod_action_throttle_states[source] = state
    end

    return state
end

local function CustomActionThrottle_RefreshTick(state)
    local current_time = CustomActionThrottle_GetTime()

    if state.tick_time ~= current_time then
        state.tick_time = current_time
        state.count = 0
    end
end

local CustomActionThrottle_Schedule

local function CustomActionThrottle_Drain(source, state)
    state.scheduled = false
    CustomActionThrottle_RefreshTick(state)

    while state.count < CUSTOM_ACTION_THROTTLE_MAX_PER_TICK and #state.queue > 0 do
        local action = table.remove(state.queue, 1)

        state.count = state.count + 1
        action()
    end

    if #state.queue > 0 then
        CustomActionThrottle_Schedule(source, state)
    end

    return nil
end

CustomActionThrottle_Schedule = function(source, state)
    if state.scheduled then return end

    local thinker = nil

    if GameRules and GameRules.GetGameModeEntity then
        thinker = GameRules:GetGameModeEntity()
    end

    if not CustomActionThrottle_IsValidEntity(thinker) then
        thinker = source
    end

    if not CustomActionThrottle_IsValidEntity(thinker) or not thinker.SetContextThink then
        return
    end

    state.scheduled = true

    thinker:SetContextThink(DoUniqueString("custom_action_throttle"), function()
        return CustomActionThrottle_Drain(source, state)
    end, CustomActionThrottle_GetDelay())
end

local function CustomActionThrottle_Run(source, run_now, create_queued_action, queued_return_value)
    if IsServer and not IsServer() then
        return run_now()
    end

    local source_key = CustomActionThrottle_GetSource(source)
    local state = CustomActionThrottle_GetState(source_key)

    CustomActionThrottle_RefreshTick(state)

    if #state.queue == 0 and state.count < CUSTOM_ACTION_THROTTLE_MAX_PER_TICK then
        state.count = state.count + 1
        return run_now()
    end

    state.queue[#state.queue + 1] = create_queued_action and create_queued_action() or run_now
    CustomActionThrottle_Schedule(source_key, state)

    return queued_return_value
end

function ApplyDamage(damage_table)
    local original_apply_damage = _G.__cod_action_throttle_original_apply_damage

    if not original_apply_damage then return 0 end
    if type(damage_table) ~= "table" then return original_apply_damage(damage_table) end

    return CustomActionThrottle_Run(damage_table.attacker, function()
        return original_apply_damage(damage_table)
    end, function()
        local queued_damage_table = CustomActionThrottle_CopyTable(damage_table)

        return function()
            if not CustomActionThrottle_IsValidEntity(queued_damage_table.victim) then return 0 end
            if queued_damage_table.attacker and not CustomActionThrottle_IsValidEntity(queued_damage_table.attacker) then return 0 end

            return original_apply_damage(queued_damage_table)
        end
    end, 0)
end

function CDOTA_BaseNPC:PerformAttack(target, useCastAttackOrb, processProcs, skipCooldown, ignoreInvis, useProjectile, fakeAttack, neverMiss)
    local original_perform_attack = _G.__cod_action_throttle_original_perform_attack

    if not original_perform_attack then return nil end

    return CustomActionThrottle_Run(self, function()
        return original_perform_attack(self, target, useCastAttackOrb, processProcs, skipCooldown, ignoreInvis, useProjectile, fakeAttack, neverMiss)
    end, function()
        return function()
            if not CustomActionThrottle_IsValidEntity(self) then return nil end
            if not CustomActionThrottle_IsValidEntity(target) then return nil end

            return original_perform_attack(self, target, useCastAttackOrb, processProcs, skipCooldown, ignoreInvis, useProjectile, fakeAttack, neverMiss)
        end
    end, nil)
end

-- ========================================================
-- Конец моделя оптимизации
-- ========================================================


CAddonTemplateGameMode = CAddonTemplateGameMode or class({})

function CAddonTemplateGameMode:InitGameMode()
	GameRules:GetGameModeEntity():SetFreeCourierModeEnabled(true)
 	GameRules:GetGameModeEntity():SetModifyGoldFilter(Dynamic_Wrap(GameMode, "ModifyGoldFilter"), GameMode)
	GameRules:GetGameModeEntity():SetExecuteOrderFilter(Dynamic_Wrap(GameMode, "ExecuteOrderFilter"), GameMode)
	
	-- Set neutral creep spawn time to 0:00
	GameRules:GetGameModeEntity():SetNeutralCreepSpawnTime(0.0)

	GameRules:SetGoldTickTime(1)
	GameRules:SetGoldPerTick(2)

	if CreepBountyComeback and CreepBountyComeback.Init then
		CreepBountyComeback.Init()
	end

	InitGameManagers()
	
	-- Инициализация спавнера Pathway Roshan
	InitRoshanPathwaySpawner()
	
	-- Создаём спавнер рошанов при старте игры (раскомментируйте и укажите нужные координаты)
	-- Timers:CreateTimer(5, function()
	--     local spawnerPos = Vector(0, 0, 128)  -- ЗАМЕНИТЕ на нужные координаты
	--     local spawner = CreateUnitByName("npc_roshan_spawner", spawnerPos, true, nil, nil, DOTA_TEAM_NEUTRALS)
	--     if spawner then
	--         print("[RoshanSpawner] Спавнер создан на позиции: " .. tostring(spawnerPos))
	--     end
	-- end)
	
	-- Консольная команда для создания спавнера рошанов (для тестирования)
	Convars:RegisterCommand("create_roshan_spawner", function(_, x, y, z)
		local pos
		if x and y and z then
			pos = Vector(tonumber(x), tonumber(y), tonumber(z))
		else
			-- Если координаты не указаны, спавним в центре карты
			pos = Vector(0, 0, 128)
		end
		
		local spawner = CreateUnitByName("npc_roshan_spawner", pos, true, nil, nil, DOTA_TEAM_NEUTRALS)
		if spawner then
			print("[RoshanSpawner] Спавнер создан на позиции: " .. tostring(pos))
		else
			print("[RoshanSpawner] ОШИБКА: Не удалось создать спавнер!")
		end
	end, "Создать спавнер рошанов. Использование: create_roshan_spawner [x] [y] [z]", FCVAR_CHEAT)
end
