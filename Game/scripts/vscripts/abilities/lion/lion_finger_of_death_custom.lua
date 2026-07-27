LinkLuaModifier("modifier_lion_finger_rebirth", "abilities/lion/lion_finger_of_death_custom", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_lion_finger_kill_marker", "abilities/lion/lion_finger_of_death_custom", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_lion_finger_scepter_claw", "abilities/lion/lion_finger_of_death_custom", LUA_MODIFIER_MOTION_NONE)

-- Temporary diagnostics for the permanent Finger of Death stacks/respawn logic.
-- Set to false after the issue has been reproduced.
local LION_FINGER_DEBUG = false

local function LionFingerEntityLabel(unit)
    if not unit then
        return "nil"
    end
    if unit.IsNull and unit:IsNull() then
        return "null"
    end

    local name = unit.GetUnitName and unit:GetUnitName() or "unknown"
    local index = unit.entindex and unit:entindex() or -1
    return string.format("%s[%s]", tostring(name), tostring(index))
end

local function LionFingerDebug(event, fields)
    if not LION_FINGER_DEBUG or not IsServer() then
        return
    end

    local parts = {
        "[LION_FINGER_DEBUG]",
        string.format("time=%.3f", GameRules:GetGameTime()),
        "event=" .. tostring(event),
    }

    for key, value in pairs(fields or {}) do
        table.insert(parts, tostring(key) .. "=" .. tostring(value))
    end

    print(table.concat(parts, " | "))
end

local function LionGetMindPower(unit)
    if GetHeroMindPower then
        return GetHeroMindPower(unit) or 0
    end
    if unit and not unit:IsNull() and unit.GetIntellect then
        return unit:GetIntellect(false) or 0
    end
    return 0
end

local function LionAddStackedModifier(parent, ability, modifier_name, amount)
    if not parent or parent:IsNull() or amount <= 0 then
        return nil
    end

    local modifier = parent:FindModifierByName(modifier_name)
    if not modifier then
        modifier = parent:AddNewModifier(parent, ability, modifier_name, {})
    end
    if modifier and not modifier:IsNull() then
        modifier:SetStackCount(modifier:GetStackCount() + amount)
        modifier:ForceRefresh()
    end

    return modifier
end

local function LionHasScepter(unit)
    if not unit or unit:IsNull() then
        return false
    end
    if unit.HasScepter and unit:HasScepter() then
        return true
    end
    return unit:HasModifier("modifier_item_ultimate_scepter") or unit:HasModifier("modifier_item_ultimate_scepter_consumed")
end

lion_finger_of_death_custom = class({})

function lion_finger_of_death_custom:GetIntrinsicModifierName()
    return "modifier_lion_finger_rebirth"
end

function lion_finger_of_death_custom:GetMindScaledDamage()
    local caster = self:GetCaster()
    local base = self:GetSpecialValueFor("damage")
    local multiplier = self:GetSpecialValueFor("mind_power_multiplier")
    return math.max(0, base + LionGetMindPower(caster) * multiplier)
end

function lion_finger_of_death_custom:OnSpellStart()
    local caster = self:GetCaster()
    local target = self:GetCursorTarget()
    if not target or target:IsNull() then
        return
    end

    if target:TriggerSpellAbsorb(self) then
        LionFingerDebug("spell_absorbed", {
            caster = LionFingerEntityLabel(caster),
            target = LionFingerEntityLabel(target),
        })
        return
    end

    LionFingerDebug("spell_start", {
        caster = LionFingerEntityLabel(caster),
        target = LionFingerEntityLabel(target),
        damage = self:GetMindScaledDamage(),
    })

    target:AddNewModifier(caster, self, "modifier_lion_finger_kill_marker", { duration = 3 })

    ApplyDamage({
        victim = target,
        attacker = caster,
        damage = self:GetMindScaledDamage(),
        damage_type = self:GetAbilityDamageType(),
        ability = self,
    })

    if LionHasScepter(caster) then
        caster:AddNewModifier(caster, self, "modifier_lion_finger_scepter_claw", {
            duration = self:GetSpecialValueFor("scepter_buff_duration"),
        })
    end

    local particle = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_lion/lion_spell_finger_of_death.vpcf",
        PATTACH_ABSORIGIN_FOLLOW,
        caster
    )
    ParticleManager:SetParticleControlEnt(particle, 0, caster, PATTACH_POINT_FOLLOW, "attach_attack1", caster:GetAbsOrigin(), true)
    ParticleManager:SetParticleControlEnt(particle, 1, target, PATTACH_POINT_FOLLOW, "attach_hitloc", target:GetAbsOrigin(), true)
    ParticleManager:ReleaseParticleIndex(particle)

    EmitSoundOn("Hero_Lion.FingerOfDeath", target)
