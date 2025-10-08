modifier_juggernaut_swift_slash_lua_thinker = class({})

--------------------------------------------------------------------------------
-- Classifications
function modifier_juggernaut_swift_slash_lua_thinker:IsHidden()
	return true
end

function modifier_juggernaut_swift_slash_lua_thinker:IsPurgable()
	return false
end

function modifier_juggernaut_swift_slash_lua_thinker:RemoveOnDeath()
	return false
end

--------------------------------------------------------------------------------
-- Initializations
function modifier_juggernaut_swift_slash_lua_thinker:OnCreated( kv )
	if not IsServer() then return end
	
	self.caster_index = kv.caster_index
	self.damage = kv.damage
	self.current_slashes = kv.current_slashes
	self.max_slashes = kv.max_slashes
	self.jump_delay = kv.jump_delay
	self.hit_targets_string = kv.hit_targets or ""
end

function modifier_juggernaut_swift_slash_lua_thinker:OnDestroy()
	if not IsServer() then return end
	
	local caster = EntIndexToHScript(self.caster_index)
	if not caster or not IsValidEntity(caster) or not caster:IsAlive() then return end
	
	-- convert hit targets back
	local hit_targets = self:GetAbility():IndexesToTable(self.hit_targets_string)
	
	-- find next target
	local search_radius = 425 -- omnislash radius
	local enemies = FindUnitsInRadius(
		caster:GetTeamNumber(),
		self:GetParent():GetAbsOrigin(),
		nil,
		search_radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
		FIND_CLOSEST,
		false
	)

	-- find valid target that hasn't been hit
	local next_target = nil
	for _, enemy in pairs(enemies) do
		if enemy ~= self:GetParent() and not hit_targets[enemy] and enemy:IsAlive() then
			next_target = enemy
			break
		end
	end

	if next_target then
		-- continue slashing
		local data = {
			damage = self.damage,
			current_slashes = self.current_slashes,
			max_slashes = self.max_slashes,
			jump_delay = self.jump_delay,
			hit_targets = hit_targets
		}
		
		self:GetAbility():PerformSlash(caster, next_target, data)
	end
end 