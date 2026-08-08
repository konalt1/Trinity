pudge_meat_hook_trinity = class({})

LinkLuaModifier("modifier_pudge_meat_hook_trinity_caster", "abilities/pudge/pudge_meat_hook_trinity", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_pudge_meat_hook_trinity_pull", "abilities/pudge/pudge_meat_hook_trinity", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_pudge_meat_hook_trinity_charges", "abilities/pudge/pudge_meat_hook_trinity", LUA_MODIFIER_MOTION_NONE)

local HOOK_OFFSET = Vector(0, 0, 96)
local RUNE_CLASSNAME = "dota_item_rune"

local function IsValidHookEntity(entity)
	return entity and (not entity.IsNull or not entity:IsNull())
end

local function IsRuneEntity(entity)
	return IsValidHookEntity(entity)
		and entity.GetClassname
		and entity:GetClassname() == RUNE_CLASSNAME
end

local function FindRuneWithinHookRadius(position, radius)
	local radius_squared = radius * radius
	local nearest_rune = nil
	local nearest_distance_squared = radius_squared
	local rune = Entities:FindByClassname(nil, RUNE_CLASSNAME)

	while rune do
		if IsRuneEntity(rune) then
			local offset = rune:GetAbsOrigin() - position
			local distance_squared = offset.x * offset.x + offset.y * offset.y
			if distance_squared <= nearest_distance_squared then
				nearest_rune = rune
				nearest_distance_squared = distance_squared
			end
		end

		rune = Entities:FindByClassname(rune, RUNE_CLASSNAME)
	end

	return nearest_rune
end

function pudge_meat_hook_trinity:GetCastRange(_, _)
	return self:GetSpecialValueFor("AbilityCastRange")
end

function pudge_meat_hook_trinity:GetIntrinsicModifierName()
	return "modifier_pudge_meat_hook_trinity_charges"
end

function pudge_meat_hook_trinity:GetCooldown(_)
	local caster = self:GetCaster()
	if caster and not caster:IsNull() and caster:HasScepter() then
		return 0
	end
	return self:GetSpecialValueFor("hook_cooldown")
end

function pudge_meat_hook_trinity:GetHookChargeRestoreTime()
	return math.max(0.1, self:GetSpecialValueFor("hook_cooldown"))
end

function pudge_meat_hook_trinity:GetAbilityChargeRestoreTime(_)
	return self:GetHookChargeRestoreTime()
end

function pudge_meat_hook_trinity:UpdateScepterCharges()
	if not IsServer() then return end

	local caster = self:GetCaster()
	if not caster or caster:IsNull() then return end
	local has_scepter = caster:HasScepter()

	if has_scepter and self.scepter_charge_mode ~= true then
		self:SetCurrentAbilityCharges(2)
	elseif not has_scepter and self.scepter_charge_mode ~= false then
		self:SetCurrentAbilityCharges(0)
	end

	self.scepter_charge_mode = has_scepter
end

function pudge_meat_hook_trinity:OnAbilityPhaseStart()
	self:GetCaster():StartGesture(ACT_DOTA_OVERRIDE_ABILITY_1)
	return true
end

function pudge_meat_hook_trinity:OnAbilityPhaseInterrupted()
	self:GetCaster():RemoveGesture(ACT_DOTA_OVERRIDE_ABILITY_1)
end

function pudge_meat_hook_trinity:GetHookDamage(distance_traveled)
	local caster = self:GetCaster()
	local mind_power = GetHeroMindPower and (GetHeroMindPower(caster) or 0) or 0
	local damage = self:GetSpecialValueFor("damage")
		+ mind_power * self:GetSpecialValueFor("mind_power_multiplier")

	local distance_damage_pct = self:GetSpecialValueFor("distance_to_damage")
	if distance_damage_pct > 0 then
		local minimum_bonus = self:GetSpecialValueFor("min_distance_damage")
		damage = damage + math.max(minimum_bonus, distance_traveled * distance_damage_pct * 0.01)
	end

	return math.max(0, damage)