end

modifier_lion_finger_scepter_claw = class({})

function modifier_lion_finger_scepter_claw:IsHidden() return false end
function modifier_lion_finger_scepter_claw:IsPurgable() return false end
function modifier_lion_finger_scepter_claw:IsBuff() return true end
function modifier_lion_finger_scepter_claw:RemoveOnDeath() return true end
function modifier_lion_finger_scepter_claw:GetTexture() return "lion_finger_of_death" end

function modifier_lion_finger_scepter_claw:OnCreated()
    local parent = self:GetParent()
    local ability = self:GetAbility()

    self.attack_range = ability and not ability:IsNull() and ability:GetSpecialValueFor("scepter_attack_range") or 250
    self.cleave_damage_pct = ability and not ability:IsNull() and ability:GetSpecialValueFor("scepter_cleave_damage_pct") or 50
    self.cleave_start_width = ability and not ability:IsNull() and ability:GetSpecialValueFor("scepter_cleave_start_width") or 150
    self.cleave_end_width = ability and not ability:IsNull() and ability:GetSpecialValueFor("scepter_cleave_end_width") or 360
    self.cleave_distance = ability and not ability:IsNull() and ability:GetSpecialValueFor("scepter_cleave_distance") or 650

    if IsServer() and parent and not parent:IsNull() then
        self.original_attack_range = self.original_attack_range or parent:Script_GetAttackRange()
        self.original_attack_capability = self.original_attack_capability or parent:GetAttackCapability()
        parent:SetAttackCapability(DOTA_UNIT_CAP_MELEE_ATTACK)
        self:StartIntervalThink(0.5)
    end
end

function modifier_lion_finger_scepter_claw:OnRefresh()
    self:OnCreated()
end

function modifier_lion_finger_scepter_claw:OnDestroy()
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if parent and not parent:IsNull() and self.original_attack_capability then
        parent:SetAttackCapability(self.original_attack_capability)
    end
end

function modifier_lion_finger_scepter_claw:OnIntervalThink()
    local parent = self:GetParent()
    if not LionHasScepter(parent) then
        self:Destroy()
    end
end

function modifier_lion_finger_scepter_claw:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_ATTACK_RANGE_BONUS,
        MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
        MODIFIER_EVENT_ON_ATTACK_START,
        MODIFIER_EVENT_ON_ATTACK_LANDED,
    }
end

function modifier_lion_finger_scepter_claw:GetModifierAttackRangeBonus()
    return self.attack_range - (self.original_attack_range or self.attack_range)
end

function modifier_lion_finger_scepter_claw:GetModifierPreAttack_BonusDamage()
    return LionGetMindPower(self:GetParent())
end

function modifier_lion_finger_scepter_claw:OnAttackStart(params)
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if params.attacker ~= parent then
        return
    end

    parent:FadeGesture(ACT_DOTA_ATTACK)
    if ACT_DOTA_ATTACK_EVENT then
        parent:FadeGesture(ACT_DOTA_ATTACK_EVENT)
    end
    parent:StartGesture(ACT_DOTA_ATTACK2 or ACT_DOTA_ATTACK)
end

