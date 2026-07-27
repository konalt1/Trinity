MortimerBoss = MortimerBoss or {}

local BOSS_NAME = "npc_mortimer_boss"
local FINALE_NAME = "npc_mortimer_boss_finale"
local CELEBRATION_DURATION = 2.5
local FINALE_DURATION = 10.0
local TARGET_RADIUS = 3000

local function IsAlive(unit)
    return unit and IsValidEntity(unit) and unit:IsAlive()
end

local function FindFinaleTarget(finale)
    local enemies = FindUnitsInRadius(
        finale:GetTeamNumber(),
        finale:GetAbsOrigin(),
        nil,
        TARGET_RADIUS,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE + DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
        FIND_CLOSEST,
        false
    )

    for _, enemy in ipairs(enemies) do
        if IsAlive(enemy) then
            return enemy
        end
    end

    return nil
end

local function GetKissesTargetPosition(finale, target)
    local origin = finale:GetAbsOrigin()
    local targetPosition = target:GetAbsOrigin()
    local offset = targetPosition - origin
    offset.z = 0

    -- Mortimer Kisses has a minimum range. Preserve the enemy's direction when
    -- it is standing too close so the stock ability can still begin its volley.
    if offset:Length2D() < 700 then
        local direction = offset:Length2D() > 0 and offset:Normalized() or finale:GetForwardVector()
        targetPosition = origin + direction * 700
    end

    return targetPosition
end

function MortimerBoss:StartFinale(killedBoss)
    local position = killedBoss:GetAbsOrigin()
    -- Replace the corpse with the animated finale actor so two Mortimers do not
    -- overlap while the normal death animation is still visible.
    killedBoss:AddNoDraw()
    local finale = CreateUnitByName(
        FINALE_NAME,
        position,
        true,
        nil,
        nil,
        killedBoss:GetTeamNumber()
    )

    if not finale then
        print("[MortimerBoss] Failed to create the finale unit")
        return
    end

    finale:SetForwardVector(killedBoss:GetForwardVector())
    finale:AddNewModifier(finale, nil, "modifier_invulnerable", {})
    finale:AddNewModifier(finale, nil, "modifier_phased", {})
    finale:StartGesture(ACT_DOTA_TAUNT)

    Timers:CreateTimer(CELEBRATION_DURATION, function()
        if not IsAlive(finale) then
            return nil
        end

        finale:FadeGesture(ACT_DOTA_TAUNT)
        local kisses = finale:FindAbilityByName("snapfire_mortimer_kisses")
        local target = FindFinaleTarget(finale)

        if kisses and target then
            kisses:SetLevel(math.max(1, kisses:GetMaxLevel()))
            kisses:SetActivated(true)
            finale:SetMana(finale:GetMaxMana())
            local targetPosition = GetKissesTargetPosition(finale, target)
            finale:SetForwardVector((targetPosition - finale:GetAbsOrigin()):Normalized())
            finale:CastAbilityOnPosition(targetPosition, kisses, -1)
        end

        return nil
    end)

    Timers:CreateTimer(FINALE_DURATION, function()
        if finale and IsValidEntity(finale) then
            UTIL_Remove(finale)
        end
        return nil
    end)
end

function MortimerBoss:OnEntityKilled(unit)
    if unit and unit:GetUnitName() == BOSS_NAME then
        self:StartFinale(unit)
    end
end

function MortimerBoss:Init()
    Convars:RegisterCommand("spawn_mortimer_boss", function(_, x, y, z)
        local position
        if x and y and z then
            position = Vector(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 128)
        else
            local hero = PlayerResource:GetSelectedHeroEntity(0)
            if hero then
                position = hero:GetAbsOrigin() + hero:GetForwardVector() * 350
            else
                position = Vector(0, 0, 128)
            end
        end

        CreateUnitByName(BOSS_NAME, position, true, nil, nil, DOTA_TEAM_NEUTRALS)
    end, "Spawn Mortimer boss: spawn_mortimer_boss [x y z]", FCVAR_CHEAT)
end
