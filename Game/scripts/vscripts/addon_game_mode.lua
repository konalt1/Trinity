require ("timers")
require ("game_settings")
require ("gamemode")
require ("item_drop")

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

end

-- Create the game mode when we activate
function Activate()
GameRules.AddonTemplate = CAddonTemplateGameMode()
GameRules.AddonTemplate:InitGameMode()
end

function CAddonTemplateGameMode:InitGameMode()
print( "Template addon is loaded." )
GameRules:GetGameModeEntity():SetThink( "OnThink", self, "GlobalThink", 2 )
end

-- Evaluate the state of the game
function CAddonTemplateGameMode:OnThink()
if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
--print( "Template addon script is running." )
elseif GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
return nil
end
return 1
end

function CAddonTemplateGameMode:InitGameMode()
GameRules:GetGameModeEntity():SetFreeCourierModeEnabled(true)
GameRules:SetGoldTickTime(1)
GameRules:SetGoldPerTick(2)
end
