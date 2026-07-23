silencer_global_silence = class({})

local GLOBAL_SILENCE_COOLDOWN = 100
local GLOBAL_SILENCE_DURATION = 4

function silencer_global_silence:GetCooldown(_level)
    return GLOBAL_SILENCE_COOLDOWN
end

function silencer_global_silence:GetDuration()
    return GLOBAL_SILENCE_DURATION
end
