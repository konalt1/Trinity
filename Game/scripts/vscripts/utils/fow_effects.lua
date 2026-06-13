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

function EmitFOWSoundOnUnit(unit, sound_name)
	if not unit or unit:IsNull() then
		return
	end

	EmitFOWSoundAtLocation(unit:GetAbsOrigin(), sound_name)
end
