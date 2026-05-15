focus = class({})

local FOCUS_SHIELD_PARTICLE = "particles/silencer/focus/lotus_orb_fallrewardline_2025_shield_fallrewardline_2025.vpcf"

LinkLuaModifier("modifier_focus_buff", "abilities/silencer/focus", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_focus_control_block", "abilities/silencer/focus", LUA_MODIFIER_MOTION_NONE)

-- hero_for_mind_power: герой, чья Сила магии участвует в формуле (обычно кастер способности).
local function focus_compute_physical_barrier(ability, hero_for_mind_power)
    if not ability or ability:IsNull() or not hero_for_mind_power or hero_for_mind_power:IsNull() then
        return 0
    end
    local base = ability:GetSpecialValueFor("shield_amount") or 0
    local mult = ability:GetSpecialValueFor("mind_power_multiplier") or 0
    local mind_power = 0
    if GetHeroMindPower then
        mind_power = GetHeroMindPower(hero_for_mind_power) or 0
    else
        mind_power = hero_for_mind_power:GetIntellect(false) or 0
    end
    return math.max(0, math.floor(base + mind_power * mult))
end

local function focus_modifier_sync_shield_from_server(mod, push_to_clients)
    if not IsServer() then
        return
    end
    mod:SetStackCount(math.max(0, math.floor(mod.current_shield or 0)))
    if push_to_clients then
        mod:SendBuffRefreshToClients()
    end
end

function focus:OnSpellStart()
    local caster = self:GetCaster()
    local duration = self:GetSpecialValueFor("duration")
    local shield = focus_compute_physical_barrier(self, caster)
    self.focus_barrier_amount = shield

    local function apply_focus_target(target)
        if not target or target:IsNull() or not target:IsAlive() or not target:IsHero() then
            return
        end

        target:AddNewModifier(caster, self, "modifier_focus_buff", {
            duration = duration,
            shield_amount = shield,
        })
    end

    if caster:HasScepter() then
        local radius = self:GetSpecialValueFor("scepter_ally_radius")
        local allies = FindUnitsInRadius(
            caster:GetTeamNumber(),
            caster:GetAbsOrigin(),
            nil,
            radius,
            DOTA_UNIT_TARGET_TEAM_FRIENDLY,
            DOTA_UNIT_TARGET_HERO,
            DOTA_UNIT_TARGET_FLAG_NONE,
            FIND_ANY_ORDER,
            false
        )

        for _, ally in ipairs(allies) do
            apply_focus_target(ally)
        end
    else
        apply_focus_target(caster)
    end

    caster:EmitSound("Hero_Antimage.Counterspell.Cast")
end

modifier_focus_buff = class({})
modifier_focus_control_block = class({})

function modifier_focus_buff:IsHidden()
    return false
end

function modifier_focus_buff:IsPurgable()
    return true
end

function modifier_focus_buff:InitShieldFromKv(kv)
    local amount = tonumber(kv and kv.shield_amount)
    local ability = self:GetAbility()
    local mind_hero = ability and ability:GetCaster()

    if not amount or amount < 0 then
        if ability and ability.focus_barrier_amount ~= nil then
            amount = tonumber(ability.focus_barrier_amount)
        end
    end
    if not amount or amount < 0 then
        amount = focus_compute_physical_barrier(ability, mind_hero)
    end

    self.max_shield = math.max(0, math.floor(amount))
    self.current_shield = self.max_shield
end

function modifier_focus_buff:OnCreated(kv)
    self.block_consumed = false
    self.max_shield = 0
    self.current_shield = 0
    self:InitShieldFromKv(kv)

    if IsServer() then
        self:SetHasCustomTransmitterData(true)
        self:CreateFocusParticle()
        focus_modifier_sync_shield_from_server(self, true)
    end
end

function modifier_focus_buff:OnRefresh()
    local ability = self:GetAbility()
    local mind_hero = ability and ability:GetCaster()
    local amount = ability and tonumber(ability.focus_barrier_amount)

    self.block_consumed = false
    if not amount or amount < 0 then
        amount = focus_compute_physical_barrier(ability, mind_hero)
    end
    self.max_shield = math.max(0, math.floor(amount))
    self.current_shield = self.max_shield

    if IsServer() then
        self:SetHasCustomTransmitterData(true)
        self:CreateFocusParticle()
        focus_modifier_sync_shield_from_server(self, true)
    end
end

function modifier_focus_buff:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_INCOMING_PHYSICAL_DAMAGE_CONSTANT,
        MODIFIER_PROPERTY_TOOLTIP,
        MODIFIER_EVENT_ON_STATE_CHANGED,
        MODIFIER_EVENT_ON_MODIFIER_ADDED,
    }
end