end


function pudge_meat_hook_trinity:OnSpellStart()
	local caster = self:GetCaster()
	self.hooks = self.hooks or {}
	local origin = caster:GetAbsOrigin()
	local direction = self:GetCursorPosition() - origin
	direction.z = 0
	if direction:Length2D() < 0.01 then
		direction = caster:GetForwardVector()
	else
		direction = direction:Normalized()
	end

	local speed = self:GetSpecialValueFor("hook_speed")
	local width = self:GetSpecialValueFor("hook_width")
	local distance = self:GetEffectiveCastRange(origin, caster)
	local target_position = origin + direction * distance + HOOK_OFFSET

	caster:AddNewModifier(caster, self, "modifier_pudge_meat_hook_trinity_caster", {
		duration = distance / speed * 0.65,
	})

	local wearable = caster:GetTogglableWearable(DOTA_LOADOUT_TYPE_WEAPON)
	if wearable then wearable:AddEffects(EF_NODRAW) end

	local particle = ParticleManager:CreateParticle("particles/units/heroes/hero_pudge/pudge_meathook.vpcf", PATTACH_CUSTOMORIGIN, nil)
	ParticleManager:SetParticleAlwaysSimulate(particle)
	ParticleManager:SetParticleControlEnt(particle, 0, caster, PATTACH_POINT_FOLLOW, "attach_weapon_chain_rt", origin + HOOK_OFFSET, true)
	ParticleManager:SetParticleControl(particle, 1, target_position)
	ParticleManager:SetParticleControl(particle, 2, Vector(speed, distance, width))
	ParticleManager:SetParticleControl(particle, 3, Vector(distance / speed * 2, 0, 0))
	ParticleManager:SetParticleControl(particle, 4, Vector(1, 0, 0))
	ParticleManager:SetParticleControl(particle, 5, Vector(0, 0, 0))
	ParticleManager:SetParticleControlEnt(particle, 7, caster, PATTACH_CUSTOMORIGIN, nil, origin, true)

	local thinker = CreateModifierThinker(caster, self, "modifier_invulnerable", {}, origin, caster:GetTeamNumber(), false)
	local projectile = ProjectileManager:CreateLinearProjectile({
		Ability = self,
		vSpawnOrigin = origin,
		vVelocity = direction * speed,
		fDistance = distance,
		fStartRadius = width,
		fEndRadius = width,
		Source = caster,
		iUnitTargetTeam = DOTA_UNIT_TARGET_TEAM_BOTH,
		iUnitTargetType = DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		iUnitTargetFlags = DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
	})

	self.hooks[projectile] = {
		projectile = projectile,
		particle = particle,
		thinker = thinker,
		caster = caster,
		start_position = origin,
		speed = speed,
		width = width,
		returning = false,
		target = nil,
		rune = nil,
		pull_modifier = nil,
	}

	thinker:EmitSound("Hero_Pudge.AttackHookExtend")
end


function pudge_meat_hook_trinity:IsValidHookTarget(target)
	if not IsValidHookEntity(target) then return false end
	if target == self:GetCaster() then return false end
	if not target.IsCreep or not target.IsConsideredHero then return false end
	return target:IsCreep() or target:IsConsideredHero()
end


function pudge_meat_hook_trinity:OnProjectileHitHandle(target, position, projectile)
	if not IsServer() then return true end

	local state = self.hooks[projectile]
	if not state then return true end
	if not IsValidHookEntity(state.thinker) then
		self:CleanupHook(projectile, false, false)
		return true
	end

	if not state.returning then
		if target == state.caster then return false end
		if target and not self:IsValidHookTarget(target) then return false end
		return self:StartHookReturn(projectile, target, position)
	end

	self:CleanupHook(projectile, true, false)
	return true
end


