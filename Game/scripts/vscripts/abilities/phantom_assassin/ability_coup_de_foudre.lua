LinkLuaModifier("modifier_coup_de_foudre", "abilities/phantom_assassin/ability_coup_de_foudre", 0)
LinkLuaModifier("modifier_coup_de_foudre_buff", "abilities/phantom_assassin/ability_coup_de_foudre", 0)
LinkLuaModifier("modifier_phantom_assassin_contract_tracker", "abilities/phantom_assassin/ability_coup_de_foudre", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_phantom_assassin_contract_target", "abilities/phantom_assassin/ability_coup_de_foudre", LUA_MODIFIER_MOTION_NONE)

local PA_CONTRACT_TALENT_NAME = "special_bonus_unique_custom_phantom_assassin_3"
local PA_LOW_HP_SENSE_TALENT_NAME = "special_bonus_unique_custom_phantom_assassin_1"
local PA_TRACK_EFFECT = "particles/units/heroes/hero_bounty_hunter/bounty_hunter_track_shield.vpcf"

ability_coup_de_foudre = ability_coup_de_foudre or class({})

function ability_coup_de_foudre:Precache(context)
    -- Precache custom sounds
    PrecacheResource("soundfile", "soundevents/trinity_sounds.vsndevts", context)
    PrecacheResource("particle", PA_TRACK_EFFECT, context)
end

function ability_coup_de_foudre:GetIntrinsicModifierName()
    return "modifier_coup_de_foudre"
end

modifier_coup_de_foudre = modifier_coup_de_foudre or class({})

function modifier_coup_de_foudre:OnCreated(_)
    if not IsServer() then
        return
    end

    self.activation_delay = self:GetAbility():GetSpecialValueFor("activation_delay")
    self.dagger_buff_time = self:GetAbility():GetSpecialValueFor("dagger_buff_time")
    
    -- Table to track dagger projectiles cast with crit buff
    self.dagger_snapshots = {}
    
    -- Reset state to prevent issues on respawn/reconnect
    self.timer = nil
    self.modifier = nil
    self.contract_tracker = nil
    self.talent_low_hp_crit_pending = false

    self:StartIntervalThink(0.1)
end

function modifier_coup_de_foudre:OnDestroy()
    if not IsServer() then
        return
    end
    
    -- Clean up timer to prevent memory leaks in multiplayer
    if self.timer then
        Timers:RemoveTimer(self.timer)
        self.timer = nil
    end
    
    -- Clean up buff modifier
    if self.modifier and not self.modifier:IsNull() then
        self.modifier:Destroy()
        self.modifier = nil
    end

    if self.contract_tracker and not self.contract_tracker:IsNull() then
        self.contract_tracker:Destroy()
        self.contract_tracker = nil
    end
end

function modifier_coup_de_foudre:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_ABILITY_EXECUTED,
        MODIFIER_EVENT_ON_TAKEDAMAGE,
        MODIFIER_PROPERTY_PREATTACK_CRITICALSTRIKE,
        MODIFIER_EVENT_ON_ATTACK_LANDED,
    }  
end

function modifier_coup_de_foudre:HasLowHpSenseTalent(attacker)
    if not attacker or attacker:IsNull() then
        return false
    end
    local talent = attacker:FindAbilityByName(PA_LOW_HP_SENSE_TALENT_NAME)
    return talent and not talent:IsNull() and talent:GetLevel() > 0
end

function modifier_coup_de_foudre:IsEligibleLowHpHeroTarget(attacker, target)
    if not attacker or attacker:IsNull() or not target or target:IsNull() then
        return false
    end
    if target:IsBuilding() or target:IsOther() or target:GetTeam() == attacker:GetTeam() then
        return false
    end
    if not target:IsHero() then
        return false
    end
    local max_hp = target:GetMaxHealth()
    if max_hp <= 0 then
        return false
    end
    if target:GetHealth() / max_hp >= 0.5 then
        return false
    end
    return true
end

function modifier_coup_de_foudre:GetModifierPreAttack_CriticalStrike(params)
    if not IsServer() then
        return
    end

    self.talent_low_hp_crit_pending = false

    local parent = self:GetParent()
    if parent:PassivesDisabled() then
        return
    end

    local pa = params.attacker
    if pa ~= parent then
        return
    end

    if pa:HasModifier("modifier_coup_de_foudre_buff") then
        return
    end

    if not self:HasLowHpSenseTalent(pa) then
        return
    end

    local target = params.target
    if not self:IsEligibleLowHpHeroTarget(pa, target) then
        return
    end

    local ability = self:GetAbility()
    if not ability or ability:IsNull() then
        return
    end

    self.talent_low_hp_crit_pending = true
    return ability:GetSpecialValueFor("crit_bonus")
