LinkLuaModifier("modifier_largo_frogstomp_debuff", "abilities/largo/largo_frogstomp", LUA_MODIFIER_MOTION_NONE)

largo_frogstomp_trinity = class({})

local PARTICLE_FROGSTOMP = "particles/units/heroes/hero_largo/largo_frogstomp.vpcf"

local function IsValid(unit)
	return unit and not unit:IsNull() and IsValidEntity(unit)
end

function largo_frogstomp_trinity:Precache(context)
	PrecacheResource("particle", PARTICLE_FROGSTOMP, context)
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
