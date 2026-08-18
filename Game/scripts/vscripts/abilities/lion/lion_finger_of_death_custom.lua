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

local LION_FINGER_PARTICLE = "particles/units/heroes/hero_lion/lion_spell_finger_of_death.vpcf"

local function LionGetAttachmentOrigin(unit, attachment_name)
    if unit and not unit:IsNull() and unit.ScriptLookupAttachment and unit.GetAttachmentOrigin then
        local attachment = unit:ScriptLookupAttachment(attachment_name)
        if attachment and attachment > 0 then
            return unit:GetAttachmentOrigin(attachment)
        end
    end

    return unit:GetAbsOrigin()
end

local function LionGetFingerAttachName(unit)
    if unit and not unit:IsNull() and unit.ScriptLookupAttachment then
        local attach2 = unit:ScriptLookupAttachment("attach_attack2")
        if attach2 and attach2 ~= 0 then
            return "attach_attack2"
        end
    end

    return "attach_attack1"
end

local function LionPlayFingerParticle(caster, target)
    local start_origin = LionGetAttachmentOrigin(caster, LionGetFingerAttachName(caster))
    local hit_origin = LionGetAttachmentOrigin(target, "attach_hitloc")
    local target_origin = target:GetAbsOrigin()
    local to_caster = start_origin - target_origin
    if to_caster:Length2D() > 0.01 then
        to_caster = to_caster:Normalized()
    else
        to_caster = -caster:GetForwardVector()
    end

    -- Snapshot all control points. Unset CP2/CP3 default to world origin;
    -- entity-bound points also jump there if a lethal hit removes the target.
    local particle = ParticleManager:CreateParticle(LION_FINGER_PARTICLE, PATTACH_WORLDORIGIN, caster)
    ParticleManager:SetParticleControl(particle, 0, start_origin)
    ParticleManager:SetParticleControl(particle, 1, hit_origin)
    ParticleManager:SetParticleControl(particle, 2, target_origin)
    ParticleManager:SetParticleControl(particle, 3, target_origin + to_caster)
    ParticleManager:SetParticleControlForward(particle, 3, -to_caster)
    ParticleManager:ReleaseParticleIndex(particle)
end

lion_finger_of_death_custom = class({})