end

function modifier_coup_de_foudre:OnAttackLanded(params)
    if not IsServer() then
        return
    end
    if params.attacker ~= self:GetParent() then
        return
    end
    if not self.talent_low_hp_crit_pending then
        return
    end

    if params.ranged_attack then
        return
    end

    self.talent_low_hp_crit_pending = false
    EmitSoundOnLocationWithCaster(
        params.target:GetAbsOrigin(),
        "Hero_PhantomAssassin.CoupDeGrace",
        self:GetCaster()
    )
end

function modifier_coup_de_foudre:IsPurgable()
    return false  
end

function modifier_coup_de_foudre:IsHidden()
    return true 
end

function modifier_coup_de_foudre:OnAbilityExecuted(params)
    if not IsServer() then return end
    
    local caster = params.unit
    local ability = params.ability
    
    -- Check if it's our PA casting Stifling Dagger
    if not caster or caster:IsNull() then return end
    if caster ~= self:GetParent() then return end
    if not ability then return end
    
    local ability_name = ability:GetAbilityName()
    if ability_name ~= "phantom_assassin_stifling_dagger" then return end
    
    -- Snapshot: check if crit buff is active at cast time
    local has_crit_buff = caster:HasModifier("modifier_coup_de_foudre_buff")
    
    if has_crit_buff then
        local target = params.target
        if target and not target:IsNull() then
            -- Store snapshot with target and timestamp
            local snapshot = {
                target = target,
                time = GameRules:GetGameTime(),
                has_crit = true
            }
            table.insert(self.dagger_snapshots, snapshot)
            
            -- Clean up old snapshots (older than 5 seconds)
            self:CleanupOldSnapshots()
        end
    end
end

function modifier_coup_de_foudre:OnTakeDamage(params)
    if not IsServer() then return end
    
    local attacker = params.attacker
    local victim = params.unit
    local ability = params.inflictor
    
    -- Validate entities
    if not attacker or attacker:IsNull() then return end
    if not victim or victim:IsNull() then return end
    if attacker ~= self:GetParent() then return end
    if not ability then return end
    
    local ability_name = ability:GetAbilityName()
    if ability_name ~= "phantom_assassin_stifling_dagger" then return end
    
    -- Check if we have a snapshot for this target
    local snapshot = self:FindSnapshot(victim)
    if snapshot and snapshot.has_crit then
        -- Play crit sound (crit already applied by GetModifierPreAttack_CriticalStrike)
        EmitSoundOnLocationWithCaster(
            victim:GetAbsOrigin(),
            "Hero_PhantomAssassin.CoupDeGrace",
            attacker
        )
        
        -- Remove the snapshot after use
        self:RemoveSnapshot(victim)
        self.talent_low_hp_crit_pending = false
    elseif self.talent_low_hp_crit_pending
        and self:HasLowHpSenseTalent(attacker)
        and self:IsEligibleLowHpHeroTarget(attacker, victim) then
        EmitSoundOnLocationWithCaster(
            victim:GetAbsOrigin(),
            "Hero_PhantomAssassin.CoupDeGrace",
            attacker
        )
        self.talent_low_hp_crit_pending = false
    end
end

function modifier_coup_de_foudre:FindSnapshot(target)
    if not target or target:IsNull() then return nil end
    
    local current_time = GameRules:GetGameTime()
    
    for i, snapshot in ipairs(self.dagger_snapshots) do
        -- Check if snapshot target is still valid
        if snapshot.target and not snapshot.target:IsNull() and snapshot.target == target then
            -- Check if snapshot is still valid (within dagger_buff_time)
            if (current_time - snapshot.time) <= self.dagger_buff_time then
                return snapshot
            end
        end
    end
    
    return nil
end

function modifier_coup_de_foudre:RemoveSnapshot(target)
    for i = #self.dagger_snapshots, 1, -1 do
        if self.dagger_snapshots[i].target == target then
            table.remove(self.dagger_snapshots, i)
            return
        end
    end
end

function modifier_coup_de_foudre:CleanupOldSnapshots()
    local current_time = GameRules:GetGameTime()
    
    for i = #self.dagger_snapshots, 1, -1 do
        local snapshot = self.dagger_snapshots[i]
        -- Remove if too old or target is invalid
        if (current_time - snapshot.time) > 5.0 or 
           not snapshot.target or snapshot.target:IsNull() then
            table.remove(self.dagger_snapshots, i)
        end
    end
