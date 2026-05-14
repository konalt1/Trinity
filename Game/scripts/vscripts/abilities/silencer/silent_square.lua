silent_square = class({})

LinkLuaModifier("modifier_silent_square_thinker", "abilities/silencer/silent_square", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_silent_square_debuff", "abilities/silencer/silent_square", LUA_MODIFIER_MOTION_NONE)

function silent_square:Precache(context)
	PrecacheResource("particle", "particles/silencer/local_silence/faceless_void_chronocube.vpcf", context)
end

function silent_square:GetAOERadius()
	local caster = self:GetCaster()
	if not caster or caster:IsNull() then
		return 250
	end

	local mind_power = GetHeroMindPower and (GetHeroMindPower(caster) or 0) or (caster:GetIntellect(false) or 0)
	local side = self:GetSpecialValueFor("base_side_length") + mind_power * self:GetSpecialValueFor("mind_power_side_bonus")
	return math.max(0, side * 0.5)
end

function silent_square:OnSpellStart()
	local caster = self:GetCaster()
	local point = self:GetCursorPosition()

	local base_duration = self:GetSpecialValueFor("base_duration")
	local duration_per_mind_power = self:GetSpecialValueFor("mind_power_duration_bonus")
	local base_side = self:GetSpecialValueFor("base_side_length")
	local side_per_mind_power = self:GetSpecialValueFor("mind_power_side_bonus")
	local think_interval = self:GetSpecialValueFor("think_interval")
	local move_slow_pct = self:GetSpecialValueFor("move_slow_pct")

	local mind_power = GetHeroMindPower and (GetHeroMindPower(caster) or 0) or (caster:GetIntellect(false) or 0)
	local duration = math.max(0.1, base_duration + mind_power * duration_per_mind_power)
	local side_length = math.max(1, base_side + mind_power * side_per_mind_power)

	CreateModifierThinker(
		caster,
		self,
		"modifier_silent_square_thinker",
		{
			duration = duration,
			side_length = side_length,
			think_interval = think_interval,
			move_slow_pct = move_slow_pct
		},
		point,
		caster:GetTeamNumber(),
		false
	)

	EmitSoundOn("Hero_Silencer.GlobalSilence.Cast", caster)
end

modifier_silent_square_thinker = class({})

function modifier_silent_square_thinker:IsHidden()
	return true
end

function modifier_silent_square_thinker:IsPurgable()
	return false
end

function modifier_silent_square_thinker:OnCreated(kv)
	if not IsServer() then return end

	local ability = self:GetAbility()
	self.side_length = tonumber(kv.side_length) or ability:GetSpecialValueFor("base_side_length")
	self.half_side = self.side_length * 0.5
	self.think_interval = tonumber(kv.think_interval) or ability:GetSpecialValueFor("think_interval")
	self.move_slow_pct = tonumber(kv.move_slow_pct) or ability:GetSpecialValueFor("move_slow_pct")
	self.end_time = GameRules:GetGameTime() + (tonumber(kv.duration) or self:GetDuration() or 0)
	self.active_debuffed_units = {}

	-- CP1.x = sphere radius; scale to square circumradius so the chronosphere encloses the debuff square.
	local cp1_radius = self.half_side * math.sqrt(2)
	self.zone_particle = ParticleManager:CreateParticle("particles/silencer/local_silence/faceless_void_chronocube.vpcf", PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(self.zone_particle, 0, self:GetParent():GetAbsOrigin())
	ParticleManager:SetParticleControl(self.zone_particle, 1, Vector(cp1_radius, cp1_radius, cp1_radius))

	self:StartIntervalThink(self.think_interval)
	self:OnIntervalThink()
end

function modifier_silent_square_thinker:IsInsideSquare(position)
	local center = self:GetParent():GetAbsOrigin()
	local dx = math.abs(position.x - center.x)
	local dy = math.abs(position.y - center.y)
	return dx <= self.half_side and dy <= self.half_side
end

function modifier_silent_square_thinker:OnIntervalThink()
	if not IsServer() then return end

	local caster = self:GetCaster()
	local ability = self:GetAbility()
	if not caster or caster:IsNull() or not ability or ability:IsNull() then
		self:Destroy()
		return
	end

	local center = self:GetParent():GetAbsOrigin()
	local vision_radius = math.ceil(self.half_side * math.sqrt(2))
	AddFOWViewer(caster:GetTeamNumber(), center, vision_radius, self.think_interval + 0.1, false)

	local now = GameRules:GetGameTime()
	local remaining_duration = self.end_time - now
	if remaining_duration <= 0 then
		self:Destroy()
		return
	end

	local enemies = FindUnitsInRadius(
		caster:GetTeamNumber(),
		center,
		nil,
		vision_radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)

	local units_inside = {}
	for _, enemy in pairs(enemies) do
		if enemy and not enemy:IsNull() and enemy:IsAlive() and (not enemy:IsMagicImmune()) and self:IsInsideSquare(enemy:GetAbsOrigin()) then
			local entindex = enemy:entindex()
			units_inside[entindex] = enemy

			local active_modifier = self.active_debuffed_units[entindex]
			if not active_modifier or active_modifier:IsNull() then
				self.active_debuffed_units[entindex] = enemy:AddNewModifier(caster, ability, "modifier_silent_square_debuff", {
					duration = remaining_duration,
					move_slow_pct = self.move_slow_pct
				})
			end
		end
	end

	for entindex, active_modifier in pairs(self.active_debuffed_units) do
		if not units_inside[entindex] then
			self.active_debuffed_units[entindex] = nil
			if active_modifier and not active_modifier:IsNull() then
				active_modifier:Destroy()
			end
		end
	end
end

function modifier_silent_square_thinker:OnDestroy()
	if not IsServer() then return end

	if self.zone_particle then
		ParticleManager:DestroyParticle(self.zone_particle, false)
		ParticleManager:ReleaseParticleIndex(self.zone_particle)
		self.zone_particle = nil
	end

	for entindex, _ in pairs(self.active_debuffed_units or {}) do
		local active_modifier = self.active_debuffed_units[entindex]
		if active_modifier and not active_modifier:IsNull() then
			active_modifier:Destroy()
		end
	end
	self.active_debuffed_units = {}
end

modifier_silent_square_debuff = class({})

function modifier_silent_square_debuff:IsHidden()
	return false
end

function modifier_silent_square_debuff:IsDebuff()
	return true
end

function modifier_silent_square_debuff:IsPurgable()
	return true
end

function modifier_silent_square_debuff:OnCreated(kv)
	self.move_slow_pct = tonumber(kv.move_slow_pct) or 0
end

function modifier_silent_square_debuff:OnRefresh(kv)
	self.move_slow_pct = tonumber(kv.move_slow_pct) or self.move_slow_pct or 0
end

function modifier_silent_square_debuff:CheckState()
	return {
		[MODIFIER_STATE_SILENCED] = true
	}
end

function modifier_silent_square_debuff:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE
	}
end

function modifier_silent_square_debuff:GetModifierMoveSpeedBonus_Percentage()
	return self.move_slow_pct
end

function modifier_silent_square_debuff:GetEffectName()
	return "particles/generic_gameplay/generic_silenced.vpcf"
end

function modifier_silent_square_debuff:GetEffectAttachType()
	return PATTACH_OVERHEAD_FOLLOW
end