function modifier_focus_buff:AddCustomTransmitterData()
    return {
        max_shield = self.max_shield or 0,
        current_shield = self.current_shield or 0,
    }
end

function modifier_focus_buff:HandleCustomTransmitterData(data)
    self.max_shield = data.max_shield or 0
    self.current_shield = data.current_shield or 0
end

function modifier_focus_buff:GetModifierIncomingPhysicalDamageConstant(params)
    if not IsServer() then
        if params.report_max then
            return self.max_shield or 0
        end
        return math.max(0, self:GetStackCount())
    end

    if not params then
        return 0
    end

    local parent = self:GetParent()
    if params.target and params.target ~= parent then
        return 0
    end

    if (self.current_shield or 0) <= 0 then
        return 0
    end

    local blocked = math.min(params.damage, self.current_shield)
    self.current_shield = self.current_shield - blocked
    focus_modifier_sync_shield_from_server(self, false)
    return -blocked
end

function modifier_focus_buff:OnTooltip()
    return math.max(0, self:GetStackCount())
end

function modifier_focus_buff:CreateFocusParticle()
    local parent = self:GetParent()
    if not parent or parent:IsNull() then
        return
    end

    if self.focus_particle then
        ParticleManager:DestroyParticle(self.focus_particle, false)
        ParticleManager:ReleaseParticleIndex(self.focus_particle)
    end

    self.focus_particle = ParticleManager:CreateParticle(
        FOCUS_SHIELD_PARTICLE,
        PATTACH_ABSORIGIN_FOLLOW,
        parent
    )
end

function modifier_focus_buff:DestroyFocusParticle()
    if not self.focus_particle then
        return
    end

    ParticleManager:DestroyParticle(self.focus_particle, false)
    ParticleManager:ReleaseParticleIndex(self.focus_particle)
    self.focus_particle = nil
end

function modifier_focus_buff:OnDestroy()
    if not IsServer() then
        return
    end

    self:DestroyFocusParticle()
end

function modifier_focus_buff:TriggerFocusCleanse()
    local parent = self:GetParent()
    if not parent or parent:IsNull() or not parent:IsAlive() then
        return
    end

    self.block_consumed = true
    self:DestroyFocusParticle()
    parent:Purge(false, true, false, true, true)

    local block_particle = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_antimage/antimage_counter.vpcf",
        PATTACH_ABSORIGIN_FOLLOW,
        parent
    )
    ParticleManager:ReleaseParticleIndex(block_particle)
    parent:EmitSound("Hero_Antimage.Counterspell.Target")
end

function modifier_focus_buff:TryBlockMomSilence()
    local parent = self:GetParent()
    if not parent or parent:IsNull() then
        return false
    end

    local mom_modifier = parent:FindModifierByName("modifier_item_mask_of_madness_berserk")
    if not mom_modifier or mom_modifier:IsNull() then
        return false
    end

    local duration = mom_modifier:GetRemainingTime()
    if not duration or duration <= 0 then
        return false
    end

    parent:AddNewModifier(parent, self:GetAbility(), "modifier_focus_control_block", {
        duration = duration,
        block_stunned = 0,
        block_silenced = 1,
        block_rooted = 0,
        block_disarmed = 0,
        block_hexed = 0,
        block_muted = 0,
        block_feared = 0,
        block_nightmared = 0,
        block_taunted = 0,
        block_break = 0,
    })

    return true
end

function modifier_focus_buff:ApplyControlBlock(
    duration,
    block_stunned,
    block_silenced,
    block_rooted,
    block_disarmed,
    block_hexed,
    block_muted,
    block_feared,
    block_nightmared,
    block_taunted,
    block_break
)
    local parent = self:GetParent()
    if not parent or parent:IsNull() then
        return
    end

    if not duration or duration <= 0 then
        duration = FrameTime() * 2
    end

    parent:AddNewModifier(parent, self:GetAbility(), "modifier_focus_control_block", {
        duration = duration,
        block_stunned = block_stunned,
        block_silenced = block_silenced,
        block_rooted = block_rooted,
        block_disarmed = block_disarmed,
        block_hexed = block_hexed,
        block_muted = block_muted,
        block_feared = block_feared,
        block_nightmared = block_nightmared,
        block_taunted = block_taunted,
        block_break = block_break,
    })
end

function modifier_focus_buff:OnStateChanged(keys)
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if not keys or keys.unit ~= parent or self.block_consumed then
        return
    end

    if not parent:IsAlive() then
        return
    end

    local should_block = parent:IsStunned()
        or parent:IsSilenced()
        or parent:IsRooted()
        or parent:IsDisarmed()
        or parent:IsHexed()
        or parent:IsMuted()
        or parent:IsFeared()
        or parent:IsNightmared()
        or parent:IsTaunted()
        or parent:PassivesDisabled()

    if not should_block then
        return
    end

    if parent:IsSilenced() then
        self:ApplyControlBlock(FrameTime() * 2, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0)
    else
        self:TryBlockMomSilence()
    end
    self:TriggerFocusCleanse()