function pudge_meat_hook_trinity:StartHookReturn(projectile, target, position)
	local state = self.hooks[projectile]
	if not state then return true end

	state.thinker:StopSound("Hero_Pudge.AttackHookExtend")
	state.caster:RemoveModifierByName("modifier_pudge_meat_hook_trinity_caster")
	state.caster:RemoveGesture(ACT_DOTA_OVERRIDE_ABILITY_1)
	state.caster:StartGesture(ACT_DOTA_CHANNEL_ABILITY_1)

	local hook_position = position
	local pulled_rune = IsRuneEntity(target) and target or nil
	local pulled_target = not pulled_rune and self:IsValidHookTarget(target) and target or nil
	state.target = nil
	state.rune = nil

	if pulled_target then
		hook_position = pulled_target:GetAbsOrigin()
		pulled_target:EmitSound("Hero_Pudge.AttackHookImpact")

		if pulled_target:GetTeamNumber() ~= state.caster:GetTeamNumber() then
			local traveled = (hook_position - state.start_position):Length2D()
			local is_normal_creep = pulled_target:IsCreep()
				and not pulled_target:IsCreepHero()
				and not pulled_target:IsAncient()

			if is_normal_creep then
				pulled_target:Kill(self, state.caster)
			else
				ApplyDamage({
					victim = pulled_target,
					attacker = state.caster,
					damage = self:GetHookDamage(traveled),
					damage_type = DAMAGE_TYPE_PURE,
					ability = self,
				})
			end

			if pulled_target:IsIllusion() and pulled_target:IsAlive() then
				pulled_target:Kill(self, state.caster)
			end
			if not pulled_target:IsMagicImmune() then pulled_target:Interrupt() end

			local impact = ParticleManager:CreateParticle("particles/units/heroes/hero_pudge/pudge_meathook_impact.vpcf", PATTACH_CUSTOMORIGIN, pulled_target)
			ParticleManager:SetParticleControlEnt(impact, 0, pulled_target, PATTACH_POINT_FOLLOW, "attach_hitloc", hook_position, true)
			ParticleManager:ReleaseParticleIndex(impact)
		else
			local reduction = self:GetSpecialValueFor("cooldown_reduction_pct_allied_hook")
			local remaining = self:GetCooldownTimeRemaining()
			if reduction > 0 and remaining > 0 then
				self:EndCooldown()
				self:StartCooldown(remaining * (1 - reduction * 0.01))
			end
		end

		AddFOWViewer(state.caster:GetTeamNumber(), hook_position, self:GetSpecialValueFor("vision_radius"), self:GetSpecialValueFor("vision_duration"), false)

		local return_target = pulled_target:IsAlive() and pulled_target or nil
		state.target = return_target

		if return_target then
			local return_duration = (hook_position - state.start_position):Length2D() / state.speed + 0.1
			state.pull_modifier = return_target:AddNewModifier(state.caster, self, "modifier_pudge_meat_hook_trinity_pull", { duration = return_duration })
			ParticleManager:SetParticleControlEnt(state.particle, 1, return_target, PATTACH_POINT_FOLLOW, "attach_hitloc", hook_position + HOOK_OFFSET, true)
		else
			ParticleManager:SetParticleControl(state.particle, 1, hook_position + HOOK_OFFSET)
		end
	elseif pulled_rune then
		hook_position = pulled_rune:GetAbsOrigin()
		state.rune = pulled_rune
		ParticleManager:SetParticleControl(state.particle, 1, hook_position + HOOK_OFFSET)

		local mana_cost = self:GetManaCost(-1)
		if mana_cost > 0 then state.caster:GiveMana(mana_cost) end
	else
		ParticleManager:SetParticleControl(state.particle, 1, hook_position + HOOK_OFFSET)
	end

	ParticleManager:SetParticleControl(state.particle, 4, Vector(0, 0, 0))
	ParticleManager:SetParticleControl(state.particle, 5, Vector(1, 0, 0))

	local velocity = state.start_position - hook_position
	velocity.z = 0
	local return_distance = math.max(1, velocity:Length2D() - state.caster:GetPaddedCollisionRadius())
	if state.target then return_distance = math.max(1, return_distance - state.target:GetPaddedCollisionRadius()) end
	velocity = velocity:Normalized() * state.speed

	state.thinker:EmitSound("Hero_Pudge.AttackHookRetract")
	state.returning = true
	local return_projectile = ProjectileManager:CreateLinearProjectile({
		Ability = self,
		vSpawnOrigin = hook_position,
		vVelocity = velocity,
		fDistance = return_distance,
		Source = state.caster,
	})

	self.hooks[projectile] = nil
	state.projectile = return_projectile
	self.hooks[return_projectile] = state

	if IsRuneEntity(state.rune) then
		state.thinker:SetContextThink("PudgeRuneHookFollow", function()
			if not IsValidHookEntity(state.thinker)
				or self.hooks[state.projectile] ~= state
				or not IsRuneEntity(state.rune) then
				return nil
			end

			local current_position = ProjectileManager:GetLinearProjectileLocation(state.projectile)
			state.thinker:SetAbsOrigin(current_position)
			state.rune:SetAbsOrigin(GetGroundPosition(current_position, state.rune))
			ParticleManager:SetParticleControl(state.particle, 1, current_position + HOOK_OFFSET)
			return FrameTime()
		end, 0)
	end

	return true