function lion_finger_of_death_custom:Precache(context)
    PrecacheResource("particle", LION_FINGER_PARTICLE, context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_lion.vsndevts", context)
end

function lion_finger_of_death_custom:GetBehavior()
    local behavior = DOTA_ABILITY_BEHAVIOR_UNIT_TARGET
    local caster = self:GetCaster()

    if caster and not caster:IsNull() and caster:HasModifier("modifier_lion_finger_scepter_claw") then
        behavior = behavior + DOTA_ABILITY_BEHAVIOR_AUTOCAST
    end

    return behavior
end

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

    LionPlayFingerParticle(caster, target)

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

    EmitSoundOn("Hero_Lion.FingerOfDeath", target)
end

modifier_lion_finger_scepter_claw = class({})

function modifier_lion_finger_scepter_claw:IsHidden() return false end
function modifier_lion_finger_scepter_claw:IsPurgable() return false end
function modifier_lion_finger_scepter_claw:IsBuff() return true end
function modifier_lion_finger_scepter_claw:RemoveOnDeath() return true end
function modifier_lion_finger_scepter_claw:GetTexture() return "lion_finger_of_death" end

function modifier_lion_finger_scepter_claw:LoadSpecialValues()
    local ability = self:GetAbility()

    self.attack_range = ability and not ability:IsNull() and ability:GetSpecialValueFor("scepter_attack_range") or 250
    self.cleave_damage_pct = ability and not ability:IsNull() and ability:GetSpecialValueFor("scepter_cleave_damage_pct") or 50
    self.cleave_start_width = ability and not ability:IsNull() and ability:GetSpecialValueFor("scepter_cleave_start_width") or 150
    self.cleave_end_width = ability and not ability:IsNull() and ability:GetSpecialValueFor("scepter_cleave_end_width") or 360
    self.cleave_distance = ability and not ability:IsNull() and ability:GetSpecialValueFor("scepter_cleave_distance") or 650
end

function modifier_lion_finger_scepter_claw:GetActiveAttackRecords()
    local parent = self:GetParent()
    if not parent or parent:IsNull() then
        return {}
    end

    parent.lion_finger_attack_records = parent.lion_finger_attack_records or {}
    return parent.lion_finger_attack_records
end

function modifier_lion_finger_scepter_claw:IsMeleeMode()
    local finger = self:GetAbility()
    return finger and not finger:IsNull() and finger:GetAutoCastState() or false
end

function modifier_lion_finger_scepter_claw:EnableFingerAutoCast()
    if not IsServer() then
        return
    end

    local finger = self:GetAbility()
    if not finger or finger:IsNull() then
        return
    end

    if not finger:GetAutoCastState() then
        finger:ToggleAutoCast()
    end
    if finger.MarkAbilityButtonDirty then
        finger:MarkAbilityButtonDirty()
    end
end

function modifier_lion_finger_scepter_claw:OnCreated()
    self:LoadSpecialValues()

    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if not parent or parent:IsNull() then
        return
    end

    self.original_attack_range = parent:Script_GetAttackRange()
    self.original_attack_capability = parent.lion_finger_pending_attack_capability or parent:GetAttackCapability()
    self:EnableFingerAutoCast()
    self:ApplyToggleMode()

    self:StartIntervalThink(0.1)
end

function modifier_lion_finger_scepter_claw:OnRefresh()
    self:LoadSpecialValues()

    if not IsServer() then
        return
    end

    self:EnableFingerAutoCast()
    self:ApplyToggleMode()
end

function modifier_lion_finger_scepter_claw:OnDestroy()
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if parent and not parent:IsNull() then
        if next(self:GetActiveAttackRecords()) then
            -- Let an in-flight attack keep its original capability until its
            -- record is destroyed. The permanent tracker restores it safely.
            parent.lion_finger_pending_attack_capability = self.original_attack_capability
        else
            parent:ClearActivityModifiers()
            if self.original_attack_capability then
                parent:SetAttackCapability(self.original_attack_capability)
            end
            parent.lion_finger_pending_attack_capability = nil
        end
    end

    local finger = self:GetAbility()
    if finger and not finger:IsNull() then
        if finger:GetAutoCastState() then
            finger:ToggleAutoCast()
        end
        if finger.MarkAbilityButtonDirty then
            finger:MarkAbilityButtonDirty()
        end

        Timers:CreateTimer(0, function()
            if finger and not finger:IsNull() and finger.MarkAbilityButtonDirty then
                finger:MarkAbilityButtonDirty()
            end
        end)
    end
end

function modifier_lion_finger_scepter_claw:OnIntervalThink()
    local parent = self:GetParent()
    if not LionHasScepter(parent) then
        self:Destroy()
        return
    end

    if self.applied_melee_mode ~= self:IsMeleeMode() and not next(self:GetActiveAttackRecords()) then
        self:ApplyToggleMode()
    else
        self:UpdateMindPower()
    end
end

function modifier_lion_finger_scepter_claw:UpdateMindPower()
    if not IsServer() then
        return
    end

    local mind_power = self:IsMeleeMode() and math.floor(LionGetMindPower(self:GetParent())) or 0
    if self:GetStackCount() ~= mind_power then
        self:SetStackCount(mind_power)
    end
end

function modifier_lion_finger_scepter_claw:ApplyToggleMode()
    if not IsServer() then
        return
    end

    if next(self:GetActiveAttackRecords()) then
        return
    end

    local parent = self:GetParent()
    if not parent or parent:IsNull() then
        return
    end

    parent:ClearActivityModifiers()

    self.applied_melee_mode = self:IsMeleeMode()
    if self.applied_melee_mode then
        parent:AddActivityModifier("melee")
        parent:SetAttackCapability(DOTA_UNIT_CAP_MELEE_ATTACK)
    else
        parent:SetAttackCapability(self.original_attack_capability or DOTA_UNIT_CAP_RANGED_ATTACK)
    end

    self:UpdateMindPower()
end

function modifier_lion_finger_scepter_claw:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_ATTACK_RANGE_BONUS,
        MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
        MODIFIER_EVENT_ON_ATTACK_LANDED,
        MODIFIER_EVENT_ON_DEATH,
    }
