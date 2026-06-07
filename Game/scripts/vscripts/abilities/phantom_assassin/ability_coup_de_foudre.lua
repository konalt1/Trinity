LinkLuaModifier("modifier_coup_de_foudre", "abilities/phantom_assassin/ability_coup_de_foudre", 0)
LinkLuaModifier("modifier_coup_de_foudre_buff", "abilities/phantom_assassin/ability_coup_de_foudre", 0)

ability_coup_de_foudre = ability_coup_de_foudre or class({})

function ability_coup_de_foudre:Precache(context)
    -- Precache custom sounds
    PrecacheResource("soundfile", "soundevents/trinity_sounds.vsndevts", context)
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
end

function modifier_coup_de_foudre:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_ABILITY_EXECUTED,
        MODIFIER_EVENT_ON_TAKEDAMAGE,
        MODIFIER_EVENT_ON_DEATH,
    }  
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
    end
end

function modifier_coup_de_foudre:OnDeath(params)
    if not IsServer() then return end

    local parent = self:GetParent()
    local victim = params.unit
    local attacker = params.attacker

    if not parent or parent:IsNull() or parent:IsIllusion() then return end
    if not victim or victim:IsNull() or not victim:IsRealHero() then return end
    if not attacker or attacker:IsNull() or attacker ~= parent then return end
    if victim:GetTeamNumber() == parent:GetTeamNumber() then return end
    if not parent:HasScepter() then return end

    self:ResetHeroAbilityCooldowns()
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

function modifier_coup_de_foudre:ResetHeroAbilityCooldowns()
    local parent = self:GetParent()
    if not parent or parent:IsNull() then return end

    for slot = 0, 23 do
        local ability = parent:GetAbilityByIndex(slot)

        if ability
            and not ability:IsNull()
            and not ability:IsItem()
            and ability:GetAbilityName() ~= "generic_hidden"
            and ability:GetCooldownTimeRemaining() > 0 then
            ability:EndCooldown()
        end
    end
end



 
function modifier_coup_de_foudre:OnIntervalThink()
    if not IsServer() then return end
    
    local unit = self:GetCaster()
    if not unit or unit:IsNull() then return end
    
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
    if target:IsRealHero() then
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