end


function pudge_meat_hook_trinity:OnProjectileThinkHandle(projectile)
	if not IsServer() then return end
	local state = self.hooks[projectile]
	if not state or not IsValidHookEntity(state.thinker) then return end

	local position = ProjectileManager:GetLinearProjectileLocation(projectile)
	state.thinker:SetAbsOrigin(position)

	if not state.returning then
		local rune = FindRuneWithinHookRadius(position, state.width)
		if IsRuneEntity(rune) then
			ProjectileManager:DestroyLinearProjectile(projectile)
			self:StartHookReturn(projectile, rune, rune:GetAbsOrigin())
			return
		end
	end

	if state.returning and (not IsValidHookEntity(state.target) or not state.target:IsAlive()) then
		if IsRuneEntity(state.rune) then
			state.rune:SetAbsOrigin(GetGroundPosition(position, state.rune))
		end
		ParticleManager:SetParticleControl(state.particle, 1, position + HOOK_OFFSET)
	elseif state.returning then
		state.target:SetOrigin(GetGroundPosition(position, state.target))
		local facing = state.start_position - state.target:GetAbsOrigin()
		facing.z = 0
		if facing:Length2D() > 0.01 then state.target:SetForwardVector(facing:Normalized()) end
	end
end


function pudge_meat_hook_trinity:CleanupHook(projectile, place_target, destroy_projectile)
	local state = self.hooks[projectile]
	if not state then return end
	if destroy_projectile then ProjectileManager:DestroyLinearProjectile(projectile) end

	if IsValidHookEntity(state.pull_modifier) then state.pull_modifier:Destroy() end

	if place_target and IsValidHookEntity(state.target) and state.target:IsAlive() then
		local away = state.target:GetAbsOrigin() - state.start_position
		away.z = 0
		if away:Length2D() < 0.01 then away = state.caster:GetForwardVector() else away = away:Normalized() end
		local padding = state.caster:GetPaddedCollisionRadius() + state.target:GetPaddedCollisionRadius()
		FindClearSpaceForUnit(state.target, state.start_position + away * padding, false)
	end

	if place_target and IsRuneEntity(state.rune) then
		state.rune:SetAbsOrigin(GetGroundPosition(state.start_position, state.rune))
	end

	if IsValidHookEntity(state.thinker) then
		state.thinker:StopSound("Hero_Pudge.AttackHookExtend")
		state.thinker:StopSound("Hero_Pudge.AttackHookRetract")
		UTIL_Remove(state.thinker)
	end

	ParticleManager:DestroyParticle(state.particle, true)
	ParticleManager:ReleaseParticleIndex(state.particle)
	self.hooks[projectile] = nil

	if IsValidHookEntity(state.caster) then
		state.caster:RemoveGesture(ACT_DOTA_CHANNEL_ABILITY_1)
		state.caster:EmitSound("Hero_Pudge.AttackHookRetractStop")
		if next(self.hooks) == nil then
			local wearable = state.caster:GetTogglableWearable(DOTA_LOADOUT_TYPE_WEAPON)
			if wearable then wearable:RemoveEffects(EF_NODRAW) end
		end
	end