end



 
function modifier_coup_de_foudre:OnIntervalThink()
    if not IsServer() then return end
    
    local unit = self:GetCaster()
    if not unit or unit:IsNull() then return end

    self:UpdateContractTracker()
    
    local canBeSeen = unit:CanBeSeenByAnyOpposingTeam()
    local hasBlurActive = unit:HasModifier("modifier_phantom_assassin_blur_custom_active")
    
    if hasBlurActive then 
        self:AddBuff(unit)
        return
    end

    if not canBeSeen then
        self:AddBuff(unit)
    else 
        if not self.timer then 
            local parent = self:GetParent()
            self.timer = Timers:CreateTimer(self.activation_delay, function()
                -- Check if modifier still exists and is valid
                if self and not self:IsNull() and self.modifier and not self.modifier:IsNull() then 
                    self.modifier:Destroy()
                    self.modifier = nil
                end
                self.timer = nil
                return nil -- Stop timer
            end)
        end
    end
end

function modifier_coup_de_foudre:AddBuff(unit)
    if not unit or unit:IsNull() then return end
    
    -- Check if modifier exists and is still valid
    if not self.modifier or self.modifier:IsNull() then 
        self.modifier = unit:AddNewModifier(
            unit,
            self:GetAbility(),
            "modifier_coup_de_foudre_buff",
            {}
        )
    end
    
    -- Clean up timer if exists
    if self.timer then 
        Timers:RemoveTimer(self.timer)
        self.timer = nil
    end 
end

function modifier_coup_de_foudre:UpdateContractTracker()
    local parent = self:GetParent()
    if not parent or parent:IsNull() then
        return
    end

    if self.contract_tracker and self.contract_tracker:IsNull() then
        self.contract_tracker = nil
    end

    if parent:IsIllusion() then
        if self.contract_tracker then
            self.contract_tracker:Destroy()
            self.contract_tracker = nil
        end
        return
    end

    local talent = parent:FindAbilityByName(PA_CONTRACT_TALENT_NAME)
    if not talent or talent:IsNull() or talent:GetLevel() <= 0 then
        if self.contract_tracker then
            self.contract_tracker:Destroy()
            self.contract_tracker = nil
        end
        return
    end

    if not self.contract_tracker then
        self.contract_tracker = parent:AddNewModifier(
            parent,
            talent,
            "modifier_phantom_assassin_contract_tracker",
            {}
        )
    end
end

modifier_coup_de_foudre_buff = modifier_coup_de_foudre_buff or class({})

function modifier_coup_de_foudre_buff:OnCreated()
    self.is_crit = false
    
    if IsServer() then
        local parent = self:GetParent()
        
        -- Start sound and track start time
        self.sound_start_time = GameRules:GetGameTime()
        EmitSoundOn("Assassins_sense.ambient", parent)
        
        -- Check every 5 seconds if sound needs to be restarted
        self:StartIntervalThink(5.0)
    end
end

function modifier_coup_de_foudre_buff:OnIntervalThink()
    if not IsServer() then return end
    
    local current_time = GameRules:GetGameTime()
    local elapsed_time = current_time - self.sound_start_time
    
    -- If sound has been playing for 25+ seconds, restart it
    if elapsed_time >= 25.0 then
        local parent = self:GetParent()
        StopSoundOn("Assassins_sense.ambient", parent)
        EmitSoundOn("Assassins_sense.ambient", parent)
        self.sound_start_time = current_time
    end
end

function modifier_coup_de_foudre_buff:OnDestroy()
    if IsServer() then
        local parent = self:GetParent()
        StopSoundOn("Assassins_sense.ambient", parent)
    end
end

function modifier_coup_de_foudre_buff:IsPurgable()
    return false
end

function modifier_coup_de_foudre_buff:IsHidden()
    return false
end

function modifier_coup_de_foudre_buff:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_PREATTACK_CRITICALSTRIKE,
        MODIFIER_EVENT_ON_ATTACK_LANDED,
    }
end

