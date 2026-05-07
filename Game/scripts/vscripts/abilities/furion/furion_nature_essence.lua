furion_nature_essence = class({})

--------------------------------------------------------------------------------
-- Nature Essence (Aghanim's Scepter granted ability)
-- Fires an energy orb that bounces between trees accumulating damage,
-- then hits enemy heroes dealing all accumulated damage.
--------------------------------------------------------------------------------
function furion_nature_essence:OnSpellStart()
    if not IsServer() then return end

    local caster    = self:GetCaster()
    local targetPos = self:GetCursorPosition()
    local ability   = self

    local bounceRadius    = ability:GetSpecialValueFor("bounce_radius")
    local damagePerBounce = ability:GetSpecialValueFor("damage_per_bounce")
    local maxBounces      = ability:GetSpecialValueFor("max_bounces")
    local projectileSpeed = ability:GetSpecialValueFor("projectile_speed")
    local damageRadius    = ability:GetSpecialValueFor("damage_radius")
    local maxTargets      = ability:GetSpecialValueFor("max_targets")

    -- Gather trees near targetPos for bounce path
    local trees = GridNav:GetAllTreesAround(targetPos, bounceRadius * maxBounces, true)

    -- Build bounce chain: pick closest trees greedily
    local bounceChain = {}
    local visited     = {}
    local currentPos  = targetPos

    for _ = 1, maxBounces do
        local bestTree = nil
        local bestDist = bounceRadius

        for _, tree in pairs(trees) do
            if tree and tree:IsStanding() and not visited[tree:entindex()] then
                local d = (tree:GetOrigin() - currentPos):Length2D()
                if d <= bounceRadius and d < bestDist then
                    bestDist = d
                    bestTree = tree
                end
            end
        end

        if not bestTree then break end

        visited[bestTree:entindex()] = true
        table.insert(bounceChain, bestTree:GetOrigin())
        currentPos = bestTree:GetOrigin()
    end

    -- The orb fires from caster, goes through tree chain, then hits enemies
    local accumulatedDamage = damagePerBounce * math.max(1, #bounceChain)

    -- Animate the orb along the chain then detonate
    local function FireOrb(startPos, chainIndex, totalDamage)
        if chainIndex > #bounceChain then
            -- Detonate: hit all enemy heroes near currentPos
            local enemies = FindUnitsInRadius(
                caster:GetTeamNumber(), currentPos, nil, damageRadius,
                DOTA_UNIT_TARGET_TEAM_ENEMY,
                DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
                DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false
            )
            local hitCount = 0
            for _, enemy in pairs(enemies) do
                if enemy and not enemy:IsNull() and enemy:IsAlive() then
                    if hitCount < maxTargets then
                        ApplyDamage({
                            victim      = enemy,
                            attacker    = caster,
                            damage      = totalDamage,
                            damage_type = DAMAGE_TYPE_MAGICAL,
                            ability     = ability,
                        })
                        hitCount = hitCount + 1

                        local fxHit = ParticleManager:CreateParticle(
                            "particles/units/heroes/hero_furion/furion_wrath_of_nature_explosion.vpcf",
                            PATTACH_ABSORIGIN_FOLLOW, enemy)
                        ParticleManager:ReleaseParticleIndex(fxHit)
                        EmitSoundOn("Hero_Furion.WrathOfNature_Impact", enemy)
                    end
                end
            end
            return
        end

        local nextPos = bounceChain[chainIndex]
        local travelDist = (nextPos - startPos):Length2D()
        local travelTime = travelDist / projectileSpeed

        -- Create particle for the orb segment
        local fxOrb = ParticleManager:CreateParticle(
            "particles/units/heroes/hero_furion/furion_wrath_of_nature_projectile.vpcf",
            PATTACH_CUSTOMORIGIN, nil)
        ParticleManager:SetParticleControl(fxOrb, 0, startPos)
        ParticleManager:SetParticleControl(fxOrb, 1, nextPos)
        ParticleManager:ReleaseParticleIndex(fxOrb)

        -- Schedule next bounce
        Timers:CreateTimer(travelTime, function()
            currentPos = nextPos

            -- Tree hit burst
            local fxBounce = ParticleManager:CreateParticle(
                "particles/units/heroes/hero_furion/furion_sprout.vpcf",
                PATTACH_CUSTOMORIGIN, nil)
            ParticleManager:SetParticleControl(fxBounce, 0, nextPos)
            ParticleManager:ReleaseParticleIndex(fxBounce)
            EmitSoundOnLocationWithCaster(nextPos, "Hero_Furion.Sprout", caster)

            FireOrb(nextPos, chainIndex + 1, totalDamage)
        end)
    end

    -- Launch from caster toward first tree (or targetPos if no chain)
    local launchPos = caster:GetAbsOrigin()
    if #bounceChain == 0 then
        -- No trees found: fire directly to target area
        table.insert(bounceChain, targetPos)
    end

    local fxLaunch = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_furion/furion_wrath_of_nature_projectile.vpcf",
        PATTACH_CUSTOMORIGIN, nil)
    ParticleManager:SetParticleControl(fxLaunch, 0, launchPos)
    ParticleManager:SetParticleControl(fxLaunch, 1, bounceChain[1])
    ParticleManager:ReleaseParticleIndex(fxLaunch)
    EmitSoundOn("Hero_Furion.WrathOfNature", caster)

    local firstDist = (bounceChain[1] - launchPos):Length2D()
    local firstTime = firstDist / projectileSpeed
    currentPos = bounceChain[1]

    Timers:CreateTimer(firstTime, function()
        FireOrb(bounceChain[1], 2, accumulatedDamage)
    end)
end
