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

    self:StartIntervalThink(0.1)
end

function modifier_coup_de_foudre:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_ABILITY_EXECUTED,
        MODIFIER_EVENT_ON_TAKEDAMAGE,
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
    if caster ~= self:GetParent() then return end
    if not ability then return end
    
    local ability_name = ability:GetAbilityName()
    if ability_name ~= "phantom_assassin_stifling_dagger" then return end
    
    -- Snapshot: check if crit buff is active at cast time
    local has_crit_buff = caster:HasModifier("modifier_coup_de_foudre_buff")
    
    if has_crit_buff then
        local target = params.target
        if target then
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
    
    -- Check if PA is dealing damage with Stifling Dagger
    if attacker ~= self:GetParent() then return end
    if not ability then return end
    
    local ability_name = ability:GetAbilityName()
    if ability_name ~= "phantom_assassin_stifling_dagger" then return end
    
    -- Check if we have a snapshot for this target
    local snapshot = self:FindSnapshot(victim)
    if snapshot and snapshot.has_crit then
        -- Apply additional crit damage
        local crit_bonus = self:GetAbility():GetSpecialValueFor("crit_bonus")
        local base_damage = params.original_damage
        
        -- Calculate additional damage (crit multiplier - 100%)
        local additional_damage = base_damage * ((crit_bonus - 100) / 100)
        
        if additional_damage > 0 then
            ApplyDamage({
                victim = victim,
                attacker = attacker,
                damage = additional_damage,
                damage_type = DAMAGE_TYPE_PHYSICAL,
                damage_flags = DOTA_DAMAGE_FLAG_NO_SPELL_AMPLIFICATION,
                ability = self:GetAbility()
            })
            
            -- Play crit sound
            EmitSoundOnLocationWithCaster(
                victim:GetAbsOrigin(),
                "Hero_PhantomAssassin.CoupDeGrace",
                attacker
            )
        end
        
        -- Remove the snapshot after use
        self:RemoveSnapshot(victim)
    end
end

function modifier_coup_de_foudre:FindSnapshot(target)
    local current_time = GameRules:GetGameTime()
    
    for i, snapshot in ipairs(self.dagger_snapshots) do
        if snapshot.target == target then
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
        if (current_time - self.dagger_snapshots[i].time) > 5.0 then
            table.remove(self.dagger_snapshots, i)
        end
    end
end



 
function modifier_coup_de_foudre:OnIntervalThink()
    local unit = self:GetCaster()
    local canBeSeen = unit:CanBeSeenByAnyOpposingTeam()
    local hasBlurActive = unit:HasModifier("modifier_phantom_assassin_blur_active")
    
    if hasBlurActive then 
        self:AddBuff(unit)
        return
    end

    if not canBeSeen then
        self:AddBuff(unit)
    else 
        if not self.timer then 
            self.timer = Timers:CreateTimer(self.activation_delay, function()
                if self.modifier then 
                    self.modifier:Destroy()
                    self.modifier = nil
                end
                self.timer = nil
            end)
        end
    end
end

function modifier_coup_de_foudre:AddBuff(unit)
    if not self.modifier then 
        self.modifier = unit:AddNewModifier(
            unit,
            self:GetAbility(),
            "modifier_coup_de_foudre_buff",
            {}
        )
    end
    
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
    if not target:IsHero() or target:GetTeam() == pa:GetTeam() then
        return
    end
    local crit_bonus = self:GetAbility():GetSpecialValueFor("crit_bonus")
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
