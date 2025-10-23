LinkLuaModifier("modifier_juggernaut_bloodlust", "abilities/juggernaut/juggernaut_bloodlust", LUA_MODIFIER_MOTION_NONE)

juggernaut_bloodlust = class({})

function juggernaut_bloodlust:Precache(context)
	PrecacheResource("soundfile", "soundevents/trinity_sounds.vsndevts", context)
end

function juggernaut_bloodlust:OnSpellStart()
    local caster = self:GetCaster()
    local duration = self:GetSpecialValueFor("duration")
    
    -- Add the bloodlust modifier to the caster
    caster:AddNewModifier(caster, self, "modifier_juggernaut_bloodlust", {duration = duration})
    
    -- Play cast sounds
    StartSoundEvent("Jugger_mom.sound", caster)
    caster:EmitSound("Hero_Juggernaut.BladeFury.Start")
end

--------------------------------------------------------------------------------
-- Bloodlust Modifier
--------------------------------------------------------------------------------
modifier_juggernaut_bloodlust = class({})

function modifier_juggernaut_bloodlust:IsHidden()
    return false
end

function modifier_juggernaut_bloodlust:IsDebuff()
    return false
end

function modifier_juggernaut_bloodlust:IsPurgable()
    return true
end

function modifier_juggernaut_bloodlust:OnCreated(kv)
    if IsServer() then
        -- Create first flame particle effect immediately
        self.flame_particle_1 = ParticleManager:CreateParticle("particles/units/heroes/hero_mars/mars_arena_of_blood_heal_flame.vpcf", PATTACH_CUSTOMORIGIN, self:GetParent())
        
        -- Initialize circle variables
        self.circle_radius = 0
        self.rotation_speed = 2.0  -- radians per second
        self.angle_offset = 0
        self.start_time = GameRules:GetGameTime()
        self.second_flame_delay = 0.8  -- seconds delay for second flame
        self.flame_particle_2 = nil  -- Will be created later
        
        -- Start the circle thinking
        self:StartIntervalThink(0.03) -- Update every 0.03 seconds for smooth motion
    end
end

function modifier_juggernaut_bloodlust:OnIntervalThink()
    if IsServer() then
        local parent = self:GetParent()
        local parent_pos = parent:GetAbsOrigin()
        local current_time = GameRules:GetGameTime()
        local elapsed_time = current_time - self.start_time
        
        -- Update angle for first flame
        self.angle_offset = self.angle_offset + (self.rotation_speed * 0.03)
        
        -- Calculate position for first flame
        local angle_1 = self.angle_offset
        local pos_1 = parent_pos + Vector(
            math.cos(angle_1) * self.circle_radius,
            math.sin(angle_1) * self.circle_radius,
            50 -- Height above ground
        )
        
        -- Update first flame position
        ParticleManager:SetParticleControl(self.flame_particle_1, 0, pos_1)
        
        -- Create and update second flame after delay
        if elapsed_time >= self.second_flame_delay then
            -- Create second flame if it doesn't exist yet
            if not self.flame_particle_2 then
                self.flame_particle_2 = ParticleManager:CreateParticle("particles/units/heroes/hero_mars/mars_arena_of_blood_heal_flame.vpcf", PATTACH_CUSTOMORIGIN, self:GetParent())
            end
            
            -- Calculate second flame position (follows behind first flame by 120 degrees)
            local angle_2 = self.angle_offset - (math.pi * 2/3) -- 120 degrees behind
            local pos_2 = parent_pos + Vector(
                math.cos(angle_2) * self.circle_radius,
                math.sin(angle_2) * self.circle_radius,
                50 -- Height above ground
            )
            
            -- Update second flame position
            ParticleManager:SetParticleControl(self.flame_particle_2, 0, pos_2)
        end
    end
end

function modifier_juggernaut_bloodlust:OnDestroy()
    if IsServer() then
        -- Destroy flame particle effects when modifier expires
        if self.flame_particle_1 then
            ParticleManager:DestroyParticle(self.flame_particle_1, false)
            ParticleManager:ReleaseParticleIndex(self.flame_particle_1)
        end
        -- Only destroy second flame if it was created
        if self.flame_particle_2 then
            ParticleManager:DestroyParticle(self.flame_particle_2, false)
            ParticleManager:ReleaseParticleIndex(self.flame_particle_2)
        end
    end
end

function modifier_juggernaut_bloodlust:GetEffectName()
    return "particles/units/heroes/hero_juggernaut/juggernaut_blade_dance.vpcf"
end

function modifier_juggernaut_bloodlust:GetEffectAttachType()
    return PATTACH_ABSORIGIN_FOLLOW
end

function modifier_juggernaut_bloodlust:DeclareFunctions()
    local funcs = {
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
        MODIFIER_EVENT_ON_ATTACK_LANDED,
    }
    return funcs
end

function modifier_juggernaut_bloodlust:GetModifierAttackSpeedBonus_Constant()
    return self:GetAbility():GetSpecialValueFor("attack_speed_bonus")
end

function modifier_juggernaut_bloodlust:OnAttackLanded(params)
    if IsServer() then
        local attacker = params.attacker
        local ability = self:GetAbility()
        
        -- Check if the attacker is the modifier owner
        if attacker == self:GetParent() then
            local heal_base = ability:GetSpecialValueFor("heal_per_attack")
            local mind_power_multiplier = ability:GetSpecialValueFor("mind_power_heal_multiplier")
            
            -- Get caster's mind power
            local mind_power = 0
            local mind_power_modifier = attacker:FindModifierByName("modifier_mind_power")
            if mind_power_modifier then
                mind_power = mind_power_modifier:GetStackCount()
            end
            
            -- Calculate total healing with mind power scaling
            local total_heal = heal_base + (mind_power * mind_power_multiplier)
            
            -- Heal the caster
            if total_heal > 0 then
                attacker:Heal(total_heal, ability)
                
                -- Create healing particle effect
                local heal_particle = ParticleManager:CreateParticle("particles/generic_gameplay/generic_lifesteal.vpcf", PATTACH_ABSORIGIN_FOLLOW, attacker)
                ParticleManager:SetParticleControl(heal_particle, 0, attacker:GetAbsOrigin())
                ParticleManager:ReleaseParticleIndex(heal_particle)
                
                -- Show healing number
                SendOverheadEventMessage(nil, OVERHEAD_ALERT_HEAL, attacker, total_heal, nil)
            end
        end
    end
end

function modifier_juggernaut_bloodlust:GetTexture()
    return "juggernaut_blade_dance"
end 