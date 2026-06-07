LinkLuaModifier("modifier_ability_sinister_gaze_debuff", "abilities/lich/ability_sinister_gaze", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_ability_sinister_gaze_illusion", "abilities/lich/ability_sinister_gaze", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_ability_sinister_gaze_channel_animation", "abilities/lich/ability_sinister_gaze", LUA_MODIFIER_MOTION_NONE)

local LICH_SINISTER_GAZE_CAST_ACTIVITY = ACT_DOTA_CAST_ABILITY_4
local LICH_SINISTER_GAZE_CHANNEL_ACTIVITY = ACT_DOTA_CHANNEL_ABILITY_4 or ACT_DOTA_CAST_ABILITY_4

ability_sinister_gaze = class({})

function ability_sinister_gaze:Spawn()
	if IsClient() then return end
	if self:GetLevel() == 0 then
		self:SetLevel(1)
	end
end

function ability_sinister_gaze:Precache(context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_lich.vsndevts", context)
	PrecacheResource("particle", "particles/units/heroes/hero_lich/lich_sinister_gaze.vpcf", context)
	PrecacheResource("particle", "particles/units/heroes/hero_lich/lich_dark_ritual.vpcf", context)
	PrecacheResource("particle", "particles/econ/items/lich/lich_ti10_immortal_head/lich_ti10_immortal_gaze_target_head.vpcf", context)
	PrecacheResource("particle", "particles/econ/items/lich/lich_ti10_immortal_head/lich_ti10_immortal_gaze_ground_rings.vpcf", context)
	PrecacheResource("particle", "particles/econ/items/lich/lich_ti10_immortal_head/lich_ti10_immortal_gaze_chain_02.vpcf", context)
	PrecacheResource("particle", "particles/status_fx/status_effect_frost_lich.vpcf", context)
end

function ability_sinister_gaze:GetChannelTime()
	return self:GetSpecialValueFor("gaze_duration")
end

function ability_sinister_gaze:GetBehavior()
	return DOTA_ABILITY_BEHAVIOR_UNIT_TARGET + DOTA_ABILITY_BEHAVIOR_CHANNELLED
end

function ability_sinister_gaze:CastFilterResultTarget(target)
	if not target then
		return UF_FAIL_CUSTOM
	end

	local caster = self:GetCaster()
	if target == caster then
		return UF_FAIL_CUSTOM
	end

	if target:GetTeamNumber() == caster:GetTeamNumber() then
		return UF_FAIL_ENEMY
	end

	if not target:IsRealHero() or target:IsIllusion() then
		return UF_FAIL_HERO
	end

	return UF_SUCCESS
end

function ability_sinister_gaze:GetCustomCastErrorTarget(target)
	if not target then
		return ""
	end

	if target == self:GetCaster() then
		return "#dota_hud_error_cant_cast_on_self"
	end

	if not target:IsRealHero() or target:IsIllusion() then
		return "#dota_hud_error_must_target_enemy_hero"
	end

	return ""
end

function ability_sinister_gaze:OnAbilityPhaseStart()
	local caster = self:GetCaster()
	if caster and not caster:IsNull() and LICH_SINISTER_GAZE_CAST_ACTIVITY then
		caster:StartGesture(LICH_SINISTER_GAZE_CAST_ACTIVITY)
	end

	return true
end

function ability_sinister_gaze:OnAbilityPhaseInterrupted()
	local caster = self:GetCaster()
	if caster and not caster:IsNull() and LICH_SINISTER_GAZE_CAST_ACTIVITY then
		caster:FadeGesture(LICH_SINISTER_GAZE_CAST_ACTIVITY)
	end
end

function ability_sinister_gaze:OnSpellStart()
	local caster = self:GetCaster()
	local target = self:GetCursorTarget()
	if not target then return end

	if target:TriggerSpellAbsorb(self) then
		return
	end

	target:AddNewModifier(
		caster,
		self,
		"modifier_ability_sinister_gaze_debuff",
		{ duration = self:GetChannelTime() }
	)

	EmitSoundOn("Hero_Lich.SinisterGaze.Cast", caster)
	EmitSoundOn("Hero_Lich.SinisterGaze.Target", target)
end

function ability_sinister_gaze:OnChannelFinish(interrupted)
end

function ability_sinister_gaze:CreateTargetIllusion(target)
	if not IsServer() then return end
	if not target or target:IsNull() then return end

	local caster = self:GetCaster()
	if not caster or caster:IsNull() then return end

	local duration = self:GetSpecialValueFor("illusion_duration")
	local outgoing_total = self:GetSpecialValueFor("illusion_outgoing_damage")
	local incoming_total = self:GetSpecialValueFor("illusion_incoming_damage")

	local illusions = CreateIllusions(
		caster,
		target,
		{
			outgoing_damage = outgoing_total - 100,
			incoming_damage = incoming_total - 100,
			bounty_base = 0,
			bounty_growth = 0,
			duration = duration,
		},
		1,
		0,
		false,
		true
	)

	for _, illusion in pairs(illusions or {}) do
		if illusion and not illusion:IsNull() then
			illusion:SetOwner(caster)
			illusion:SetControllableByPlayer(caster:GetPlayerOwnerID(), true)
			illusion:AddNewModifier(caster, self, "modifier_ability_sinister_gaze_illusion", { duration = duration })
			illusion:SetHealth(illusion:GetMaxHealth())

			for slot = 0, 23 do
				local ability = illusion:GetAbilityByIndex(slot)
				if ability and not ability:IsNull() then
					ability:SetActivated(false)
				end
			end

			for item_slot = 0, 8 do
				local item = illusion:GetItemInSlot(item_slot)
				if item and not item:IsNull() then
					item:SetActivated(false)
				end
			end

			local particle = ParticleManager:CreateParticle(
				"particles/units/heroes/hero_lich/lich_dark_ritual.vpcf",
				PATTACH_ABSORIGIN_FOLLOW,
				illusion
			)
			ParticleManager:ReleaseParticleIndex(particle)

			EmitSoundOn("Hero_Lich.SinisterGaze.Target", illusion)
		end
	end
end

modifier_ability_sinister_gaze_debuff = class({})

function modifier_ability_sinister_gaze_debuff:IsHidden()
	return false
end

function modifier_ability_sinister_gaze_debuff:IsDebuff()
	return true
end

function modifier_ability_sinister_gaze_debuff:IsPurgable()
	return true
end

function modifier_ability_sinister_gaze_debuff:OnCreated()
	if not IsServer() then return end

	self.parent = self:GetParent()
	self.caster = self:GetCaster()
	self.ability = self:GetAbility()
	self.caster_origin = self.caster:GetAbsOrigin()
	self.pull_speed = self.ability:GetSpecialValueFor("pull_speed")
	self.pull_stop_distance = self.ability:GetSpecialValueFor("pull_distance")
	self.illusion_spawned = false
	self.channel_animation_modifier = nil
	self.chain_particle = nil
	self.scepter_target_particle = nil
	self.scepter_ground_particle = nil

	if self.caster and not self.caster:IsNull() and self.parent and not self.parent:IsNull() then
		self.channel_animation_modifier = self.caster:AddNewModifier(
			self.caster,
			self.ability,
			"modifier_ability_sinister_gaze_channel_animation",
			{ duration = self:GetDuration() }
		)

		self.chain_particle = ParticleManager:CreateParticle(
			"particles/econ/items/lich/lich_ti10_immortal_head/lich_ti10_immortal_gaze_chain_02.vpcf",
			PATTACH_ABSORIGIN_FOLLOW,
			self.caster
		)
		ParticleManager:SetParticleControlEnt(self.chain_particle, 1, self.parent, PATTACH_ABSORIGIN_FOLLOW, nil, self.parent:GetAbsOrigin(), true)
		ParticleManager:SetParticleControlEnt(self.chain_particle, 3, self.caster, PATTACH_ABSORIGIN_FOLLOW, nil, self.caster:GetAbsOrigin(), true)
	end

	if self.caster and not self.caster:IsNull() and self.caster:HasScepter() then
		self.scepter_target_particle = ParticleManager:CreateParticle(
			"particles/econ/items/lich/lich_ti10_immortal_head/lich_ti10_immortal_gaze_target_head.vpcf",
			PATTACH_OVERHEAD_FOLLOW,
			self.parent
		)

		self.scepter_ground_particle = ParticleManager:CreateParticle(
			"particles/econ/items/lich/lich_ti10_immortal_head/lich_ti10_immortal_gaze_ground_rings.vpcf",
			PATTACH_ABSORIGIN_FOLLOW,
			self.caster
		)
	end

	self:StartIntervalThink(FrameTime())
end

function modifier_ability_sinister_gaze_debuff:OnIntervalThink()
	if not IsServer() then return end
	if not self.parent or self.parent:IsNull() or not self.parent:IsAlive() then
		self:Destroy()
		return
	end
	if not self.caster or self.caster:IsNull() or not self.caster:IsAlive() then
		self:Destroy()
		return
	end
	if not self.ability or self.ability:IsNull() then
		self:Destroy()
		return
	end

	if (self.caster:GetAbsOrigin() - self.caster_origin):Length2D() > 5 then
		self:Destroy()
		return
	end

	self:PullTowardsCaster(FrameTime())
end

function modifier_ability_sinister_gaze_debuff:PullTowardsCaster(dt)
	if not self.parent or self.parent:IsNull() then return end
	if not self.caster or self.caster:IsNull() then return end

	local parent_pos = self.parent:GetAbsOrigin()
	local caster_pos = self.caster:GetAbsOrigin()
	local offset = caster_pos - parent_pos
	offset.z = 0

	local distance = offset:Length2D()
	if distance <= self.pull_stop_distance then
		return
	end

	local direction = offset:Normalized()
	local move_distance = self.pull_speed * dt
	local remaining = distance - self.pull_stop_distance
	if move_distance > remaining then
		move_distance = remaining
	end

	local new_pos = parent_pos + direction * move_distance
	self.parent:SetAbsOrigin(new_pos)
	self.parent:SetForwardVector(direction)
end

function modifier_ability_sinister_gaze_debuff:OnDestroy()
	if not IsServer() then return end

	if self.channel_animation_modifier and not self.channel_animation_modifier:IsNull() then
		self.channel_animation_modifier:Destroy()
		self.channel_animation_modifier = nil
	end

	if self.chain_particle then
		ParticleManager:DestroyParticle(self.chain_particle, false)
		ParticleManager:ReleaseParticleIndex(self.chain_particle)
		self.chain_particle = nil
	end

	if self.scepter_target_particle then
		ParticleManager:DestroyParticle(self.scepter_target_particle, false)
		ParticleManager:ReleaseParticleIndex(self.scepter_target_particle)
		self.scepter_target_particle = nil
	end

	if self.scepter_ground_particle then
		ParticleManager:DestroyParticle(self.scepter_ground_particle, false)
		ParticleManager:ReleaseParticleIndex(self.scepter_ground_particle)
		self.scepter_ground_particle = nil
	end

	if self.parent and not self.parent:IsNull() then
		self.parent:StopSound("Hero_Lich.SinisterGaze.Target")
	end

	if self.caster and not self.caster:IsNull() then
		self.caster:StopSound("Hero_Lich.SinisterGaze.Cast")
	end

	if self.parent and not self.parent:IsNull() and self.parent:IsAlive() then
		FindClearSpaceForUnit(self.parent, self.parent:GetAbsOrigin(), true)
	end
end

function modifier_ability_sinister_gaze_debuff:DeclareFunctions()
	return {
		MODIFIER_EVENT_ON_DEATH,
		MODIFIER_PROPERTY_OVERRIDE_ANIMATION,
	}
end

function modifier_ability_sinister_gaze_debuff:OnDeath(event)
	if not IsServer() then return end
	if self.illusion_spawned then return end
	if not event.unit or event.unit ~= self.parent then return end
	if not self.ability or self.ability:IsNull() then return end
	if not self.parent:IsRealHero() or self.parent:IsReincarnating() then return end

	self.illusion_spawned = true
	self.ability:CreateTargetIllusion(self.parent)
end

function modifier_ability_sinister_gaze_debuff:GetOverrideAnimation()
	return ACT_DOTA_FLAIL
end

function modifier_ability_sinister_gaze_debuff:CheckState()
	return {
		[MODIFIER_STATE_COMMAND_RESTRICTED] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
		[MODIFIER_STATE_ROOTED] = true,
	}
end

function modifier_ability_sinister_gaze_debuff:GetEffectName()
	return "particles/units/heroes/hero_lich/lich_sinister_gaze.vpcf"
end

function modifier_ability_sinister_gaze_debuff:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end

function modifier_ability_sinister_gaze_debuff:GetStatusEffectName()
	return "particles/status_fx/status_effect_frost_lich.vpcf"
end

function modifier_ability_sinister_gaze_debuff:StatusEffectPriority()
	return MODIFIER_PRIORITY_HIGH
end

modifier_ability_sinister_gaze_illusion = class({})

function modifier_ability_sinister_gaze_illusion:IsHidden()
	return false
end

function modifier_ability_sinister_gaze_illusion:IsDebuff()
	return false
end

function modifier_ability_sinister_gaze_illusion:IsPurgable()
	return false
end

function modifier_ability_sinister_gaze_illusion:RemoveOnDeath()
	return true
end

function modifier_ability_sinister_gaze_illusion:CheckState()
	local state = {}

	if MODIFIER_STATE_SUPER_ILLUSION ~= nil then
		state[MODIFIER_STATE_SUPER_ILLUSION] = true
	end

	return state
end

function modifier_ability_sinister_gaze_illusion:GetTexture()
	return "lich_sinister_gaze"
end

modifier_ability_sinister_gaze_channel_animation = class({})

function modifier_ability_sinister_gaze_channel_animation:IsHidden()
	return true
end

function modifier_ability_sinister_gaze_channel_animation:IsPurgable()
	return false
end

function modifier_ability_sinister_gaze_channel_animation:RemoveOnDeath()
	return true
end

function modifier_ability_sinister_gaze_channel_animation:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_OVERRIDE_ANIMATION,
	}
end

function modifier_ability_sinister_gaze_channel_animation:GetOverrideAnimation()
	return LICH_SINISTER_GAZE_CHANNEL_ACTIVITY
end
