-- Отладка pathway-ивентов: ускорение боссов каравана, Мортимера и Primal Beast.
-- Вешается спавнером, только когда в roshan_spawner_unit.lua включён DEBUG_FAST_EVENTS.

modifier_pathway_debug_speed = class({})

local SPEED_MULTIPLIER = 10

function modifier_pathway_debug_speed:IsHidden()
    return true
end

function modifier_pathway_debug_speed:IsPurgable()
    return false
end

function modifier_pathway_debug_speed:RemoveOnDeath()
    return true
end

function modifier_pathway_debug_speed:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
        MODIFIER_PROPERTY_IGNORE_MOVESPEED_LIMIT,
    }
end

function modifier_pathway_debug_speed:GetModifierMoveSpeedBonus_Percentage()
    return (SPEED_MULTIPLIER - 1) * 100
end

function modifier_pathway_debug_speed:GetModifierIgnoreMovespeedLimit()
    return 1
end