end

function modifier_lion_finger_scepter_claw:GetModifierAttackRangeBonus()
    if not self:IsMeleeMode() then
        return 0
    end
    return self.attack_range - (self.original_attack_range or self.attack_range)
end

function modifier_lion_finger_scepter_claw:GetModifierPreAttack_BonusDamage()
    return self:GetStackCount()
end

function modifier_lion_finger_scepter_claw:OnAttackLanded(params)
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    local ability = self:GetAbility()
    if not self:IsMeleeMode() or params.attacker ~= parent or not params.target or params.target:IsNull() then
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

function modifier_lion_finger_scepter_claw:OnDeath(params)
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    local ability = self:GetAbility()
    local victim = params.unit

    -- A nil inflictor identifies damage from a regular attack. Cleave and
    -- other spell/item damage must not grant additional Finger stacks.
    if not self:IsMeleeMode() or params.attacker ~= parent or params.inflictor ~= nil then
        return
    end
    if not victim or victim:IsNull() or not victim:IsRealHero() or victim:GetTeamNumber() == parent:GetTeamNumber() then
        return
    end
    if not ability or ability:IsNull() or not LionHasScepter(parent) then
        return
    end

    ability:AddRebirthStack()
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
    if not caster or caster:IsNull() then
        LionFingerDebug("kill_marker_rejected", { reason = "caster_is_invalid" })
        return
    end

    -- A direct empowered hand kill is handled by the Scepter modifier, so a
    -- Finger marker still active on the same victim must not grant a second stack.
    if params.attacker == caster and params.inflictor == nil and caster:HasModifier("modifier_lion_finger_scepter_claw") then
        LionFingerDebug("kill_marker_rejected", { reason = "scepter_hand_kill" })
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
        MODIFIER_EVENT_ON_ATTACK_RECORD,
        MODIFIER_EVENT_ON_ATTACK_RECORD_DESTROY,
    }
end

function modifier_lion_finger_rebirth:OnAttackRecord(params)
    if not IsServer() or params.attacker ~= self:GetParent() or params.record == nil then
        return
    end

    local parent = self:GetParent()
    parent.lion_finger_attack_records = parent.lion_finger_attack_records or {}
    parent.lion_finger_attack_records[params.record] = true
end

function modifier_lion_finger_rebirth:OnAttackRecordDestroy(params)
    if not IsServer() or params.attacker ~= self:GetParent() or params.record == nil then
        return
    end

    local records = self:GetParent().lion_finger_attack_records
    if records then
        records[params.record] = nil
    end

    local parent = self:GetParent()
    if next(records or {}) or parent.lion_finger_pending_attack_capability == nil or parent.lion_finger_restore_scheduled then
        return
    end

    parent.lion_finger_restore_scheduled = true
    Timers:CreateTimer(0, function()
        if not parent or parent:IsNull() then
            return
        end

        parent.lion_finger_restore_scheduled = nil
        if next(parent.lion_finger_attack_records or {}) then
            return
        end

        local capability = parent.lion_finger_pending_attack_capability
        parent.lion_finger_pending_attack_capability = nil

        -- A refreshed/new empowerment owns the attack mode now.
        if parent:HasModifier("modifier_lion_finger_scepter_claw") then
            return
        end

        parent:ClearActivityModifiers()
        if capability ~= nil then
            parent:SetAttackCapability(capability)
        end
    end)
end

function modifier_lion_finger_rebirth:GetModifierPercentageRespawnTime()
    local ability = self:GetAbility()
    local reduction = ability and not ability:IsNull() and ability:GetSpecialValueFor("respawn_reduction_pct") or 5
    local stack_reduction = math.min(1, self:GetStackCount() * reduction / 100)

    -- Valve expects a positive fraction here: 0.05 reduces the already
    -- game-mode-scaled respawn duration by 5%.
    return stack_reduction
end
