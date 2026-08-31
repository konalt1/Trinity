LinkLuaModifier("modifier_largo_catchy_lick_buff", "abilities/largo/largo_catchy_lick", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_largo_catchy_lick_pull", "abilities/largo/largo_catchy_lick", LUA_MODIFIER_MOTION_NONE)

largo_catchy_lick_trinity = class({})

local PARTICLE_LICK = "particles/units/heroes/hero_largo/largo_catchy_lick.vpcf"
local PULL_DURATION = 0.3

local function IsValid(unit)
	return unit and not unit:IsNull() and IsValidEntity(unit)
end

local function IsRuneEntity(entity)
	if not IsValid(entity) then
		return false
	end

	if entity.GetRuneType then
		return true
	end

	local className = entity.GetClassname and entity:GetClassname() or ""
	return className == "dota_item_rune"
end

local MOUTH_ATTACHMENTS = {
	"attach_mouth",
	"attach_tongue",
	"attach_jaw",
	"attach_head",
	"attach_hitloc",
}

local function GetAttachName(unit, names)
	if not IsValid(unit) or not unit.ScriptLookupAttachment then
		return names and names[1] or "attach_hitloc"
	end

	for _, name in ipairs(names) do
		local id = unit:ScriptLookupAttachment(name)
		if id and id > 0 then
			return name
		end
	end

	return "attach_hitloc"
end

local function ModifierCount(unit)
	if not IsValid(unit) or not unit.FindAllModifiers then
		return 0
	end

	local modifiers = unit:FindAllModifiers()
	if not modifiers then
		return 0
	end

	local count = 0
	for _, modifier in pairs(modifiers) do
		if modifier ~= nil then
			count = count + 1
		end
	end
	return count
end

function largo_catchy_lick_trinity:Precache(context)
	PrecacheResource("particle", PARTICLE_LICK, context)
	PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_largo.vsndevts", context)
end

function largo_catchy_lick_trinity:GetDamage()
	local caster = self:GetCaster()
	local mindPower = 0
	if caster and GetHeroMindPower then
		mindPower = GetHeroMindPower(caster) or 0
	end

	return math.max(0,
		self:GetSpecialValueFor("damage")
		+ mindPower * self:GetSpecialValueFor("mind_power_multiplier")
	)
end

function largo_catchy_lick_trinity:CastFilterResultTarget(target)
	if not IsValid(target) then
		return UF_FAIL_CUSTOM
	end

	if IsRuneEntity(target) then
		return UF_SUCCESS
	end

	return self.BaseClass.CastFilterResultTarget(self, target)
end

function largo_catchy_lick_trinity:OnSpellStart()
	if not IsServer() then
		return
	end

	local caster = self:GetCaster()
	local target = self:GetCursorTarget()
	if not IsValid(caster) or not IsValid(target) then
		return
	end

	caster:EmitSound("Hero_Largo.CatchyLick.Cast")

	if IsRuneEntity(target) then
		self:PlayLickEffect(caster, target)
		self:PullRune(caster, target)
		caster:GiveMana(self:GetManaCost(self:GetLevel() - 1))
		return
	end

	if target:TriggerSpellAbsorb(self) then
		return
	end

	local isEnemy = target:GetTeamNumber() ~= caster:GetTeamNumber()
	local removeBuffs = isEnemy
	local removeDebuffs = not isEnemy
	local before = ModifierCount(target)
	target:Purge(removeBuffs, removeDebuffs, false, false, false)
	local hadEffects = ModifierCount(target) < before

	local killed = false
	if isEnemy then
		ApplyDamage({
			attacker = caster,
			victim = target,
			damage = self:GetDamage(),
			damage_type = DAMAGE_TYPE_MAGICAL,
			ability = self,
		})
		killed = not IsValid(target) or not target:IsAlive()
	end

	if hadEffects or killed then
		self:GrantRegen(caster)
	end

	self:PlayLickEffect(caster, target)

	if not killed and target ~= caster then
		local pullDistance = isEnemy
			and self:GetSpecialValueFor("pull_distance")
			or self:GetSpecialValueFor("pull_distance_ally")
		self:PullUnit(caster, target, pullDistance)
	end
end

function largo_catchy_lick_trinity:GrantRegen(caster)
	caster:AddNewModifier(caster, self, "modifier_largo_catchy_lick_buff", {
		duration = self:GetSpecialValueFor("buff_duration"),
	})
end

function largo_catchy_lick_trinity:PlayLickEffect(caster, target)
	local mouth = GetAttachName(caster, MOUTH_ATTACHMENTS)
	local hitloc = GetAttachName(target, { "attach_hitloc", "attach_origin" })
	local fx = ParticleManager:CreateParticle(PARTICLE_LICK, PATTACH_CUSTOMORIGIN, caster)
	ParticleManager:SetParticleControlEnt(
		fx,
		0,
		caster,
		PATTACH_POINT_FOLLOW,
		mouth,
		caster:GetAbsOrigin(),
		true
	)
	ParticleManager:SetParticleControlEnt(
		fx,
		1,
		target,
		PATTACH_POINT_FOLLOW,
		hitloc,
		target:GetAbsOrigin(),
		true
	)
	ParticleManager:ReleaseParticleIndex(fx)
end

function largo_catchy_lick_trinity:PullUnit(caster, target, distance)
	local origin = target:GetAbsOrigin()
	local toCaster = caster:GetAbsOrigin() - origin
	toCaster.z = 0
	local gap = toCaster:Length2D()
	if gap < 1 then
		return
	end

	local pull = math.min(distance, math.max(0, gap - 80))
	if pull < 1 then
		return
	end

	if target.InterruptMotionControllers then
		target:InterruptMotionControllers(true)
	end

	target:AddNewModifier(caster, self, "modifier_largo_catchy_lick_pull", {
		duration = PULL_DURATION,
		distance = pull,
	})
end

function largo_catchy_lick_trinity:PullRune(caster, rune)
	local dest = caster:GetAbsOrigin() + caster:GetForwardVector() * 90
	dest.z = GetGroundHeight(dest, caster)
	if rune.SetAbsOrigin then
		rune:SetAbsOrigin(dest)
	end
end

modifier_largo_catchy_lick_buff = class({})

function modifier_largo_catchy_lick_buff:IsHidden()
	return false
end

function modifier_largo_catchy_lick_buff:IsDebuff()
	return false
end

function modifier_largo_catchy_lick_buff:IsPurgable()
	return true
end

function modifier_largo_catchy_lick_buff:GetAttributes()
	return MODIFIER_ATTRIBUTE_MULTIPLE
end

function modifier_largo_catchy_lick_buff:OnCreated()
	local ability = self:GetAbility()
	self.regen = ability and ability:GetSpecialValueFor("dispel_hp_regen") or 0
end

function modifier_largo_catchy_lick_buff:OnRefresh()
	self:OnCreated()
end

function modifier_largo_catchy_lick_buff:DeclareFunctions()
	return {
		MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
	}
end

function modifier_largo_catchy_lick_buff:GetModifierConstantHealthRegen()
	return self.regen
end

function modifier_largo_catchy_lick_buff:GetTexture()
	return "largo_catchy_lick"
end

modifier_largo_catchy_lick_pull = class({})

function modifier_largo_catchy_lick_pull:IsHidden()
	return true
end

function modifier_largo_catchy_lick_pull:IsPurgable()
	return false
end

function modifier_largo_catchy_lick_pull:OnCreated(kv)
	if not IsServer() then
		return
	end

	kv = kv or {}
	self.distance = tonumber(kv.distance) or 0
	self.traveled = 0
	self.stopRange = 80
	self.speed = self.distance / math.max(self:GetDuration(), 0.03)
	self.lastTime = GameRules:GetGameTime()
	self:StartIntervalThink(FrameTime())
end

function modifier_largo_catchy_lick_pull:OnDestroy()
	if not IsServer() then
		return
	end

	local parent = self:GetParent()
	if IsValid(parent) then
		FindClearSpaceForUnit(parent, GetGroundPosition(parent:GetAbsOrigin(), parent), false)
	end
end

function modifier_largo_catchy_lick_pull:CheckState()
	return {
		[MODIFIER_STATE_ROOTED] = true,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
		[MODIFIER_STATE_FLYING_FOR_PATHING_PURPOSES_ONLY] = true,
		[MODIFIER_STATE_IGNORING_MOVE_AND_ATTACK_ORDERS] = true,
	}
end

function modifier_largo_catchy_lick_pull:OnIntervalThink()
	local parent = self:GetParent()
	local caster = self:GetCaster()
	if not IsValid(parent) or not IsValid(caster) then
		self:Destroy()
		return
	end

	local now = GameRules:GetGameTime()
	local dt = math.max(0, now - (self.lastTime or now))
	self.lastTime = now
	if dt < 0.001 then
		dt = FrameTime()
	end

	local origin = parent:GetAbsOrigin()
	local toCaster = caster:GetAbsOrigin() - origin
	toCaster.z = 0
	local gap = toCaster:Length2D()
	if gap <= self.stopRange then
		self:Destroy()
		return
	end

	local remainingBudget = math.max(0, self.distance - self.traveled)
	local remainingGap = gap - self.stopRange
	local step = math.min(self.speed * dt, remainingBudget, remainingGap)
	if step < 0.1 then
		self:Destroy()
		return
	end

	parent:SetAbsOrigin(GetGroundPosition(origin + toCaster:Normalized() * step, parent))
	self.traveled = self.traveled + step
	if self.traveled >= self.distance then
		self:Destroy()
	end
end
