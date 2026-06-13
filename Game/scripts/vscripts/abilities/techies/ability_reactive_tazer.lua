LinkLuaModifier("modifier_reactive_tazer_buff", "abilities/techies/ability_reactive_tazer", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_reactive_tazer_disarm", "abilities/techies/ability_reactive_tazer", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_reactive_tazer_attacker_arc", "abilities/techies/ability_reactive_tazer", LUA_MODIFIER_MOTION_NONE)

local TAZER_P_AMBIENT = "particles/units/heroes/hero_techies/techies_tazer_ambient.vpcf"
local TAZER_P_ARCS_WRAP = "particles/units/heroes/hero_techies/techies_tazer_ambient_arcs_wrap.vpcf"
local TAZER_P_ARCS_WRAP_INV = "particles/units/heroes/hero_techies/techies_tazer_ambient_arcs_wrap_inverted.vpcf"
local TAZER_P_COUNTDOWN = "particles/units/heroes/hero_techies/techies_tazer_countdown.vpcf"
local TAZER_P_EXPLODE = "particles/units/heroes/hero_techies/techies_tazer_explode.vpcf"

ability_reactive_tazer = ability_reactive_tazer or class({})

function ability_reactive_tazer:GetDamage()
    local caster = self:GetCaster()
    local base_damage = self:GetSpecialValueFor("damage")
    local mind_power_multiplier = self:GetSpecialValueFor("mind_power_multiplier")
    local mind_power = 0

    if GetHeroMindPower then
        mind_power = GetHeroMindPower(caster) or 0
    elseif caster and caster.GetIntellect then
        mind_power = caster:GetIntellect(false) or 0
    end

    return math.max(0, base_damage + (mind_power * mind_power_multiplier))
end

function ability_reactive_tazer:OnSpellStart()
    local caster = self:GetCaster()
    if not caster or caster:IsNull() or not caster:IsAlive() then
        return
    end

    local duration = self:GetSpecialValueFor("buff_duration")
    caster:AddNewModifier(caster, self, "modifier_reactive_tazer_buff", { duration = duration })
    EmitFOWSoundOnUnit(caster, "Hero_Techies.ReactiveTazer.Cast")
end

modifier_reactive_tazer_buff = modifier_reactive_tazer_buff or class({})

function modifier_reactive_tazer_buff:OnCreated()
    self.countdown_fx = nil
    self:OnRefresh()
    if IsServer() then
        self:CreateTazerBuffParticles()
        self:StartIntervalThink(0.1)
        local parent = self:GetParent()
        if parent and not parent:IsNull() then
            parent:EmitSound("Hero_Techies.ReactiveTazer.Loop")
        end
    end
end

function modifier_reactive_tazer_buff:OnRefresh()
    local ability = self:GetAbility()
    if not ability or ability:IsNull() then
        return
    end

    self.ms_bonus = ability:GetSpecialValueFor("bonus_movespeed_pct")
    self.disarm_duration = ability:GetSpecialValueFor("disarm_duration")
    self.radius = ability:GetSpecialValueFor("explosion_radius")

    if IsServer() then
        local dur = self:GetRemainingTime()
        if dur <= 0 then
            dur = self:GetDuration()
        end
        if dur <= 0 then
            dur = ability:GetSpecialValueFor("buff_duration")
        end
        self.end_time = GameRules:GetGameTime() + dur
    end
end

function modifier_reactive_tazer_buff:CreateTazerBuffParticles()
    local parent = self:GetParent()
    if not parent or parent:IsNull() then
        return
    end

    local function add(path)
        local idx = ParticleManager:CreateParticle(path, PATTACH_ABSORIGIN_FOLLOW, parent)
        self:AddParticle(idx, false, false, -1, false, false)
    end

    add(TAZER_P_AMBIENT)
    add(TAZER_P_ARCS_WRAP)
end

function modifier_reactive_tazer_buff:DestroyTazerBuffParticles()
    if self.countdown_fx then
        DestroyFOWParticleForTeams(self.countdown_fx)
        self.countdown_fx = nil
    end
end

function modifier_reactive_tazer_buff:IsHidden()
    return false
end

function modifier_reactive_tazer_buff:IsPurgable()
    return true
end

function modifier_reactive_tazer_buff:IsBuff()
    return true
end

function modifier_reactive_tazer_buff:GetTexture()
    return "techies_reactive_tazer"
end

function modifier_reactive_tazer_buff:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
        MODIFIER_EVENT_ON_ATTACKED,
    }
end

function modifier_reactive_tazer_buff:GetModifierMoveSpeedBonus_Percentage()
    return self.ms_bonus or 0
end

function modifier_reactive_tazer_buff:OnIntervalThink()
    if not IsServer() then
        return
    end

    local ability = self:GetAbility()
    if not ability or ability:IsNull() or not self.end_time then
        return
    end

    local lead = ability:GetSpecialValueFor("countdown_lead")
    local time_left = self.end_time - GameRules:GetGameTime()

    if time_left > lead + 0.05 then
        if self.countdown_fx then
            DestroyFOWParticleForTeams(self.countdown_fx)
            self.countdown_fx = nil
        end
    elseif time_left > 0 and time_left <= lead and not self.countdown_fx then
        local parent = self:GetParent()
        if parent and not parent:IsNull() then
            self.countdown_fx = CreateFOWParticleForTeams(
                TAZER_P_COUNTDOWN,
                PATTACH_ABSORIGIN_FOLLOW,
                parent,
                parent:GetAbsOrigin()
            )
        end
    end
