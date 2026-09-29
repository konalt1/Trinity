-- Trinity: Giant's Ring (в ванилле нейтралка). Прямое развитие Havoc Hammer:
-- Havoc Hammer + Ring of Tarrasque + рецепт 300 = 4800.
-- Наследует всё от Havoc Hammer и Ring of Tarrasque:
--   * Статы: +bonus_strength, +bonus_damage (Havoc Hammer), +bonus_health_regen (Ring of Tarrasque).
--   * Активка Havoc Hammer: притягивает врагов в радиусе range, наносит nuke_base_dmg + nuke_str_dmg * сила
--     магического урона и замедляет на slow% на slow_duration сек (с учётом сопротивления эффектам).
--   * Пассив Giant's Ring: герой увеличивается (model_scale), враги рядом получают магический урон
--     pct_str_damage_per_second% силы героя в секунду и постоянно притягиваются к герою со скоростью
--     pull_speed (до дистанции pull_min_distance; древних не двигает). Несколько колец не складывают
--     рост, урон и притяжение.
-- Значения берутся из KV (npc_items_custom.txt, "item_giants_ring").
-- Референс механики: Кастомки/scripts/vscripts/items/item_giants_ring_custom.lua, item_havoc_hammer_custom.lua.

LinkLuaModifier("modifier_item_giants_ring_trinity", "items/item_giants_ring_trinity", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_giants_ring_trinity_slow", "items/item_giants_ring_trinity", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_giants_ring_trinity_pull", "items/item_giants_ring_trinity", LUA_MODIFIER_MOTION_HORIZONTAL)

local TICK = 0.25

item_giants_ring = class({})

function item_giants_ring:Precache(context)
    PrecacheResource("particle", "particles/items5_fx/havoc_hammer.vpcf", context)
end

function item_giants_ring:GetIntrinsicModifierName()
    return "modifier_item_giants_ring_trinity"
end

function item_giants_ring:OnSpellStart()
    if not IsServer() then return end
    local caster = self:GetCaster()
    local origin = caster:GetAbsOrigin()
    local radius = self:GetSpecialValueFor("range")
    local pull_distance = self:GetSpecialValueFor("pull_distance")
    local knockback_duration = self:GetSpecialValueFor("knockback_duration")
    local slow_duration = self:GetSpecialValueFor("slow_duration")
    local damage = self:GetSpecialValueFor("nuke_base_dmg") + self:GetSpecialValueFor("nuke_str_dmg") * caster:GetStrength()

    local particle = ParticleManager:CreateParticle("particles/items5_fx/havoc_hammer.vpcf", PATTACH_ABSORIGIN_FOLLOW, caster)
    ParticleManager:SetParticleControl(particle, 0, origin)
    ParticleManager:SetParticleControl(particle, 1, Vector(radius, radius, radius))
    ParticleManager:ReleaseParticleIndex(particle)
    caster:EmitSound("DOTA_Item.HavocHammer.Cast")

    local units = FindUnitsInRadius(
        caster:GetTeamNumber(), origin, nil, radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false
    )

    for _, unit in pairs(units) do
        -- Притяжение к герою: центр отбрасывания — точка за целью, дальше от героя.
        if pull_distance > 0 and not unit:IsAncient() and not unit:HasModifier("modifier_knockback") then
            local away = unit:GetAbsOrigin() - origin
            away.z = 0
            if away:Length2D() > 1 then
                local center = unit:GetAbsOrigin() + away:Normalized() * pull_distance
                unit:AddNewModifier(caster, self, "modifier_knockback", {
                    center_x = center.x,
                    center_y = center.y,
                    center_z = center.z,
                    duration = knockback_duration,
                    knockback_duration = knockback_duration,
                    knockback_distance = math.min(pull_distance, away:Length2D()),
                    knockback_height = 0,
                    should_stun = 0,
                })
            end
        end

        ApplyDamage({
            victim = unit,
            attacker = caster,
            damage = damage,
            damage_type = DAMAGE_TYPE_MAGICAL,
            ability = self,
        })

        unit:AddNewModifier(caster, self, "modifier_item_giants_ring_trinity_slow", {
            duration = slow_duration * (1 - unit:GetStatusResistance()),
        })
    end
end

--------------------------------------------------------------------------------
-- Пассив: статы, рост, урон по силе вокруг героя
--------------------------------------------------------------------------------