end

function modifier_focus_buff:OnModifierAdded(keys)
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if not keys or keys.unit ~= parent or self.block_consumed then
        return
    end

    local added_modifier = keys.added_buff
    if not added_modifier or added_modifier:IsNull() or added_modifier == self then
        return
    end

    local state = added_modifier.CheckState and added_modifier:CheckState() or nil
    local modifier_name = added_modifier.GetName and added_modifier:GetName() or ""
    local modifier_caster = added_modifier.GetCaster and added_modifier:GetCaster() or nil
    local is_self_applied = modifier_caster ~= nil and modifier_caster == parent
    if not state and modifier_name ~= "modifier_item_mask_of_madness_berserk" then
        return
    end

    local block_stunned = state and state[MODIFIER_STATE_STUNNED] and 1 or 0
    local block_silenced = state and state[MODIFIER_STATE_SILENCED] and 1 or 0
    local block_rooted = state and state[MODIFIER_STATE_ROOTED] and 1 or 0
    local block_disarmed = state and state[MODIFIER_STATE_DISARMED] and 1 or 0
    local block_hexed = state and state[MODIFIER_STATE_HEXED] and 1 or 0
    local block_muted = state and state[MODIFIER_STATE_MUTED] and 1 or 0
    local block_feared = state and state[MODIFIER_STATE_FEARED] and 1 or 0
    local block_nightmared = state and state[MODIFIER_STATE_NIGHTMARED] and 1 or 0
    local block_taunted = state and state[MODIFIER_STATE_TAUNTED] and 1 or 0
    local block_break = state and state[MODIFIER_STATE_PASSIVES_DISABLED] and 1 or 0

    if modifier_name == "modifier_item_mask_of_madness_berserk" then
        block_silenced = 1
    end

    if is_self_applied and parent:IsSilenced() then
        block_silenced = 1
    end

    local applies_control = block_stunned == 1
        or block_silenced == 1
        or block_rooted == 1
        or block_disarmed == 1
        or block_hexed == 1
        or block_muted == 1
        or block_feared == 1
        or block_nightmared == 1
        or block_taunted == 1
        or block_break == 1

    if not applies_control then
        return
    end

    local should_apply_block = (not added_modifier:IsDebuff()) or is_self_applied
    if should_apply_block then
        local duration = added_modifier:GetRemainingTime()
        self:ApplyControlBlock(
            duration,
            block_stunned,
            block_silenced,
            block_rooted,
            block_disarmed,
            block_hexed,
            block_muted,
            block_feared,
            block_nightmared,
            block_taunted,
            block_break
        )
    end

    self:TriggerFocusCleanse()
end

function modifier_focus_buff:GetEffectAttachType()
    return PATTACH_ABSORIGIN_FOLLOW
end

function modifier_focus_control_block:IsHidden()
    return true
end

function modifier_focus_control_block:IsPurgable()
    return false
end

function modifier_focus_control_block:GetPriority()
    return MODIFIER_PRIORITY_ULTRA
end

function modifier_focus_control_block:OnCreated(kv)
    self.block_stunned = kv.block_stunned == 1
    self.block_silenced = kv.block_silenced == 1
    self.block_rooted = kv.block_rooted == 1
    self.block_disarmed = kv.block_disarmed == 1
    self.block_hexed = kv.block_hexed == 1
    self.block_muted = kv.block_muted == 1
    self.block_feared = kv.block_feared == 1
    self.block_nightmared = kv.block_nightmared == 1
    self.block_taunted = kv.block_taunted == 1
    self.block_break = kv.block_break == 1
end

function modifier_focus_control_block:CheckState()
    local state = {}

    if self.block_stunned then
        state[MODIFIER_STATE_STUNNED] = false
    end
    if self.block_silenced then
        state[MODIFIER_STATE_SILENCED] = false
    end
    if self.block_rooted then
        state[MODIFIER_STATE_ROOTED] = false
    end
    if self.block_disarmed then
        state[MODIFIER_STATE_DISARMED] = false
    end
    if self.block_hexed then
        state[MODIFIER_STATE_HEXED] = false
    end
    if self.block_muted then
        state[MODIFIER_STATE_MUTED] = false
    end
    if self.block_feared then
        state[MODIFIER_STATE_FEARED] = false
    end
    if self.block_nightmared then
        state[MODIFIER_STATE_NIGHTMARED] = false
    end
    if self.block_taunted then
        state[MODIFIER_STATE_TAUNTED] = false
    end
    if self.block_break then
        state[MODIFIER_STATE_PASSIVES_DISABLED] = false
    end

    return state
end