end

function modifier_reactive_tazer_buff:OnAttacked(params)
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    local ability = self:GetAbility()
    local attacker = params.attacker

    if not parent or parent:IsNull() or params.target ~= parent then
        return
    end

    if not ability or ability:IsNull() or not attacker or attacker:IsNull() or not attacker:IsAlive() then
        return
    end

    if attacker:IsMagicImmune() or attacker:IsInvulnerable() then
        return
    end

    local filter = UnitFilter(
        attacker,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE,
        parent:GetTeamNumber()
    )

    if filter ~= UF_SUCCESS then
        return
    end

    local caster = self:GetCaster()
    if not caster or caster:IsNull() then
        return
    end

    local damage = ability:GetDamage()

    ApplyDamage({
        victim = attacker,
        attacker = caster,
        damage = damage,
        damage_type = DAMAGE_TYPE_MAGICAL,
        ability = ability,
    })

    attacker:Purge(true, false, false, false, false)
    attacker:AddNewModifier(caster, ability, "modifier_reactive_tazer_disarm", { duration = self.disarm_duration })
    attacker:AddNewModifier(caster, ability, "modifier_reactive_tazer_attacker_arc", { duration = self.disarm_duration })

    EmitFOWSoundOnUnit(attacker, "Hero_Zuus.ArcLightning.Cast")
end

function modifier_reactive_tazer_buff:OnDestroy()
    if not IsServer() then
        return
    end

    self:StartIntervalThink(-1)

    local parent = self:GetParent()
    if parent and not parent:IsNull() then
        StopSoundOn("Hero_Techies.ReactiveTazer.Loop", parent)
    end

    self:DestroyTazerBuffParticles()

    local parent = self:GetParent()
    local ability = self:GetAbility()
    local caster = self:GetCaster()

    if not parent or parent:IsNull() or not ability or ability:IsNull() then
        return
    end

    local now = GameRules:GetGameTime()
    local natural = self.end_time and now >= self.end_time - 0.05

    if not natural then
        return
    end

    if not caster or caster:IsNull() then
        return
    end

    local origin = parent:GetAbsOrigin()
    local radius = self.radius or ability:GetSpecialValueFor("explosion_radius")
    local damage = ability:GetDamage()
    local disarm_dur = ability:GetSpecialValueFor("disarm_duration")

    CreateFOWParticle(TAZER_P_EXPLODE, PATTACH_WORLDORIGIN, nil, origin, function(fx)
        ParticleManager:SetParticleControl(fx, 0, origin)
        ParticleManager:SetParticleControl(fx, 1, Vector(radius, radius, radius))
    end)

    EmitFOWSoundAtLocation(origin, "Hero_Techies.ReactiveTazer.Detonate")

    local enemies = FindUnitsInRadius(
        caster:GetTeamNumber(),
        origin,
        nil,
        radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )

    for _, enemy in ipairs(enemies) do
        if enemy and not enemy:IsNull() and enemy:IsAlive() and not enemy:IsMagicImmune() and not enemy:IsInvulnerable() then
            ApplyDamage({
                victim = enemy,
                attacker = caster,
                damage = damage,
                damage_type = DAMAGE_TYPE_MAGICAL,
                ability = ability,
            })
            enemy:AddNewModifier(caster, ability, "modifier_reactive_tazer_disarm", { duration = disarm_dur })
        end
    end
end

modifier_reactive_tazer_disarm = modifier_reactive_tazer_disarm or class({})

function modifier_reactive_tazer_disarm:IsHidden()
    return false
end

function modifier_reactive_tazer_disarm:IsDebuff()
    return true
end

function modifier_reactive_tazer_disarm:IsPurgable()
    return true
end

function modifier_reactive_tazer_disarm:GetTexture()
    return "techies_reactive_tazer"
end

function modifier_reactive_tazer_disarm:CheckState()
    return {
        [MODIFIER_STATE_DISARMED] = true,
    }
end

modifier_reactive_tazer_attacker_arc = modifier_reactive_tazer_attacker_arc or class({})

function modifier_reactive_tazer_attacker_arc:IsHidden()
    return true
end

function modifier_reactive_tazer_attacker_arc:IsDebuff()
    return true
end

function modifier_reactive_tazer_attacker_arc:IsPurgable()
    return true
end

function modifier_reactive_tazer_attacker_arc:OnCreated()
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if not parent or parent:IsNull() then
        return
    end

    local idx = ParticleManager:CreateParticle(TAZER_P_ARCS_WRAP_INV, PATTACH_ABSORIGIN_FOLLOW, parent)
    self:AddParticle(idx, false, false, -1, false, false)
end

function modifier_reactive_tazer_attacker_arc:OnRefresh()
end
