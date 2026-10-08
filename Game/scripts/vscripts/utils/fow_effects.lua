FOW_EFFECT_TEAMS = FOW_EFFECT_TEAMS or { DOTA_TEAM_GOODGUYS, DOTA_TEAM_BADGUYS }

function ForEachTeamWithVisionAt(location, fn)
	if not location then
		return
	end

	for _, team in ipairs(FOW_EFFECT_TEAMS) do
		if IsLocationVisible(team, location) then
			fn(team)
		end
	end
end

function CreateFOWParticle(particle_name, attach_type, entity, origin, control_fn)
	ForEachTeamWithVisionAt(origin, function(team)
		local idx = ParticleManager:CreateParticleForTeam(particle_name, attach_type, entity, team)
		if control_fn then
			control_fn(idx, team)
		end
		ParticleManager:ReleaseParticleIndex(idx)
	end)
end

function CreateFOWParticleForTeams(particle_name, attach_type, entity, origin, control_fn)
	local particles = {}

	ForEachTeamWithVisionAt(origin, function(team)
		local idx = ParticleManager:CreateParticleForTeam(particle_name, attach_type, entity, team)
		if control_fn then
			control_fn(idx, team)
		end
		particles[team] = idx
	end)

	return particles
end

function DestroyFOWParticleForTeams(particles)
	if not particles then
		return
	end

	for _, idx in pairs(particles) do
		if idx then
			ParticleManager:DestroyParticle(idx, false)
			ParticleManager:ReleaseParticleIndex(idx)
		end
	end
end

function EmitFOWSoundAtLocation(location, sound_name)
	if not location or not sound_name then
		return
	end

	ForEachTeamWithVisionAt(location, function(team)
		for player_id = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
			if PlayerResource:IsValidPlayer(player_id) and PlayerResource:GetTeam(player_id) == team then
				EmitSoundOnLocationForPlayer(sound_name, location, player_id)
			end
		end
	end)
end

-- Sound on a unit only for players who can see it: allies always, enemies only while the unit
-- is visible to their team, spectators always. Plain EmitSoundOn is heard through fog of war.
-- heard (optional) is a table playerID -> true; for looping sounds call this again on every
-- think with the same table so enemies who start seeing the unit later also hear it.
function EmitSoundOnUnitForObservers(unit, sound_name, heard)
	if not unit or unit:IsNull() or not sound_name then
		return
	end

	local unit_team = unit:GetTeamNumber()
	local origin = unit:GetAbsOrigin()
	for player_id = 0, DOTA_MAX_TEAM_PLAYERS - 1 do
		if PlayerResource:IsValidPlayer(player_id) and not (heard and heard[player_id]) then
			local team = PlayerResource:GetTeam(player_id)
			local fighting = team == DOTA_TEAM_GOODGUYS or team == DOTA_TEAM_BADGUYS
			local sees = not fighting or team == unit_team
				or (IsLocationVisible(team, origin) and not unit:IsInvisible())
			if sees then
				if EmitSoundOnEntityForPlayer then
					EmitSoundOnEntityForPlayer(sound_name, unit, player_id)
				else
					EmitSoundOnLocationForPlayer(sound_name, origin, player_id)
				end
				if heard then
					heard[player_id] = true
				end
			end
		end
	end
end

function EmitFOWSoundOnUnit(unit, sound_name)
	if not unit or unit:IsNull() then
		return
	end

	EmitFOWSoundAtLocation(unit:GetAbsOrigin(), sound_name)
end
