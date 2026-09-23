LinkLuaModifier("modifier_largo_frogstomp_debuff", "abilities/largo/largo_frogstomp", LUA_MODIFIER_MOTION_NONE)

largo_frogstomp_trinity = class({})

local PARTICLE_FROGSTOMP = "particles/units/heroes/hero_largo/largo_frogstomp.vpcf"
local PARTICLE_PROJECTILE = "particles/units/heroes/hero_largo/largo_frogstomp_projectile.vpcf"
local THROW_ATTACHMENTS = {
	"attach_attack1",
	"attach_attack2",
	"attach_hitloc",
}

local function IsValid(unit)
	return unit and not unit:IsNull() and IsValidEntity(unit)
end

local function HorizontalVector(vector)
	return Vector(vector.x, vector.y, 0)
end

function largo_frogstomp_trinity:Precache(context)
	PrecacheResource("particle", PARTICLE_FROGSTOMP, context)
	PrecacheResource("particle", PARTICLE_PROJECTILE, context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_largo.vsndevts", context)
end

function largo_frogstomp_trinity:GetAOERadius()
	return self:GetRadius()
end

function largo_frogstomp_trinity:GetRadius()
	local radius = self:GetSpecialValueFor("radius")
	if GetHeroBonusSpellAoE then
		radius = radius + (GetHeroBonusSpellAoE(self:GetCaster()) or 0)
	end
	return math.max(0, radius)
end

function largo_frogstomp_trinity:GetStompDamage()
	local caster = self:GetCaster()
	local mindPower = 0
	if caster and GetHeroMindPower then
		mindPower = GetHeroMindPower(caster) or 0
	end

	return math.max(0,
		self:GetSpecialValueFor("damage_per_stomp")
		+ mindPower * self:GetSpecialValueFor("mind_power_multiplier")
	)
end

function largo_frogstomp_trinity:GetTickCount()
	local ticks = math.floor(self:GetSpecialValueFor("total_ticks") + 0.5)
	if ticks < 1 then
		ticks = 4
	end
	return ticks
end

function largo_frogstomp_trinity:GetTickInterval()
	local interval = self:GetSpecialValueFor("tick_interval")
	if interval < 0.25 then
		interval = 1.0
	end
	return interval
end

function largo_frogstomp_trinity:GetEffectDelay()
	local delay = self:GetSpecialValueFor("effect_delay")
	if delay < 0.05 then
		delay = 0.5
	end
	return delay
end

function largo_frogstomp_trinity:GetThrowOrigin(caster)
	if caster.ScriptLookupAttachment and caster.GetAttachmentOrigin then
		for _, name in ipairs(THROW_ATTACHMENTS) do
			local id = caster:ScriptLookupAttachment(name)
			if id and id > 0 then
				return caster:GetAttachmentOrigin(id)
			end
		end
	end

	local origin = caster:GetAbsOrigin()
	return Vector(origin.x, origin.y, origin.z + 80)
end

function largo_frogstomp_trinity:ThrowFroglings(caster, point)
	local origin = self:GetThrowOrigin(caster)
	local offset = HorizontalVector(point - origin)
	local distance = offset:Length2D()
	local direction
	if distance < 16 then
		direction = HorizontalVector(caster:GetForwardVector())
		if direction:Length2D() < 0.01 then
			direction = Vector(1, 0, 0)
		else
			direction = direction:Normalized()
		end
		distance = 16
	else
		direction = offset:Normalized()
	end

	local delay = self:GetEffectDelay()
	local speed = distance / delay

	ProjectileManager:CreateLinearProjectile({
		Ability = self,
		EffectName = PARTICLE_PROJECTILE,
		vSpawnOrigin = origin,
		fDistance = distance,
		fStartRadius = 8,
		fEndRadius = 8,
		Source = caster,
		bHasFrontalCone = false,
		bReplaceExisting = false,
		iUnitTargetTeam = DOTA_UNIT_TARGET_TEAM_NONE,
		iUnitTargetFlags = DOTA_UNIT_TARGET_FLAG_NONE,
		iUnitTargetType = DOTA_UNIT_TARGET_NONE,
		fExpireTime = GameRules:GetGameTime() + delay + 0.25,
		bDeleteOnHit = false,
		vVelocity = direction * speed,
		bProvidesVision = false,
	})
end

function largo_frogstomp_trinity:StartStomps(caster, point)
	local ticks = self:GetTickCount()
	local interval = self:GetTickInterval()
	local radius = self:GetRadius()

	local fx = ParticleManager:CreateParticle(PARTICLE_FROGSTOMP, PATTACH_WORLDORIGIN, nil)
	ParticleManager:SetParticleControl(fx, 0, point)
	ParticleManager:SetParticleControl(fx, 1, Vector(radius, 0, interval))
	ParticleManager:SetParticleControl(fx, 8, Vector(3, 0, 0))
	ParticleManager:SetParticleControl(fx, 10, caster:GetAbsOrigin())

	local function StopFx()
		if not fx then
			return
		end
		ParticleManager:DestroyParticle(fx, false)
		ParticleManager:ReleaseParticleIndex(fx)
		fx = nil
	end

	local function DoStomp(isLast)
		if IsValid(caster) and not self:IsNull() then
			self:StompPoint(caster, point)
		end
		if isLast then
			StopFx()
		end
	end

	for i = 0, ticks - 1 do
		local wait = i * interval
		local isLast = i == ticks - 1
		if wait <= 0 then
			DoStomp(isLast)
		else
			Timers:CreateTimer(wait, function()
				DoStomp(isLast)
				return nil
			end)
		end
	end
end

function largo_frogstomp_trinity:OnSpellStart()
	if not IsServer() then
		return
	end

	local caster = self:GetCaster()
	local point = self:GetCursorPosition()
	if not IsValid(caster) then
		return
	end

	point = GetGroundPosition(point, caster)
	caster:EmitSound("Hero_Largo.Frogstomp.Cast")
	self:ThrowFroglings(caster, point)

	local delay = self:GetEffectDelay()
	Timers:CreateTimer(delay, function()
		if self:IsNull() or not IsValid(caster) then
			return nil
		end
		self:StartStomps(caster, point)
		return nil
	end)
end

function largo_frogstomp_trinity:StompPoint(caster, point)
	local radius = self:GetRadius()
	local damage = self:GetStompDamage()
	local stun = self:GetSpecialValueFor("stun_duration")
	local slowDuration = self:GetTickInterval() + self:GetSpecialValueFor("aura_linger")

	EmitSoundOnLocationWithCaster(point, "Hero_Largo.Frogstomp.Stomp", caster)

	local enemies = FindUnitsInRadius(
		caster:GetTeamNumber(),
		point,
		nil,
		radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)

	for _, enemy in ipairs(enemies) do
		if IsValid(enemy) and enemy:IsAlive() then
			ApplyDamage({
				attacker = caster,
				victim = enemy,
				damage = damage,
				damage_type = DAMAGE_TYPE_MAGICAL,
				ability = self,
			})
			enemy:AddNewModifier(caster, self, "modifier_stunned", { duration = stun })
			enemy:AddNewModifier(caster, self, "modifier_largo_frogstomp_debuff", { duration = slowDuration })
		end
	end
end

modifier_largo_frogstomp_debuff = class({})

function modifier_largo_frogstomp_debuff:IsHidden()
	return false
end

function modifier_largo_frogstomp_debuff:IsDebuff()
	return true
end

function modifier_largo_frogstomp_debuff:IsPurgable()
	return true
end

function modifier_largo_frogstomp_debuff:OnCreated()
	local ability = self:GetAbility()
	self.slow = ability and ability:GetSpecialValueFor("slow") or 0
end

function modifier_largo_frogstomp_debuff:OnRefresh()
	self:OnCreated()
end

function modifier_largo_frogstomp_debuff:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
	}
end

function modifier_largo_frogstomp_debuff:GetModifierMoveSpeedBonus_Percentage()
	return -self.slow
end

function modifier_largo_frogstomp_debuff:GetTexture()
	return "largo_frogstomp"
end
