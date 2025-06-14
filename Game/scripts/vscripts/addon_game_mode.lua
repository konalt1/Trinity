require ("timers")
require ("game_settings")
require ("utils/util")
require ("gamemode")
require ("item_drop")
require ("game_managers/config")


require ("abilities/ogre_magi/ogre_magi_reroll")
function Precache( context )
	--[[
		Precache things we know we'll use.  Possible file types include (but not limited to):
			PrecacheResource( "model", "*.vmdl", context )
			PrecacheResource( "soundfile", "*.vsndevts", context )
			PrecacheResource( "particle", "*.vpcf", context )
			PrecacheResource( "particle_folder", "particles/folder", context )
	]]
	PrecacheResource( "soundfile", "soundevents/game_sounds_heroes/game_sounds_troll_warlord.vsndevts", context )
	PrecacheResource( "soundfile", "soundevents/voscripts/game_sounds_troll_warlord.vsndevts", context )
	PrecacheResource( "particle", "particles/econ/events/plus/high_five/high_five_impact.vpcf", context )

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
	GameRules:GetGameModeEntity():SetRespawnTimeScale(0.5)
 	GameRules:GetGameModeEntity():SetModifyGoldFilter(Dynamic_Wrap(GameMode, "ModifyGoldFilter"), GameMode)

	GameRules:SetGoldTickTime(1)
	GameRules:SetGoldPerTick(2)
	InitGameManagers()
end
