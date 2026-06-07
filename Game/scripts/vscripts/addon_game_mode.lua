print("=== ADDON GAME MODE LOADING ===")

require ("Timers")
require ("game_settings")
require ("utils/util")
require ("test_mind_power") -- Тестовый файл для проверки функции
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

CAddonTemplateGameMode = CAddonTemplateGameMode or class({})

function CAddonTemplateGameMode:InitGameMode()
	GameRules:GetGameModeEntity():SetFreeCourierModeEnabled(true)
	GameRules:GetGameModeEntity():SetRespawnTimeScale(1)
 	GameRules:GetGameModeEntity():SetModifyGoldFilter(Dynamic_Wrap(GameMode, "ModifyGoldFilter"), GameMode)
	GameRules:GetGameModeEntity():SetExecuteOrderFilter(Dynamic_Wrap(GameMode, "ExecuteOrderFilter"), GameMode)
	
	-- Set neutral creep spawn time to 0:00
	GameRules:GetGameModeEntity():SetNeutralCreepSpawnTime(0.0)

	GameRules:SetGoldTickTime(1)
	GameRules:SetGoldPerTick(2)
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