modifier_item_giants_ring_trinity = class({
    IsHidden      = function(self) return true end,
    IsPurgable    = function(self) return false end,
    RemoveOnDeath = function(self) return false end,
    GetAttributes = function(self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
})

function modifier_item_giants_ring_trinity:OnCreated()
    self:ReadValues()
    if not IsServer() then return end
    self:StartIntervalThink(TICK)
end

function modifier_item_giants_ring_trinity:OnRefresh()
    self:ReadValues()
end

function modifier_item_giants_ring_trinity:ReadValues()
    local ability = self:GetAbility()
    if not ability then return end
    self.strength = ability:GetSpecialValueFor("bonus_strength")
    self.damage = ability:GetSpecialValueFor("bonus_damage")
    self.regen = ability:GetSpecialValueFor("bonus_health_regen")
    self.model_scale = ability:GetSpecialValueFor("model_scale")
end

-- Рост и урон работают только от первого кольца в инвентаре.
function modifier_item_giants_ring_trinity:IsPrimary()
    return self:GetParent():FindModifierByName(self:GetName()) == self
end

function modifier_item_giants_ring_trinity:OnIntervalThink()
    if not IsServer() or not self:IsPrimary() then return end
    local parent = self:GetParent()
    local ability = self:GetAbility()
    if not ability or not parent:IsAlive() or parent:IsIllusion() then return end

    local pct = ability:GetSpecialValueFor("pct_str_damage_per_second")
    local radius = ability:GetSpecialValueFor("damage_radius")
    -- Урон за один тик: доля секундного урона.
    local damage = parent:GetStrength() * pct / 100 * TICK

    local enemies = FindUnitsInRadius(
        parent:GetTeamNumber(), parent:GetAbsOrigin(), nil, radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false
    )
    for _, enemy in pairs(enemies) do
        ApplyDamage({
            victim = enemy,
            attacker = parent,
            damage = damage,
            damage_type = DAMAGE_TYPE_MAGICAL,
            ability = ability,
        })
        -- Притяжение: модификатор живёт чуть дольше тика и обновляется, пока враг в радиусе.
        if enemy:IsAlive() and not enemy:IsAncient() and not enemy:IsBuilding() then
            enemy:AddNewModifier(parent, ability, "modifier_item_giants_ring_trinity_pull", {
                duration = TICK * 2,
            })
        end
    end
end

function modifier_item_giants_ring_trinity:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_STATS_STRENGTH_BONUS,
        MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
        MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
        MODIFIER_PROPERTY_MODEL_SCALE,
    }
end

function modifier_item_giants_ring_trinity:GetModifierBonusStats_Strength()
    return self.strength or 0
end

function modifier_item_giants_ring_trinity:GetModifierPreAttack_BonusDamage()
    return self.damage or 0
end

function modifier_item_giants_ring_trinity:GetModifierConstantHealthRegen()
    return self.regen or 0
end

function modifier_item_giants_ring_trinity:GetModifierModelScale()
    if not self:IsPrimary() then return 0 end
    return self.model_scale or 0
end

--------------------------------------------------------------------------------
-- Дебафф активки: замедление
--------------------------------------------------------------------------------

modifier_item_giants_ring_trinity_slow = class({
    IsHidden   = function(self) return false end,
    IsDebuff   = function(self) return true end,
    IsPurgable = function(self) return true end,
    GetTexture = function(self) return "item_giants_ring" end,
})

function modifier_item_giants_ring_trinity_slow:OnCreated()
    local ability = self:GetAbility()
    self.slow = ability and ability:GetSpecialValueFor("slow") or 0
end

function modifier_item_giants_ring_trinity_slow:OnRefresh()
    self:OnCreated()
end

function modifier_item_giants_ring_trinity_slow:DeclareFunctions()
    return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE }
end

function modifier_item_giants_ring_trinity_slow:GetModifierMoveSpeedBonus_Percentage()
    return -(self.slow or 0)
end

--------------------------------------------------------------------------------
-- Притяжение врагов в радиусе пассива к герою (горизонтальный контроллер движения)
--------------------------------------------------------------------------------

modifier_item_giants_ring_trinity_pull = class({
    IsHidden   = function(self) return true end,
    IsDebuff   = function(self) return true end,
    IsPurgable = function(self) return false end,
})

function modifier_item_giants_ring_trinity_pull:OnCreated()
    if not IsServer() then return end
    local ability = self:GetAbility()
    if not ability then self:Destroy() return end
    self.speed = ability:GetSpecialValueFor("pull_speed")
    self.min_distance = ability:GetSpecialValueFor("pull_min_distance")
    -- Если на враге уже работает другой горизонтальный контроллер (отбрасывание, рывок), не вмешиваемся.
    if not self:ApplyHorizontalMotionController() then
        self:Destroy()
    end
end

function modifier_item_giants_ring_trinity_pull:OnRefresh()
    if not IsServer() then return end
    local ability = self:GetAbility()
    if not ability then return end
    self.speed = ability:GetSpecialValueFor("pull_speed")
    self.min_distance = ability:GetSpecialValueFor("pull_min_distance")
end

function modifier_item_giants_ring_trinity_pull:UpdateHorizontalMotion(me, dt)
    if not IsServer() then return end
    local caster = self:GetCaster()
    if not caster or caster:IsNull() or not caster:IsAlive() or not me:IsAlive() then
        self:Destroy()
        return
    end
    local offset = caster:GetAbsOrigin() - me:GetAbsOrigin()
    offset.z = 0
    local distance = offset:Length2D()
    local step = math.min(self.speed * dt, distance - self.min_distance)
    if step <= 0 or distance < 1 then return end
    me:SetAbsOrigin(me:GetAbsOrigin() + offset:Normalized() * step)
end

function modifier_item_giants_ring_trinity_pull:OnHorizontalMotionInterrupted()
    if not IsServer() then return end
    self:Destroy()
end

function modifier_item_giants_ring_trinity_pull:OnDestroy()
    if not IsServer() then return end
    local parent = self:GetParent()
    parent:RemoveHorizontalMotionController(self)
    if parent:IsAlive() then
        ResolveNPCPositions(parent:GetAbsOrigin(), 64)
    end
end
