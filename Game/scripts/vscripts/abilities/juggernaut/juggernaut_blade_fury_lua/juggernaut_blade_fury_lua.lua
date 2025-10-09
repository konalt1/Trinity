juggernaut_blade_fury_lua = class({})
LinkLuaModifier( "modifier_juggernaut_blade_fury_lua", "abilities/juggernaut/juggernaut_blade_fury_lua/modifier_juggernaut_blade_fury_lua", LUA_MODIFIER_MOTION_NONE )

--------------------------------------------------------------------------------
-- Ability Start
function juggernaut_blade_fury_lua:OnSpellStart()
	-- unit identifier
	local caster = self:GetCaster()

	print("=== Blade Fury OnSpellStart Debug ===")
	print("Caster: " .. (caster:GetUnitName() or "Unknown"))
	print("Ability: " .. (self:GetAbilityName() or "Unknown"))

	-- load data
	local bDuration = self:GetSpecialValueFor("duration")
	print("Duration: " .. bDuration)

	-- Play cast animation
	caster:StartGesture(ACT_DOTA_OVERRIDE_ABILITY_1)
	print("Animation started")

	-- Add modifier
	local modifier = caster:AddNewModifier(
		caster, -- player source
		self, -- ability source
		"modifier_juggernaut_blade_fury_lua", -- modifier name
		{ duration = bDuration } -- kv
	)
	
	if modifier then
		print("Modifier successfully added: " .. modifier:GetName())
	else
		print("ERROR: Failed to add modifier!")
	end
	
	print("=== Blade Fury OnSpellStart Complete ===")
end