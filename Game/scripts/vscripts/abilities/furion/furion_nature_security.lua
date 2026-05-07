LinkLuaModifier("modifier_furion_nature_security_passive", "abilities/furion/furion_nature_security", LUA_MODIFIER_MOTION_NONE)

furion_nature_security                  = class({})
modifier_furion_nature_security_passive = class({})

--------------------------------------------------------------------------------
-- Passive ult
--------------------------------------------------------------------------------
function furion_nature_security:GetIntrinsicModifierName()
    return "modifier_furion_nature_security_passive"
end

--------------------------------------------------------------------------------
-- Рисует кровавую дорожку от sourcePos до Фуриона
-- Видна в тумане войны через AddFOWViewer
--------------------------------------------------------------------------------
-- Два варианта частиц: bloodstain как удар + persistent маркер на земле
local BLOOD_HIT    = "particles/units/heroes/hero_phantom_assassin_persona/pa_persona_crit_impact_bloodstain.vpcf"
local BLOOD_MARKER = "particles/units/heroes/hero_phantom_assassin/pa_blood_marker.vpcf"
local STEP_DIST      = 120   -- расстояние между пятнами
local TRAIL_DURATION = 1.5   -- время жизни дорожки

local function DrawBloodTrail(caster, sourcePos)
    if not caster or caster:IsNull() then return end

    local furionPos = caster:GetAbsOrigin()
    local delta     = furionPos - sourcePos
    local dist      = delta:Length2D()
    if dist < 1 then return end

    local steps   = math.max(1, math.floor(dist / STEP_DIST))
    local stepVec = delta / steps

    -- Держим все индексы — освобождаем только ПОСЛЕ DestroyParticle
    local heldParticles = {}

    for i = 0, steps do
        local pos = sourcePos + stepVec * i
        local groundPos = Vector(pos.x, pos.y, GetGroundHeight(pos, nil) + 2)

        -- === Вспышка крови (одноразовая, запускается и сама гаснет) ===
        local fxHit = ParticleManager:CreateParticle(
            BLOOD_HIT,
            PATTACH_WORLDORIGIN,
            nil
        )
        ParticleManager:SetParticleControl(fxHit, 0, groundPos)
        ParticleManager:SetParticleControl(fxHit, 1, delta:Normalized())
        -- Одноразовые частицы можно сразу освободить — они доиграют до конца
        ParticleManager:ReleaseParticleIndex(fxHit)

        -- === Persistent маркер (держится TRAIL_DURATION секунд) ===
        local fxMark = ParticleManager:CreateParticle(
            BLOOD_HIT,
            PATTACH_WORLDORIGIN,
            nil
        )
        ParticleManager:SetParticleControl(fxMark, 0, groundPos)
        ParticleManager:SetParticleControl(fxMark, 1, delta:Normalized() * 30)
        -- НЕ вызываем ReleaseParticleIndex — держим индекс живым
        table.insert(heldParticles, fxMark)

        -- FOW vision у каждого пятна
        AddFOWViewer(caster:GetTeamNumber(), groundPos, 150, TRAIL_DURATION + 0.2, false)
    end

    EmitSoundOnLocationWithCaster(sourcePos, "Hero_Furion.WrathOfNature_Arc", caster)

    -- Уничтожаем все маркеры через TRAIL_DURATION
    Timers:CreateTimer(TRAIL_DURATION, function()
        for _, fx in ipairs(heldParticles) do
            ParticleManager:DestroyParticle(fx, false)
            ParticleManager:ReleaseParticleIndex(fx)
        end
    end)
end


--------------------------------------------------------------------------------
-- Passive modifier
--------------------------------------------------------------------------------
function modifier_furion_nature_security_passive:IsHidden()    return true  end
function modifier_furion_nature_security_passive:IsDebuff()    return false end
function modifier_furion_nature_security_passive:IsPurgable()  return false end
function modifier_furion_nature_security_passive:RemoveOnDeath() return false end

function modifier_furion_nature_security_passive:DeclareFunctions()
    return { MODIFIER_EVENT_ON_TAKEDAMAGE }
end

-- Ловим убийство нейтрального крипа
function modifier_furion_nature_security_passive:OnTakeDamage(params)
    if not IsServer() then return end

    local caster  = self:GetParent()
    local ability = self:GetAbility()
    if not ability or ability:IsNull() or ability:GetLevel() == 0 then return end

    local victim   = params.unit
    local attacker = params.attacker
    if not victim or victim:IsNull() then return end
    if not attacker or attacker:IsNull() then return end

    -- Только вражеский герой, убивающий нейтрального крипа
    if attacker:GetTeamNumber() == caster:GetTeamNumber() then return end
    if not attacker:IsRealHero() then return end
    if not (victim:IsCreep() and not victim:IsHero() and victim:GetTeamNumber() == DOTA_TEAM_NEUTRALS) then return end

    -- Это смертельный удар?
    if params.damage < victim:GetHealth() then return end

    local detectionRadius = ability:GetSpecialValueFor("detection_radius")
    if (victim:GetAbsOrigin() - caster:GetAbsOrigin()):Length2D() <= detectionRadius then
        DrawBloodTrail(caster, victim:GetAbsOrigin())
    end
end

-- Think-цикл: обнаружение срубленных деревьев
function modifier_furion_nature_security_passive:OnCreated()
    if not IsServer() then return end
    self._knownTrees = {}
    self:StartIntervalThink(0.5)
end

function modifier_furion_nature_security_passive:OnIntervalThink()
    if not IsServer() then return end

    local caster  = self:GetParent()
    local ability = self:GetAbility()
    if not ability or ability:IsNull() or ability:GetLevel() == 0 then return end
    if not caster or caster:IsNull() or not caster:IsAlive() then return end

    local detectionRadius = ability:GetSpecialValueFor("detection_radius")
    local now = GameRules:GetGameTime()

    local ok, trees = pcall(function()
        return GridNav:GetAllTreesAround(caster:GetAbsOrigin(), detectionRadius, false)
    end)
    if not ok or not trees then return end

    for _, tree in pairs(trees) do
        if not tree then goto continue end
        local id = tree:entindex()

        if tree:IsStanding() then
            self._knownTrees[id] = now
        else
            local lastSeen = self._knownTrees[id]
            if lastSeen and (now - lastSeen) < 1.0 then
                DrawBloodTrail(caster, tree:GetOrigin())
                self._knownTrees[id] = nil
            end
        end
        ::continue::
    end
end
