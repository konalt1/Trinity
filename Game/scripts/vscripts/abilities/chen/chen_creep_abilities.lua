-- Chen Barrack Creep Abilities
-- Simplified versions of hero abilities for Chen's barrack creeps

chen_creep_relocate = class({})
chen_creep_inner_beast = class({})
chen_creep_furry_swipes = class({})
chen_creep_spirit_forest = class({})
chen_creep_leech_seed = class({})
chen_creep_entangle = class({})
chen_creep_tornado = class({})

-- Relocate (Warruner)
function chen_creep_relocate:OnSpellStart()
    if not IsServer() then return end

    local caster = self:GetCaster()
    local targetPoint = self:GetCursorPosition()
    local returnDelay = self:GetSpecialValueFor("return_delay")

    -- Save original position
    local originalPos = caster:GetAbsOrigin()

    -- Create return timer
    local returnTimer = Timers:CreateTimer(returnDelay, function()
        if caster and not caster:IsNull() and caster:IsAlive() then
            FindClearSpaceForUnit(caster, originalPos, true)
            EmitSoundOn("Hero_Wisp.Relocate.Return", caster)
        end
    end)

    -- Teleport to target
    FindClearSpaceForUnit(caster, targetPoint, true)
    EmitSoundOn("Hero_Wisp.Relocate.Teleport", caster)
end

function chen_creep_relocate:OnChannelFinish(interrupted)
    if interrupted then
        -- If interrupted, return immediately
        local caster = self:GetCaster()
        if caster.chen_relocate_original_pos then
            FindClearSpaceForUnit(caster, caster.chen_relocate_original_pos, true)
            EmitSoundOn("Hero_Wisp.Relocate.Return", caster)
        end
    end
end