function modifier_coup_de_foudre_buff:GetModifierPreAttack_CriticalStrike(params)
    if not IsServer() or self:GetParent():PassivesDisabled() then
        return
    end

    local pa = params.attacker

    if pa ~= self:GetParent() then
        return
    end

    local target = params.target
    if target:IsBuilding() or target:IsOther() or target:GetTeam() == pa:GetTeam() then
        return
    end

    local crit_bonus
    if target:IsHero() then
        crit_bonus = self:GetAbility():GetSpecialValueFor("crit_bonus")
    else
        crit_bonus = self:GetAbility():GetSpecialValueFor("crit_bonus_creeps")
    end

    self.is_crit = true
    return crit_bonus
end

function modifier_coup_de_foudre_buff:OnAttackLanded(params)
    if self:GetParent() == params.attacker and self.is_crit then

        EmitSoundOnLocationWithCaster(
                params.target:GetAbsOrigin(),
                "Hero_PhantomAssassin.CoupDeGrace",
                self:GetCaster()
        )

        self.is_crit = false
    end
end

modifier_phantom_assassin_contract_tracker = class({})

function modifier_phantom_assassin_contract_tracker:IsHidden()
    return true
end

function modifier_phantom_assassin_contract_tracker:IsPurgable()
    return false
end

function modifier_phantom_assassin_contract_tracker:RemoveOnDeath()
    return false
end

function modifier_phantom_assassin_contract_tracker:OnCreated()
    self.current_target = nil
    self.contract_end_time = 0
    self.next_roll_time = 0
    self.last_damage_time = -math.huge

    self:RefreshTalentValues()

    if not IsServer() then
        return
    end

    self.next_roll_time = GameRules:GetGameTime()
    self:StartIntervalThink(0.25)
end

function modifier_phantom_assassin_contract_tracker:OnRefresh()
    self:RefreshTalentValues()
end

function modifier_phantom_assassin_contract_tracker:OnDestroy()
    if not IsServer() then
        return
    end

    self:ClearCurrentTarget()
end

function modifier_phantom_assassin_contract_tracker:RefreshTalentValues()
    local ability = self:GetAbility()

    self.contract_duration = 60
    self.bonus_gold = 300
    self.assist_window = 13

    if ability and not ability:IsNull() then
        self.contract_duration = ability:GetSpecialValueFor("contract_duration") or self.contract_duration
        self.bonus_gold = ability:GetSpecialValueFor("bonus_gold") or self.bonus_gold
        self.assist_window = ability:GetSpecialValueFor("assist_window") or self.assist_window
    end
end

function modifier_phantom_assassin_contract_tracker:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_TAKEDAMAGE,
        MODIFIER_EVENT_ON_DEATH,
    }
end

function modifier_phantom_assassin_contract_tracker:OnIntervalThink()
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    local ability = self:GetAbility()
    if not parent or parent:IsNull() then
        self:Destroy()
        return
    end

    if parent:IsIllusion() or parent:IsTempestDouble() then
        self:Destroy()
        return
    end

    if not ability or ability:IsNull() or ability:GetLevel() <= 0 then
        self:Destroy()
        return
    end

    self:RefreshTalentValues()

    local current_time = GameRules:GetGameTime()

    if self.current_target and self.current_target:IsNull() then
        self.current_target = nil
    end

    if self.current_target then
        if current_time >= self.contract_end_time then
            self:FailCurrentContract(false)
            return
        end

        self:EnsureTargetMarker()
        return
    end

    if current_time >= self.next_roll_time then
        self:AssignNewTarget()
    end
end

function modifier_phantom_assassin_contract_tracker:OnTakeDamage(params)
    if not IsServer() then
        return
    end

    if not self.current_target or self.current_target:IsNull() then
        return
    end

    if params.unit ~= self.current_target then
        return
    end

    if params.damage <= 0 then
        return
    end

    if self:IsParentOwnedAttacker(params.attacker) then
        self.last_damage_time = GameRules:GetGameTime()
    end
end

function modifier_phantom_assassin_contract_tracker:OnDeath(params)
    if not IsServer() then
        return
    end

    if not self.current_target or self.current_target:IsNull() then
        return
    end

    if params.unit ~= self.current_target then
        return
    end

    if self:IsSuccessfulKill(params.attacker) or self:DidParentAssist() then
        self:CompleteCurrentContract()
        return
    end

    self:FailCurrentContract(true)
end

function modifier_phantom_assassin_contract_tracker:IsSuccessfulKill(attacker)
    return self:IsParentOwnedAttacker(attacker)
end

function modifier_phantom_assassin_contract_tracker:DidParentAssist()
    return (GameRules:GetGameTime() - self.last_damage_time) <= self.assist_window
end

