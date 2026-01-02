juggernaut_blade_fury_lua = class({})
LinkLuaModifier( "modifier_juggernaut_blade_fury_lua", "abilities/juggernaut/juggernaut_blade_fury_lua/modifier_juggernaut_blade_fury_lua", LUA_MODIFIER_MOTION_NONE )

--------------------------------------------------------------------------------
-- Ability Start
function juggernaut_blade_fury_lua:OnSpellStart()
	-- unit identifier
	local caster = self:GetCaster()

	-- load data
	local bDuration = self:GetSpecialValueFor("duration")

	-- Play cast animation
	caster:StartGesture(ACT_DOTA_OVERRIDE_ABILITY_1)

	-- Add modifier
	caster:AddNewModifier(
		caster, -- player source
		self, -- ability source
		"modifier_juggernaut_blade_fury_lua", -- modifier name
		{ duration = bDuration } -- kv
	)
end