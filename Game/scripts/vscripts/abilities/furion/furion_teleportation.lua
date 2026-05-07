furion_teleportation = class({})

--------------------------------------------------------------------------------
-- BaseClass "furion_teleportation"
-- Channels like native TP, after landing auto-triggers native Shard ability
-- (furion_curse_of_oldgrowth) if the caster has Aghanim's Shard
--------------------------------------------------------------------------------
function furion_teleportation:OnSpellStart()
    if not IsServer() then return end
    local caster = self:GetCaster()

    local fxStart = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_furion/furion_teleport.vpcf",
        PATTACH_ABSORIGIN_FOLLOW, caster)
    ParticleManager:SetParticleControl(fxStart, 0, caster:GetAbsOrigin())
    ParticleManager:ReleaseParticleIndex(fxStart)

    EmitSoundOn("Hero_Furion.Teleportation", caster)
end

function furion_teleportation:OnChannelFinish(bInterrupted)
    if not IsServer() then return end
    if bInterrupted then return end

    local caster    = self:GetCaster()
    local targetPos = self:GetCursorPosition()

    -- Depart effect
    local fxDepart = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_furion/furion_teleport_end.vpcf",
        PATTACH_ABSORIGIN, caster)
    ParticleManager:SetParticleControl(fxDepart, 0, caster:GetAbsOrigin())
    ParticleManager:ReleaseParticleIndex(fxDepart)

    -- Teleport
    FindClearSpaceForUnit(caster, targetPos, true)

    -- Arrival effect
    local fxArrive = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_furion/furion_teleport_end.vpcf",
        PATTACH_ABSORIGIN, caster)
    ParticleManager:SetParticleControl(fxArrive, 0, caster:GetAbsOrigin())
    ParticleManager:ReleaseParticleIndex(fxArrive)
    EmitSoundOn("Hero_Furion.Teleportation_End", caster)

    -- Auto-trigger native Shard: furion_curse_of_oldgrowth (no-target ability)
    local shardAbility = caster:FindAbilityByName("furion_curse_of_oldgrowth")
    if shardAbility and not shardAbility:IsNull() and shardAbility:GetLevel() > 0 then
        ExecuteOrderFromTable({
            UnitIndex    = caster:entindex(),
            OrderType    = DOTA_UNIT_ORDER_CAST_NO_TARGET,
            AbilityIndex = shardAbility:entindex(),
            Queue        = false,
        })
    end
end
