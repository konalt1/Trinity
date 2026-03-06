omniknight_repel_lua = class({})
LinkLuaModifier( "modifier_omniknight_repel_lua", "abilities/omniknight/omniknight_repel_lua/modifier_omniknight_repel_lua.lua", LUA_MODIFIER_MOTION_NONE )

local AOE_TALENT_NAME = "special_bonus_unique_custom_omniknight_4"
local AOE_RADIUS = 300

local function HasAoETalent(caster)
	if not caster then
		return false
	end

	if caster.HasTalent and caster.FindTalentValue then
		return caster:HasTalent(AOE_TALENT_NAME)
	end

	local talent = caster:FindAbilityByName(AOE_TALENT_NAME)
	return talent ~= nil and talent:GetLevel() > 0
end

function omniknight_repel_lua:GetBehavior()
	if HasAoETalent(self:GetCaster()) then
		return DOTA_ABILITY_BEHAVIOR_POINT + DOTA_ABILITY_BEHAVIOR_AOE
	end

	return DOTA_ABILITY_BEHAVIOR_UNIT_TARGET
end

function omniknight_repel_lua:GetAOERadius()
	if HasAoETalent(self:GetCaster()) then
		return AOE_RADIUS
	end

	return 0
end

--------------------------------------------------------------------------------
-- Ability Start
function omniknight_repel_lua:OnSpellStart()
	local caster = self:GetCaster()

	local buffDuration = self:GetSpecialValueFor("duration")
	local baseHealAmount = self:GetSpecialValueFor("heal_amount")
	local mindPowerMultiplier = self:GetSpecialValueFor("mind_power_multiplier")
	
	local mindPower = 0
	if GetHeroMindPower then
		mindPower = GetHeroMindPower(caster) or 0
	end
	local mindPowerBonus = mindPower * mindPowerMultiplier
	local totalHealAmount = baseHealAmount + mindPowerBonus

	if HasAoETalent(caster) then
		local point = self:GetCursorPosition()
		local allies = FindUnitsInRadius(
			caster:GetTeamNumber(),
			point,
			nil,
			AOE_RADIUS,
			DOTA_UNIT_TARGET_TEAM_FRIENDLY,
			DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
			DOTA_UNIT_TARGET_FLAG_NONE,
			FIND_ANY_ORDER,
			false
		)

		for _, ally in pairs(allies) do
			ally:Heal(totalHealAmount, self)
			ally:AddNewModifier(
				caster,
				self,
				"modifier_omniknight_repel_lua",
				{ duration = buffDuration }
			)
		end

		self:PlayEffects()
		return
	end

	local target = self:GetCursorTarget()
	if not target then
		return
	end

	target:Heal(totalHealAmount, self)

	target:AddNewModifier(
		caster, -- player source
		self, -- ability source
		"modifier_omniknight_repel_lua", -- modifier name
		{ duration = buffDuration } -- kv
	)

	self:PlayEffects()
end

function omniknight_repel_lua:PlayEffects()
	local particle_cast = "particles/units/heroes/hero_omniknight/omniknight_repel_cast.vpcf"
	local effect_cast = ParticleManager:CreateParticle( particle_cast, PATTACH_ABSORIGIN_FOLLOW, self:GetCaster() )
	ParticleManager:SetParticleControlEnt(
		effect_cast,
		0,
		self:GetCaster(),
		PATTACH_POINT_FOLLOW,
		"attach_attack2",
		self:GetCaster():GetOrigin(), -- unknown
		true -- unknown, true
	)
	ParticleManager:ReleaseParticleIndex( effect_cast )
end