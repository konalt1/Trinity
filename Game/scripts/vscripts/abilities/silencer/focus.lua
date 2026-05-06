focus = class({})

local FOCUS_SHIELD_PARTICLE = "particles/silencer/focus/lotus_orb_fallrewardline_2025_shield_fallrewardline_2025.vpcf"

LinkLuaModifier("modifier_focus_buff", "abilities/silencer/focus", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_focus_control_block", "abilities/silencer/focus", LUA_MODIFIER_MOTION_NONE)

function focus:OnSpellStart()
    local caster = self:GetCaster()
    local duration = self:GetSpecialValueFor("duration")

    caster:AddNewModifier(caster, self, "modifier_focus_buff", { duration = duration })
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


function modifier_focus_buff:OnCreated()
    self.max_shield = 0
    self.current_shield = 0
    self.block_consumed = false
    self:SetHasCustomTransmitterData(true)

    local ability = self:GetAbility()
    if ability and not ability:IsNull() then
        local base_shield = ability:GetSpecialValueFor("shield_amount")
        local mind_power_multiplier = ability:GetSpecialValueFor("mind_power_multiplier")
        local caster = self:GetCaster()
        local mind_power = 0

        if caster and not caster:IsNull() then
            mind_power = GetHeroMindPower and (GetHeroMindPower(caster) or 0) or (caster:GetIntellect(false) or 0)
        end

        self.max_shield = math.max(0, base_shield + mind_power * mind_power_multiplier)
        self.current_shield = self.max_shield
    end

    if IsServer() then
        self:SendBuffRefreshToClients()
        self:CreateFocusParticle()
    end
end

function modifier_focus_buff:OnRefresh()
    self:OnCreated()
end

function modifier_focus_buff:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_INCOMING_DAMAGE_CONSTANT,
        MODIFIER_PROPERTY_TOOLTIP,
        MODIFIER_EVENT_ON_STATE_CHANGED,
        MODIFIER_EVENT_ON_MODIFIER_ADDED
    }
end

function modifier_focus_buff:AddCustomTransmitterData()
    return {
        max_shield = self.max_shield or 0,
        current_shield = self.current_shield or 0
    }
end

function modifier_focus_buff:HandleCustomTransmitterData(data)
    self.max_shield = data.max_shield or 0
    self.current_shield = data.current_shield or 0
end

function modifier_focus_buff:GetModifierIncomingDamageConstant(params)
    if not IsServer() then
        if params.report_max then
            return self.max_shield or 0
        end

        return self.current_shield or 0
    end

    if not params or params.damage_type ~= DAMAGE_TYPE_PHYSICAL then
        return 0
    end

    local parent = self:GetParent()
    if params.target and params.target ~= parent then
        return 0
    end

    if not self.current_shield or self.current_shield <= 0 then
        return 0
    end

    local blocked_damage = math.min(params.damage, self.current_shield)
    self.current_shield = self.current_shield - blocked_damage
    self:SendBuffRefreshToClients()

    return -blocked_damage
end

function modifier_focus_buff:OnTooltip()
    return self.current_shield or 0
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
        block_break = 0
    })

    return true
end

function modifier_focus_buff:ApplyControlBlock(duration, block_stunned, block_silenced, block_rooted, block_disarmed, block_hexed, block_muted, block_feared, block_nightmared, block_taunted, block_break)
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
        block_break = block_break
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