function modifier_lion_finger_scepter_claw:OnAttackLanded(params)
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    local ability = self:GetAbility()
    if params.attacker ~= parent or not params.target or params.target:IsNull() then
        return
    end
    if not ability or ability:IsNull() or not LionHasScepter(parent) then
        return
    end

    DoCleaveAttack(
        parent,
        params.target,
        ability,
        params.damage * (self.cleave_damage_pct or 0) / 100,
        self.cleave_start_width or 150,
        self.cleave_end_width or 360,
        self.cleave_distance or 650,
        "particles/items_fx/battlefury_cleave.vpcf"
    )
end

function lion_finger_of_death_custom:AddRebirthStack()
    local caster = self:GetCaster()
    local current = caster and not caster:IsNull() and caster:FindModifierByName("modifier_lion_finger_rebirth") or nil
    local before = current and not current:IsNull() and current:GetStackCount() or 0
    local modifier = LionAddStackedModifier(caster, self, "modifier_lion_finger_rebirth", 1)
    local after = modifier and not modifier:IsNull() and modifier:GetStackCount() or -1

    LionFingerDebug("rebirth_stack_added", {
        caster = LionFingerEntityLabel(caster),
        before = before,
        after = after,
    })
end

modifier_lion_finger_kill_marker = class({})

function modifier_lion_finger_kill_marker:IsHidden() return true end
function modifier_lion_finger_kill_marker:IsPurgable() return false end
function modifier_lion_finger_kill_marker:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_DEATH,
    }
end

function modifier_lion_finger_kill_marker:OnDeath(params)
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    local caster = self:GetCaster()
    local ability = self:GetAbility()

    LionFingerDebug("kill_marker_death_event", {
        marker_parent = LionFingerEntityLabel(parent),
        dead_unit = LionFingerEntityLabel(params.unit),
        attacker = LionFingerEntityLabel(params.attacker),
        caster = LionFingerEntityLabel(caster),
        inflictor = params.inflictor and params.inflictor:GetAbilityName() or "nil",
        expected_inflictor = ability and not ability:IsNull() and ability:GetAbilityName() or "nil",
    })

    if not parent or parent:IsNull() or params.unit ~= parent then
        LionFingerDebug("kill_marker_rejected", { reason = "dead_unit_is_not_marker_parent" })
        return
    end
    if not parent:IsRealHero() then
        LionFingerDebug("kill_marker_rejected", { reason = "victim_is_not_real_hero" })
        return
    end
    if not caster or caster:IsNull() or params.attacker ~= caster then
        LionFingerDebug("kill_marker_rejected", { reason = "attacker_is_not_caster" })
        return
    end
    if params.inflictor ~= ability then
        LionFingerDebug("kill_marker_rejected", { reason = "inflictor_is_not_finger" })
        return
    end

    LionFingerDebug("kill_marker_accepted", {
        victim = LionFingerEntityLabel(parent),
        caster = LionFingerEntityLabel(caster),
    })

    if ability and not ability:IsNull() and ability.AddRebirthStack then
        ability:AddRebirthStack()
    end
end

modifier_lion_finger_rebirth = class({})

function modifier_lion_finger_rebirth:IsHidden() return self:GetStackCount() <= 0 end
function modifier_lion_finger_rebirth:IsPurgable() return false end
function modifier_lion_finger_rebirth:IsBuff() return true end
function modifier_lion_finger_rebirth:RemoveOnDeath() return false end
function modifier_lion_finger_rebirth:IsPermanent() return true end
function modifier_lion_finger_rebirth:GetTexture() return "lion_finger_of_death" end
function modifier_lion_finger_rebirth:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_RESPAWNTIME_PERCENTAGE,
    }
end

function modifier_lion_finger_rebirth:GetModifierPercentageRespawnTime()
    local ability = self:GetAbility()
    local reduction = ability and not ability:IsNull() and ability:GetSpecialValueFor("respawn_reduction_pct") or 5
    local stack_reduction = math.min(1, self:GetStackCount() * reduction / 100)

    -- Valve expects a positive fraction here: 0.05 reduces the already
    -- game-mode-scaled respawn duration by 5%.
    return stack_reduction
end
