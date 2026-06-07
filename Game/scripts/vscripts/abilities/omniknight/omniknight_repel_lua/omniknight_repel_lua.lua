omniknight_repel_lua = class({})
LinkLuaModifier( "modifier_omniknight_repel_lua", "abilities/omniknight/omniknight_repel_lua/modifier_omniknight_repel_lua.lua", LUA_MODIFIER_MOTION_NONE )

local function ApplyRepelToAlly(ally, caster, ability, healAmount, buffDuration)
	if not ally or ally:IsNull() then
		return
	end

	ally:Purge(false, true, false, true, true)
	ally:Heal(healAmount, ability)
	ally:AddNewModifier(
		caster,
		ability,
		"modifier_omniknight_repel_lua",
		{ duration = buffDuration }
	)
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

	local target = self:GetCursorTarget()
	if not target then
		return
	end

	ApplyRepelToAlly(target, caster, self, totalHealAmount, buffDuration)

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
		self:GetCaster():GetOrigin(),
		true
	)
	ParticleManager:ReleaseParticleIndex( effect_cast )
end