function modifier_phantom_assassin_contract_tracker:IsParentOwnedAttacker(attacker)
    local parent = self:GetParent()
    if not attacker or attacker:IsNull() or not parent or parent:IsNull() then
        return false
    end

    if attacker == parent then
        return true
    end

    if attacker:GetOwner() == parent then
        return true
    end

    local parent_player_id = parent:GetPlayerOwnerID()
    local attacker_player_id = attacker:GetPlayerOwnerID()
    if parent_player_id ~= nil and parent_player_id ~= -1 and attacker_player_id == parent_player_id then
        return true
    end

    return false
end

function modifier_phantom_assassin_contract_tracker:IsValidTarget(hero)
    local parent = self:GetParent()

    if not hero or hero:IsNull() then
        return false
    end

    if hero == parent then
        return false
    end

    if not hero:IsRealHero() or hero:IsIllusion() or hero:IsTempestDouble() then
        return false
    end

    if not hero:IsAlive() or hero:IsOutOfGame() then
        return false
    end

    if hero:GetTeamNumber() == parent:GetTeamNumber() then
        return false
    end

    return true
end

function modifier_phantom_assassin_contract_tracker:AssignNewTarget()
    local candidates = {}

    for _, hero in ipairs(HeroList:GetAllHeroes()) do
        if self:IsValidTarget(hero) then
            table.insert(candidates, hero)
        end
    end

    if #candidates == 0 then
        self.next_roll_time = GameRules:GetGameTime() + 1.0
        return
    end

    local target = candidates[RandomInt(1, #candidates)]
    self.current_target = target
    self.contract_end_time = GameRules:GetGameTime() + self.contract_duration
    self.next_roll_time = self.contract_end_time
    self.last_damage_time = -math.huge

    self:EnsureTargetMarker()
end

function modifier_phantom_assassin_contract_tracker:EnsureTargetMarker()
    if not self.current_target or self.current_target:IsNull() then
        return
    end

    local duration = math.max(self.contract_end_time - GameRules:GetGameTime(), 0.1)
    local marker = self.current_target:FindModifierByNameAndCaster(
        "modifier_phantom_assassin_contract_target",
        self:GetParent()
    )

    if marker then
        marker:SetDuration(duration, true)
        return
    end

    self.current_target:AddNewModifier(
        self:GetParent(),
        self:GetAbility(),
        "modifier_phantom_assassin_contract_target",
        { duration = duration }
    )
end

function modifier_phantom_assassin_contract_tracker:ClearCurrentTarget()
    if self.current_target and not self.current_target:IsNull() then
        local marker = self.current_target:FindModifierByNameAndCaster(
            "modifier_phantom_assassin_contract_target",
            self:GetParent()
        )

        if marker then
            marker:Destroy()
        end
    end

    self.current_target = nil
    self.contract_end_time = 0
    self.last_damage_time = -math.huge
end

function modifier_phantom_assassin_contract_tracker:GrantContractGold()
    local parent = self:GetParent()
    local player = PlayerResource:GetPlayer(parent:GetPlayerOwnerID())

    parent:ModifyGold(self.bonus_gold, true, DOTA_ModifyGold_Unspecified)

    if player then
        SendOverheadEventMessage(player, OVERHEAD_ALERT_GOLD, parent, self.bonus_gold, nil)
    end
end

function modifier_phantom_assassin_contract_tracker:CompleteCurrentContract()
    self:GrantContractGold()
    self:ClearCurrentTarget()
    self.next_roll_time = GameRules:GetGameTime() + FrameTime()
end

function modifier_phantom_assassin_contract_tracker:FailCurrentContract(wait_until_end_of_contract)
    local next_roll_time = GameRules:GetGameTime() + FrameTime()
    if wait_until_end_of_contract and self.contract_end_time > GameRules:GetGameTime() then
        next_roll_time = self.contract_end_time
    end

    self:ClearCurrentTarget()
    self.next_roll_time = next_roll_time
end

modifier_phantom_assassin_contract_target = class({})

function modifier_phantom_assassin_contract_target:IsHidden()
    return true
end

function modifier_phantom_assassin_contract_target:IsDebuff()
    return true
end

function modifier_phantom_assassin_contract_target:IsPurgable()
    return false
end

function modifier_phantom_assassin_contract_target:RemoveOnDeath()
    return true
end

function modifier_phantom_assassin_contract_target:GetEffectName()
    return PA_TRACK_EFFECT
end

function modifier_phantom_assassin_contract_target:GetEffectAttachType()
    return PATTACH_OVERHEAD_FOLLOW
end
