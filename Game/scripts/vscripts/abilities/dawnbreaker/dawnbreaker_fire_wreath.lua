-- Overlay on vanilla Starbreaker: CastFilter only. Native spell logic stays on BaseClass.

dawnbreaker_fire_wreath = class({})

function dawnbreaker_fire_wreath:IsHammerAway()
	return self:GetCaster():HasModifier("modifier_dawnbreaker_celestial_hammer_custom_nohammer")
end

function dawnbreaker_fire_wreath:CastFilterResult()
	if self:IsHammerAway() then
		return UF_FAIL_CUSTOM
	end
	return UF_SUCCESS
end

function dawnbreaker_fire_wreath:CastFilterResultLocation(location)
	return self:CastFilterResult()
end

function dawnbreaker_fire_wreath:GetCustomCastError()
	if self:IsHammerAway() then
		return "#dota_hud_error_nohammer"
	end
	return ""
end

function dawnbreaker_fire_wreath:GetCustomCastErrorLocation(location)
	return self:GetCustomCastError()
end
