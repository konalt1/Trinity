LinkLuaModifier("modifier_techies_parry_blast_buff", "abilities/techies/ability_techies_parry_blast", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_techies_parry_blast_disarm", "abilities/techies/ability_techies_parry_blast", LUA_MODIFIER_MOTION_NONE)

local PARRY_P_EXPLODE = "particles/techies/techies_tazer_explode.vpcf"

ability_techies_parry_blast = ability_techies_parry_blast or class({})

function ability_techies_parry_blast:Precache(context)
	PrecacheResource("particle", PARRY_P_EXPLODE, context)
end

function ability_techies_parry_blast:GetAOERadius()
    return self:GetSpecialValueFor("explosion_radius")
end

function ability_techies_parry_blast:OnSpellStart()
    if not IsServer() then
        return
    end

    local caster = self:GetCaster()
    if not caster or caster:IsNull() or not caster:IsAlive() then
        return
    end

    local origin = caster:GetAbsOrigin()
    local radius = self:GetSpecialValueFor("explosion_radius")
    local damage = self:GetSpecialValueFor("damage")
    local buff_duration = self:GetSpecialValueFor("buff_duration")

    CreateFOWParticle(PARRY_P_EXPLODE, PATTACH_WORLDORIGIN, nil, origin, function(fx)
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
                ability = self,
            })
        end
    end

    caster:AddNewModifier(caster, self, "modifier_techies_parry_blast_buff", { duration = buff_duration })
    EmitFOWSoundOnUnit(caster, "Hero_Techies.ReactiveTazer.Cast")
end

modifier_techies_parry_blast_buff = modifier_techies_parry_blast_buff or class({})

function modifier_techies_parry_blast_buff:IsHidden()
    return false
end

function modifier_techies_parry_blast_buff:IsPurgable()
    return true
end

function modifier_techies_parry_blast_buff:IsDebuff()
    return false
end

function modifier_techies_parry_blast_buff:IsBuff()
    return true
end

function modifier_techies_parry_blast_buff:GetTexture()
    return "techies_blast_off"
end

function modifier_techies_parry_blast_buff:OnCreated()
    local ability = self:GetAbility()
    if not ability or ability:IsNull() then
        return
    end

    self.bonus_armor = ability:GetSpecialValueFor("bonus_armor")
    self.disarm_duration = ability:GetSpecialValueFor("disarm_duration")
end

function modifier_techies_parry_blast_buff:OnRefresh()
    local ability = self:GetAbility()
    if not ability or ability:IsNull() then
        return
    end

    self.bonus_armor = ability:GetSpecialValueFor("bonus_armor")
    self.disarm_duration = ability:GetSpecialValueFor("disarm_duration")
end

function modifier_techies_parry_blast_buff:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS,
        MODIFIER_EVENT_ON_ATTACKED,
        MODIFIER_EVENT_ON_TAKEDAMAGE,
    }
end

function modifier_techies_parry_blast_buff:GetModifierPhysicalArmorBonus()
    return self.bonus_armor or 0
end

function modifier_techies_parry_blast_buff:TryDisarmAttacker(attacker)
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    local ability = self:GetAbility()
    local caster = self:GetCaster()

    if not parent or parent:IsNull() or not ability or ability:IsNull() then
        return
    end

    if not attacker or attacker:IsNull() or not attacker:IsAlive() then
        return
    end

    if attacker == parent then
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

    if not caster or caster:IsNull() then
        return
    end

    attacker:AddNewModifier(caster, ability, "modifier_techies_parry_blast_disarm", { duration = self.disarm_duration })
    EmitFOWSoundOnUnit(attacker, "Hero_Zuus.ArcLightning.Cast")
end

function modifier_techies_parry_blast_buff:OnAttacked(params)
    if not IsServer() then
        return
    end

    if params.target ~= self:GetParent() then
        return
    end

    self:TryDisarmAttacker(params.attacker)
end

function modifier_techies_parry_blast_buff:OnTakeDamage(params)
    if not IsServer() then
        return
    end

    if params.unit ~= self:GetParent() then
        return
    end

    if params.damage <= 0 then
        return
    end

    self:TryDisarmAttacker(params.attacker)
end

modifier_techies_parry_blast_disarm = modifier_techies_parry_blast_disarm or class({})

function modifier_techies_parry_blast_disarm:IsHidden()
    return false
end

function modifier_techies_parry_blast_disarm:IsDebuff()
    return true
end

function modifier_techies_parry_blast_disarm:IsPurgable()
    return true
end

function modifier_techies_parry_blast_disarm:GetTexture()
    return "techies_blast_off"
end

function modifier_techies_parry_blast_disarm:CheckState()
    return {
        [MODIFIER_STATE_DISARMED] = true,
    }
end