-- Inner Beast (Wanderbear)
function chen_creep_inner_beast:OnSpellStart()
    if not IsServer() then return end

    local caster = self:GetCaster()
    local duration = self:GetSpecialValueFor("duration")
    local bonusAttackSpeed = self:GetSpecialValueFor("bonus_attack_speed")
    local bonusDamage = self:GetSpecialValueFor("bonus_damage")
    local radius = self:GetSpecialValueFor("radius")

    -- Apply buff to caster
    caster:AddNewModifier(caster, self, "modifier_chen_creep_inner_beast", {
        duration = duration,
        bonus_attack_speed = bonusAttackSpeed,
        bonus_damage = bonusDamage
    })

    -- Apply buff to nearby allies
    local allies = FindUnitsInRadius(caster:GetTeamNumber(), caster:GetAbsOrigin(), nil, radius, DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

    for _, ally in ipairs(allies) do
        if ally ~= caster and not ally:IsNull() and ally:IsAlive() then
            ally:AddNewModifier(caster, self, "modifier_chen_creep_inner_beast", {
                duration = duration,
                bonus_attack_speed = bonusAttackSpeed,
                bonus_damage = bonusDamage
            })
        end
    end

    EmitSoundOn("Hero_LoneDruid.Bear.Cast", caster)
end

-- Furry Swipes (Torchbearer) - Passive
function chen_creep_furry_swipes:GetIntrinsicModifierName()
    return "modifier_chen_creep_furry_swipes"
end

function chen_creep_furry_swipes:OnHeroDiedNearby()
    -- This ability is passive, no active cast
end

-- Spirit of the Forest (Treant) - Passive
function chen_creep_spirit_forest:GetIntrinsicModifierName()
    return "modifier_chen_creep_spirit_forest"
end

-- Leech Seed (Shroomling)
function chen_creep_leech_seed:OnSpellStart()
    if not IsServer() then return end

    local caster = self:GetCaster()
    local target = self:GetCursorTarget()
    local damage = self:GetSpecialValueFor("damage")
    local healAmount = self:GetSpecialValueFor("heal_amount")
    local duration = self:GetSpecialValueFor("duration")
    local radius = self:GetSpecialValueFor("radius")

    -- Apply debuff to target
    target:AddNewModifier(caster, self, "modifier_chen_creep_leech_seed", {
        duration = duration,
        damage = damage,
        heal_amount = healAmount,
        radius = radius,
        caster = caster:entindex()
    })

    EmitSoundOn("Hero_Furion.LeechSeed.Cast", caster)
end

-- Entangle (Woodling)
function chen_creep_entangle:OnSpellStart()
    if not IsServer() then return end

    local caster = self:GetCaster()
    local target = self:GetCursorTarget()
    local duration = self:GetSpecialValueFor("duration")
    local damage = self:GetSpecialValueFor("damage")

    -- Apply root to target
    target:AddNewModifier(caster, self, "modifier_chen_creep_entangle", {
        duration = duration,
        damage = damage
    })

    EmitSoundOn("Hero_Furion.Sprout.Cast", caster)
end

-- Tornado (Phoenix bird)
function chen_creep_tornado:OnSpellStart()
    if not IsServer() then return end

    local caster = self:GetCaster()
    local targetPoint = self:GetCursorPosition()
    local travelDistance = self:GetSpecialValueFor("travel_distance")
    local travelSpeed = self:GetSpecialValueFor("travel_speed")
    local duration = self:GetSpecialValueFor("duration")
    local radius = self:GetSpecialValueFor("radius")
    local damage = self:GetSpecialValueFor("damage")
    local liftDuration = self:GetSpecialValueFor("lift_duration")

    -- Create tornado
    local direction = (targetPoint - caster:GetAbsOrigin()):Normalized()
    local spawnPoint = caster:GetAbsOrigin()

    local tornado = CreateUnitByName("npc_dota_unit_tornado", spawnPoint, false, caster, caster, caster:GetTeamNumber())
    if tornado then
        tornado:SetAbsOrigin(spawnPoint)
        tornado:SetForwardVector(direction)
        tornado:AddNewModifier(caster, self, "modifier_chen_creep_tornado", {
            duration = duration,
            travel_distance = travelDistance,
            travel_speed = travelSpeed,
            radius = radius,
            damage = damage,
            lift_duration = liftDuration,
            direction = direction,
            spawn_point = spawnPoint
        })
    end

    EmitSoundOn("Hero_Invoker.Tornado.Cast", caster)
end

-- Modifiers
modifier_chen_creep_inner_beast = class({})
function modifier_chen_creep_inner_beast:IsHidden() return false end
function modifier_chen_creep_inner_beast:IsDebuff() return false end
function modifier_chen_creep_inner_beast:IsPurgable() return true end

function modifier_chen_creep_inner_beast:OnCreated(kv)
    if not IsServer() then return end
    self.bonus_attack_speed = kv.bonus_attack_speed or 30
    self.bonus_damage = kv.bonus_damage or 15
end

function modifier_chen_creep_inner_beast:DeclareFunctions()
    return { MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT, MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE }
end

function modifier_chen_creep_inner_beast:GetModifierAttackSpeedBonus_Constant()
    return self.bonus_attack_speed
end

function modifier_chen_creep_inner_beast:GetModifierPreAttack_BonusDamage()
    return self.bonus_damage
end

modifier_chen_creep_furry_swipes = class({})
function modifier_chen_creep_furry_swipes:IsHidden() return true end
function modifier_chen_creep_furry_swipes:IsDebuff() return false end
function modifier_chen_creep_furry_swipes:IsPurgable() return false end

function modifier_chen_creep_furry_swipes:OnCreated(kv)
    if not IsServer() then return end
    self.bonus_damage_per_hit = self:GetAbility():GetSpecialValueFor("bonus_damage_per_hit") or 15
    self.duration = self:GetAbility():GetSpecialValueFor("duration") or 10
    self.max_stacks = self:GetAbility():GetSpecialValueFor("max_stacks") or 3
    self.stacks = {}
end

function modifier_chen_creep_furry_swipes:DeclareFunctions()
    return { MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE }
end

function modifier_chen_creep_furry_swipes:GetModifierPreAttack_BonusDamage()
    local parent = self:GetParent()
    if not parent or parent:IsNull() then return 0 end

    local currentTime = GameRules:GetGameTime()
    local bonus = 0

    -- Clean up expired stacks
    local newStacks = {}
    for _, stackTime in ipairs(self.stacks) do
        if currentTime - stackTime < self.duration then
            table.insert(newStacks, stackTime)
            bonus = bonus + self.bonus_damage_per_hit
        end
    end
    self.stacks = newStacks

    -- Cap at max stacks
    if #self.stacks > self.max_stacks then
        bonus = self.bonus_damage_per_hit * self.max_stacks
    end

    return bonus
end

function modifier_chen_creep_furry_swipes:OnAttackLanded(params)
    if not IsServer() then return end
    if params.attacker ~= self:GetParent() then return end

    table.insert(self.stacks, GameRules:GetGameTime())
end

modifier_chen_creep_spirit_forest = class({})
function modifier_chen_creep_spirit_forest:IsHidden() return true end
function modifier_chen_creep_spirit_forest:IsDebuff() return false end
function modifier_chen_creep_spirit_forest:IsPurgable() return false end

function modifier_chen_creep_spirit_forest:OnCreated(kv)
    if not IsServer() then return end
    self.tree_radius = self:GetAbility():GetSpecialValueFor("tree_radius") or 250
    self.bonus_damage = self:GetAbility():GetSpecialValueFor("bonus_damage") or 5
    self.bonus_attack_speed = self:GetAbility():GetSpecialValueFor("bonus_attack_speed") or 3

    self:StartIntervalThink(0.5)
end

function modifier_chen_creep_spirit_forest:OnIntervalThink()
    if not IsServer() then return end
    if not self:GetParent() or self:GetParent():IsNull() then return end

    local parent = self:GetParent()
    local parentPos = parent:GetAbsOrigin()

    -- Find trees in radius
    local trees = GridNav:GetAllTreesInRadius(parentPos, self.tree_radius, true)
    local treeCount = #trees

    -- Apply bonuses based on tree count
    parent:SetModifierStackCount(treeCount, self, "spirit_forest_trees")
end

function modifier_chen_creep_spirit_forest:DeclareFunctions()
    return { MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE, MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT }
end

function modifier_chen_creep_spirit_forest:GetModifierPreAttack_BonusDamage()
    return self:GetStackCount() * self.bonus_damage
end

function modifier_chen_creep_spirit_forest:GetModifierAttackSpeedBonus_Constant()
    return self:GetStackCount() * self.bonus_attack_speed
end

modifier_chen_creep_leech_seed = class({})
function modifier_chen_creep_leech_seed:IsHidden() return false end
function modifier_chen_creep_leech_seed:IsDebuff() return true end
function modifier_chen_creep_leech_seed:IsPurgable() return true end

function modifier_chen_creep_leech_seed:OnCreated(kv)
    if not IsServer() then return end
    self.damage = kv.damage or 75
    self.heal_amount = kv.heal_amount or 75
    self.radius = kv.radius or 300
    self.caster_entindex = kv.caster

    self:StartIntervalThink(1.0)
end

function modifier_chen_creep_leech_seed:OnIntervalThink()
    if not IsServer() then return end
    local parent = self:GetParent()
    if not parent or parent:IsNull() then return end

    local caster = EntIndexToHScript(self.caster_entindex)
    if not caster or caster:IsNull() or not caster:IsAlive() then
        self:Destroy()
        return
    end

    -- Deal damage to target
    ApplyDamage({
        victim = parent,
        attacker = caster,
        damage = self.damage,
        damage_type = DAMAGE_TYPE_MAGICAL,
        ability = self:GetAbility()
    })

    -- Heal caster and nearby allies
    local allies = FindUnitsInRadius(caster:GetTeamNumber(), caster:GetAbsOrigin(), nil, self.radius, DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

    for _, ally in ipairs(allies) do
        if ally:IsAlive() then
            ally:Heal(self.heal_amount, self:GetAbility())
        end
    end
end

modifier_chen_creep_entangle = class({})
function modifier_chen_creep_entangle:IsHidden() return false end
function modifier_chen_creep_entangle:IsDebuff() return true end
function modifier_chen_creep_entangle:IsPurgable() return true end
function modifier_chen_creep_entangle:IsStunDebuff() return false end

function modifier_chen_creep_entangle:OnCreated(kv)
    if not IsServer() then return end
    self.damage = kv.damage or 100

    self:StartIntervalThink(1.0)
end

function modifier_chen_creep_entangle:OnIntervalThink()
    if not IsServer() then return end
    local parent = self:GetParent()
    if not parent or parent:IsNull() then return end

    local caster = self:GetCaster()
    if not caster or caster:IsNull() or not caster:IsAlive() then return end

    ApplyDamage({
        victim = parent,
        attacker = caster,
        damage = self.damage,
        damage_type = DAMAGE_TYPE_MAGICAL,
        ability = self:GetAbility()
    })
end

function modifier_chen_creep_entangle:CheckState()
    return {
        [MODIFIER_STATE_ROOTED] = true,
        [MODIFIER_STATE_DISARMED] = true
    }
end

function modifier_chen_creep_entangle:GetEffectName()
    return "particles/items2_fx/gleipnir_root.vpcf"
end

modifier_chen_creep_tornado = class({})
function modifier_chen_creep_tornado:IsHidden() return true end
function modifier_chen_creep_tornado:IsPurgable() return false end

function modifier_chen_creep_tornado:OnCreated(kv)
    if not IsServer() then return end
    self.travel_distance = kv.travel_distance or 2000
    self.travel_speed = kv.travel_speed or 1000
    self.duration = kv.duration or 2.5
    self.radius = kv.radius or 200
    self.damage = kv.damage or 80
    self.lift_duration = kv.lift_duration or 2.2
    self.direction = kv.direction
    self.spawn_point = kv.spawn_point

    self.traveled = 0
    self.affectedUnits = {}

    self:StartIntervalThink(0.1)
end

function modifier_chen_creep_tornado:OnIntervalThink()
    if not IsServer() then return end

    local parent = self:GetParent()
    if not parent or parent:IsNull() then return end

    -- Move tornado
    local moveStep = self.travel_speed * 0.1
    local newPos = parent:GetAbsOrigin() + self.direction * moveStep
    parent:SetAbsOrigin(newPos)

    self.traveled = self.traveled + moveStep

    -- Find and lift units
    local enemies = FindUnitsInRadius(parent:GetTeamNumber(), parent:GetAbsOrigin(), nil, self.radius, DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false)

    for _, enemy in ipairs(enemies) do
        if enemy:IsAlive() and not self.affectedUnits[enemy:entindex()] then
            self.affectedUnits[enemy:entindex()] = true

            -- Apply lift modifier
            enemy:AddNewModifier(parent, self:GetAbility(), "modifier_chen_creep_tornado_lift", {
                duration = self.lift_duration,
                damage = self.damage,
                parent_entindex = parent:entindex()
            })
        end
    end

    -- Destroy when distance traveled
    if self.traveled >= self.travel_distance then
        self:Destroy()
    end
end

function modifier_chen_creep_tornado:OnDestroy()
    if not IsServer() then return end
    local parent = self:GetParent()
    if parent and not parent:IsNull() then
        UTIL_Remove(parent)
    end
end

modifier_chen_creep_tornado_lift = class({})
function modifier_chen_creep_tornado_lift:IsHidden() return false end
function modifier_chen_creep_tornado_lift:IsDebuff() return true end
function modifier_chen_creep_tornado_lift:IsPurgable() return true end

function modifier_chen_creep_tornado_lift:OnCreated(kv)
    if not IsServer() then return end
    self.damage = kv.damage or 80
    self.parent_entindex = kv.parent_entindex

    self:StartIntervalThink(0.5)
end

function modifier_chen_creep_tornado_lift:OnIntervalThink()
    if not IsServer() then return end
    local parent = self:GetParent()
    if not parent or parent:IsNull() then return end

    local tornado = EntIndexToHScript(self.parent_entindex)
    if not tornado or tornado:IsNull() then
        self:Destroy()
        return
    end

    -- Deal damage
    ApplyDamage({
        victim = parent,
        attacker = tornado,
        damage = self.damage,
        damage_type = DAMAGE_TYPE_MAGICAL,
        ability = self:GetAbility()
    })
end

function modifier_chen_creep_tornado_lift:CheckState()
    return {
        [MODIFIER_STATE_INVULNERABLE] = true,
        [MODIFIER_STATE_NO_UNIT_COLLISION] = true
    }
end

function modifier_chen_creep_tornado_lift:GetEffectName()
    return "particles/units/heroes/hero_invoker/invoker_tornado_child.vpcf"
end
