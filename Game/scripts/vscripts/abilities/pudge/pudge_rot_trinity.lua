pudge_rot_trinity = class({})

LinkLuaModifier("modifier_pudge_rot_trinity", "abilities/pudge/pudge_rot_trinity", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_pudge_rot_trinity_debuff", "abilities/pudge/pudge_rot_trinity", LUA_MODIFIER_MOTION_NONE)

local function GetPudgeMindPower(caster)
	if not caster or caster:IsNull() then
		return 0
	end

	-- FindModifierByName is not available for this client-side ability query.
	-- Gameplay calculations always run on the server and use full Mind Power.
	if not IsServer() then
		return caster:GetIntellect(false) or 0
	end

	if GetHeroMindPower then
		return GetHeroMindPower(caster) or 0
	end

	return caster:GetIntellect(false) or 0
end

local function GetPudgeBonusAoE(caster)
	if not caster or caster:IsNull() then
		return 0
	end

	if not IsServer() then
		return 0
	end

	if GetHeroBonusSpellAoE then
		return GetHeroBonusSpellAoE(caster) or 0
	end

	local total = 0
	for slot = 0, 8 do
		local item = caster:GetItemInSlot(slot)
		if item and not item:IsNull() then
			total = total + math.max(0, item:GetSpecialValueFor("bonus_aoe") or 0)
			total = total + math.max(0, item:GetSpecialValueFor("aoe_bonus") or 0)
		end
	end

	return total
end

function pudge_rot_trinity:GetDamagePerSecond()
	local base_damage = self:GetSpecialValueFor("rot_damage")
	local multiplier = self:GetSpecialValueFor("mind_power_damage_multiplier")
	return math.max(0, base_damage + GetPudgeMindPower(self:GetCaster()) * multiplier)
end

function pudge_rot_trinity:GetAOERadius()
	local caster = self:GetCaster()
	local base_radius = self:GetSpecialValueFor("rot_radius")
	local multiplier = self:GetSpecialValueFor("mind_power_radius_multiplier")
	return math.max(0, base_radius + GetPudgeMindPower(caster) * multiplier + GetPudgeBonusAoE(caster))
end

function pudge_rot_trinity:OnToggle()
	if not IsServer() then return end

	local caster = self:GetCaster()
	if self:GetToggleState() then
		caster:AddNewModifier(caster, self, "modifier_pudge_rot_trinity", {})
	else
		caster:RemoveModifierByName("modifier_pudge_rot_trinity")
	end
end

function pudge_rot_trinity:OnOwnerDied()
	if not IsServer() then return end

	if self:GetToggleState() then
		self:ToggleAbility()
	end
end

modifier_pudge_rot_trinity = class({})

function modifier_pudge_rot_trinity:CreateRotParticle(radius)
	if self.particle then
		ParticleManager:DestroyParticle(self.particle, false)
		ParticleManager:ReleaseParticleIndex(self.particle)
	end

	self.particle = ParticleManager:CreateParticle(
		"particles/units/heroes/hero_pudge/pudge_rot.vpcf",
		PATTACH_ABSORIGIN_FOLLOW,
		self:GetParent()
	)
	ParticleManager:SetParticleControl(self.particle, 1, Vector(radius, 0, 0))
	self.particle_radius = radius
end

function modifier_pudge_rot_trinity:IsHidden() return true end
function modifier_pudge_rot_trinity:IsPurgable() return false end
function modifier_pudge_rot_trinity:IsAura() return true end
function modifier_pudge_rot_trinity:GetModifierAura() return "modifier_pudge_rot_trinity_debuff" end
function modifier_pudge_rot_trinity:GetAuraSearchTeam() return DOTA_UNIT_TARGET_TEAM_ENEMY end
function modifier_pudge_rot_trinity:GetAuraSearchType() return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC end
function modifier_pudge_rot_trinity:GetAuraSearchFlags() return DOTA_UNIT_TARGET_FLAG_NONE end
function modifier_pudge_rot_trinity:GetAuraDuration() return 0.3 end

function modifier_pudge_rot_trinity:GetAuraRadius()
	local ability = self:GetAbility()
	return ability and ability:GetAOERadius() or 0
end

function modifier_pudge_rot_trinity:OnCreated()
	if not IsServer() then return end

	local ability = self:GetAbility()
	if not ability then
		self:Destroy()
		return
	end

	self.tick = math.max(0.03, ability:GetSpecialValueFor("rot_tick"))
	self:CreateRotParticle(ability:GetAOERadius())

	EmitSoundOn("Hero_Pudge.Rot", self:GetParent())
	self:StartIntervalThink(self.tick)
end

function modifier_pudge_rot_trinity:OnIntervalThink()
	if not IsServer() then return end

	local ability = self:GetAbility()
	local parent = self:GetParent()
	if not ability or ability:IsNull() or not parent:IsAlive() then
		self:Destroy()
		return
	end

	local radius = ability:GetAOERadius()
	if math.abs(radius - (self.particle_radius or 0)) > 0.01 then
		-- Rot has instantaneous child particles which only read CP1 on creation.
		-- Recreate it when the aura grows so every visual layer uses the real radius.
		self:CreateRotParticle(radius)
	else
		ParticleManager:SetParticleControl(self.particle, 1, Vector(radius, 0, 0))
	end
	ApplyDamage({
		victim = parent,
		attacker = parent,
		damage = ability:GetDamagePerSecond() * self.tick,
		damage_type = DAMAGE_TYPE_MAGICAL,
		damage_flags = DOTA_DAMAGE_FLAG_NO_SPELL_AMPLIFICATION,
		ability = ability,
	})
end

function modifier_pudge_rot_trinity:OnDestroy()
	if not IsServer() then return end
	if self.particle then
		ParticleManager:DestroyParticle(self.particle, false)
		ParticleManager:ReleaseParticleIndex(self.particle)
		self.particle = nil
	end
	StopSoundOn("Hero_Pudge.Rot", self:GetParent())
end

modifier_pudge_rot_trinity_debuff = class({})

function modifier_pudge_rot_trinity_debuff:IsHidden() return false end
function modifier_pudge_rot_trinity_debuff:IsDebuff() return true end
function modifier_pudge_rot_trinity_debuff:IsPurgable() return false end

function modifier_pudge_rot_trinity_debuff:OnCreated()
	local ability = self:GetAbility()
	self.slow = ability and ability:GetSpecialValueFor("rot_slow") or 0

	if IsServer() and ability then
		self.tick = math.max(0.03, ability:GetSpecialValueFor("rot_tick"))
		self:StartIntervalThink(self.tick)
	end
end

function modifier_pudge_rot_trinity_debuff:OnRefresh()
	local ability = self:GetAbility()
	self.slow = ability and ability:GetSpecialValueFor("rot_slow") or self.slow
end

function modifier_pudge_rot_trinity_debuff:OnIntervalThink()
	if not IsServer() then return end

	local ability = self:GetAbility()
	local caster = self:GetCaster()
	if not ability or ability:IsNull() or not caster or caster:IsNull() then
		self:Destroy()
		return
	end

	ApplyDamage({
		victim = self:GetParent(),
		attacker = caster,
		damage = ability:GetDamagePerSecond() * self.tick,
		damage_type = DAMAGE_TYPE_MAGICAL,
		ability = ability,
	})
end

function modifier_pudge_rot_trinity_debuff:DeclareFunctions()
	return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE }
end

function modifier_pudge_rot_trinity_debuff:GetModifierMoveSpeedBonus_Percentage()
	return self.slow or 0
end

function modifier_pudge_rot_trinity_debuff:GetEffectName()
	return "particles/units/heroes/hero_pudge/pudge_rot_recipient.vpcf"
end

function modifier_pudge_rot_trinity_debuff:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end