end


function pudge_meat_hook_trinity:OnOwnerDied()
	local caster = self:GetCaster()
	caster:RemoveGesture(ACT_DOTA_OVERRIDE_ABILITY_1)
	caster:RemoveGesture(ACT_DOTA_CHANNEL_ABILITY_1)

	local active_projectiles = {}
	self.hooks = self.hooks or {}
	for projectile in pairs(self.hooks) do table.insert(active_projectiles, projectile) end
	for _, projectile in pairs(active_projectiles) do self:CleanupHook(projectile, false, true) end
end


modifier_pudge_meat_hook_trinity_charges = class({})

function modifier_pudge_meat_hook_trinity_charges:IsHidden() return true end
function modifier_pudge_meat_hook_trinity_charges:IsPurgable() return false end
function modifier_pudge_meat_hook_trinity_charges:RemoveOnDeath() return false end

function modifier_pudge_meat_hook_trinity_charges:OnCreated()
	if not IsServer() then return end
	self:GetAbility():UpdateScepterCharges()
	self:StartIntervalThink(0.2)
end

function modifier_pudge_meat_hook_trinity_charges:OnIntervalThink()
	local ability = self:GetAbility()
	if not ability or ability:IsNull() then
		self:Destroy()
		return
	end
	ability:UpdateScepterCharges()
end


modifier_pudge_meat_hook_trinity_caster = class({})

function modifier_pudge_meat_hook_trinity_caster:IsHidden() return true end
function modifier_pudge_meat_hook_trinity_caster:IsPurgable() return false end
function modifier_pudge_meat_hook_trinity_caster:CheckState()
	return { [MODIFIER_STATE_STUNNED] = true }
end


modifier_pudge_meat_hook_trinity_pull = class({})

function modifier_pudge_meat_hook_trinity_pull:IsHidden() return true end
function modifier_pudge_meat_hook_trinity_pull:IsDebuff() return self:GetParent():GetTeamNumber() ~= self:GetCaster():GetTeamNumber() end
function modifier_pudge_meat_hook_trinity_pull:IsPurgable() return false end
function modifier_pudge_meat_hook_trinity_pull:RemoveOnDeath() return false end
function modifier_pudge_meat_hook_trinity_pull:GetAttributes() return MODIFIER_ATTRIBUTE_MULTIPLE end
function modifier_pudge_meat_hook_trinity_pull:DeclareFunctions()
	return { MODIFIER_PROPERTY_OVERRIDE_ANIMATION }
end
function modifier_pudge_meat_hook_trinity_pull:GetOverrideAnimation() return ACT_DOTA_FLAIL end

function modifier_pudge_meat_hook_trinity_pull:CheckState()
	if self:GetParent():GetTeamNumber() ~= self:GetCaster():GetTeamNumber() and not self:GetParent():IsMagicImmune() then
		return {
			[MODIFIER_STATE_STUNNED] = true,
			[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
		}
	end
	return { [MODIFIER_STATE_NO_UNIT_COLLISION] = true }
end

function modifier_pudge_meat_hook_trinity_pull:OnDestroy()
	if not IsServer() then return end
	local parent = self:GetParent()
	if IsValidHookEntity(parent) and parent:IsAlive() then FindClearSpaceForUnit(parent, parent:GetAbsOrigin(), false) end
end
