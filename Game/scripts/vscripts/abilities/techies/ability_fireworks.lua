LinkLuaModifier("modifier_fireworks", "abilities/techies/ability_fireworks", 0)
LinkLuaModifier("modifier_fireworks_tracker", "abilities/techies/ability_fireworks", LUA_MODIFIER_MOTION_NONE)

-- Снаряд атаки на время баффа (стандартный путь Techies в клиенте Dota 2)
local FIREWORKS_ATTACK_PROJECTILE = "particles/units/heroes/hero_techies/techies_base_attack.vpcf"
local FIREWORKS_CHARGE_ARC = "particles/units/heroes/hero_techies/techies_tazer_ambient_arcs_wrap.vpcf"

local CHARGED_RECORDS_KEY = "_fireworks_charged_attack_records"

local function fireworks_get_charged_table(parent)
    if not parent or parent:IsNull() then
        return nil
    end
    parent[CHARGED_RECORDS_KEY] = parent[CHARGED_RECORDS_KEY] or {}
    return parent[CHARGED_RECORDS_KEY]
end

local function fireworks_is_valid_proc_target(target)
    if not target or target:IsNull() then
        return false
    end
    if target:IsBuilding() or target:IsOther() then
        return false
    end
    return target:IsHero() or target:IsCreep()
end

local function fireworks_play_impact(attacker, visual_radius, origin)
    CreateFOWParticle(
        "particles/units/heroes/hero_techies/techies_remote_mines_detonate.vpcf",
        PATTACH_WORLDORIGIN,
        nil,
        origin,
        function(fx)
            ParticleManager:SetParticleControl(fx, 0, origin)
            ParticleManager:SetParticleControl(fx, 1, Vector(visual_radius, visual_radius, visual_radius))
        end
    )

    EmitFOWSoundAtLocation(origin, "Hero_Techies.RemoteMine.Detonate")
end

local function fireworks_apply_proc_damage(params)
    local victim = params.victim
    local attacker = params.attacker
    local ability = params.ability
    local physical = params.physical or 0
    local magical = params.magical or 0

    if physical > 0 then
        ApplyDamage({
            victim = victim,
            attacker = attacker,
            damage = physical,
            damage_type = DAMAGE_TYPE_PHYSICAL,
            ability = ability,
        })
    end
    if magical > 0 then
        ApplyDamage({
            victim = victim,
            attacker = attacker,
            damage = magical,
            damage_type = DAMAGE_TYPE_MAGICAL,
            ability = ability,
        })
    end
end

--- Взрыв: параметры с текущего уровня ability_fireworks на момент попадания.
local function fireworks_run_proc(attacker, ability, target, attack_dmg)
    if not attacker or attacker:IsNull() or not ability or ability:IsNull() then
        return
    end
    if not fireworks_is_valid_proc_target(target) then
        return
    end

    if attack_dmg <= 0 and attacker.GetAverageTrueAttackDamage then
        attack_dmg = attacker:GetAverageTrueAttackDamage(target) or 0
    end

    local splash_radius = ability:GetSpecialValueFor("splash_radius")
    local visual_radius = ability:GetLevelSpecialValueFor("splash_radius", ability:GetLevel())
    local splash_pct = ability:GetSpecialValueFor("splash_attack_damage_pct") / 100
    local magic_bonus = ability:GetMindScaledMagicDamage()
    local splash_phys = attack_dmg * splash_pct
    local origin = target:GetAbsOrigin()

    local enemies = FindUnitsInRadius(
        attacker:GetTeamNumber(),
        origin,
        nil,
        splash_radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )

    fireworks_play_impact(attacker, visual_radius, origin)

    for _, enemy in ipairs(enemies) do
        if fireworks_is_valid_proc_target(enemy) then
            local phys = enemy == target and 0 or splash_phys
            fireworks_apply_proc_damage({
                victim = enemy,
                attacker = attacker,
                ability = ability,
                physical = phys,
                magical = magic_bonus,
            })
        end
    end
end

ability_fireworks = ability_fireworks or class({})

local SOUND_FUSE = "techies.fireworks.fuse"
local SOUND_SHOT = "techies.fireworks.shot"

function ability_fireworks:Precache(context)
	PrecacheResource("soundfile", "soundevents/trinity_sounds.vsndevts", context)
end

function ability_fireworks:GetIntrinsicModifierName()
    return "modifier_fireworks_tracker"
end

function ability_fireworks:GetAOERadius()
    return self:GetSpecialValueFor("splash_radius")
end

function ability_fireworks:OnSpellStart()
    local caster = self:GetCaster()
    local duration = self:GetSpecialValueFor("duration")

    if caster:HasModifier("modifier_fireworks") then
        StopSoundOn(SOUND_FUSE, caster)
    end
    caster:AddNewModifier(caster, self, "modifier_fireworks", { duration = duration })
    EmitSoundOn(SOUND_FUSE, caster)
end

function ability_fireworks:GetMindPower()
    local caster = self:GetCaster()
    if GetHeroMindPower then
        return GetHeroMindPower(caster) or 0
    end
    if caster and caster.GetIntellect then
        return caster:GetIntellect(false) or 0
    end
    return 0
end

--- Магическая часть взрыва: базовый маг. урон по уровню + Сила Магии × множитель
function ability_fireworks:GetMindScaledMagicDamage()
    local bonus_magic = self:GetSpecialValueFor("bonus_magic_damage")
    local mult = self:GetSpecialValueFor("mind_power_multiplier")
    local mind = self:GetMindPower()
    return math.max(0, bonus_magic + mind * mult)
end

--------------------------------------------------------------------------------
-- Видимый бафф: дальность, партиклы, пометка выстрелов (record), снаряд
--------------------------------------------------------------------------------
modifier_fireworks = modifier_fireworks or class({})

function modifier_fireworks:OnCreated()
    self:OnRefresh()
    if IsServer() then
        self:CreateFireworksChargeParticles()
    end
end

function modifier_fireworks:OnRefresh()
    local ability = self:GetAbility()
    if not ability or ability:IsNull() then
        return
    end

    self.splash_radius = ability:GetSpecialValueFor("splash_radius")
    self.bonus_attack_range = ability:GetSpecialValueFor("bonus_attack_range")
    self.splash_attack_damage_pct = ability:GetSpecialValueFor("splash_attack_damage_pct")
end

function modifier_fireworks:OnDestroy()
    if not IsServer() then
        return
    end
    local parent = self:GetParent()
    if parent and not parent:IsNull() then
        StopSoundOn(SOUND_FUSE, parent)
    end
    self:DestroyFireworksChargeParticles()
end

function modifier_fireworks:CreateFireworksChargeParticles()
    local parent = self:GetParent()
    if not parent or parent:IsNull() then
        return
    end

    local idx = ParticleManager:CreateParticle(FIREWORKS_CHARGE_ARC, PATTACH_ABSORIGIN_FOLLOW, parent)
    self:AddParticle(idx, false, false, -1, false, false)
end

function modifier_fireworks:DestroyFireworksChargeParticles()
end

function modifier_fireworks:IsHidden()
    return false
end

function modifier_fireworks:IsPurgable()
    return true
end

function modifier_fireworks:IsBuff()
    return true
end

function modifier_fireworks:GetTexture()
    return "fireworks"
end

function modifier_fireworks:GetEffectAttachType()
    return PATTACH_ABSORIGIN_FOLLOW
end

function modifier_fireworks:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_ATTACK,
        MODIFIER_EVENT_ON_ATTACK_RECORD,
        MODIFIER_PROPERTY_ATTACK_RANGE_BONUS,
        MODIFIER_PROPERTY_PROJECTILE_NAME,
    }
end

--- Помечаем только атаки, начатые пока бафф активен (в т.ч. запись снаряда).
--- Звук выстрела: OnAttack ближе к вылету снаряда, чем OnAttackRecord.
function modifier_fireworks:OnAttack(params)
    if not IsServer() then
        return
    end
    local parent = self:GetParent()
    if params.attacker ~= parent then
        return
    end
    EmitFOWSoundOnUnit(parent, SOUND_SHOT)
end

function modifier_fireworks:OnAttackRecord(params)
    if not IsServer() then
        return
    end
    local parent = self:GetParent()
    if params.attacker ~= parent or not params.record then
        return
    end
    local t = fireworks_get_charged_table(parent)
    if t then
        t[params.record] = true
    end
end

function modifier_fireworks:GetModifierProjectileName()
    return FIREWORKS_ATTACK_PROJECTILE
end

function modifier_fireworks:GetModifierAttackRangeBonus()
    return self.bonus_attack_range or 0
end

--------------------------------------------------------------------------------
-- Скрытый трекер: взрыв по помеченному record при попадании, даже без баффа
--------------------------------------------------------------------------------
modifier_fireworks_tracker = modifier_fireworks_tracker or class({})

function modifier_fireworks_tracker:IsHidden()
    return true
end

function modifier_fireworks_tracker:IsPurgable()
    return false
end

function modifier_fireworks_tracker:RemoveOnDeath()
    return false
end

function modifier_fireworks_tracker:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_TAKEDAMAGE,
        MODIFIER_EVENT_ON_ATTACK_RECORD_DESTROY,
        MODIFIER_EVENT_ON_DEATH,
    }
end

function modifier_fireworks_tracker:OnAttackRecordDestroy(params)
    if not IsServer() then
        return
    end
    if params.attacker ~= self:GetParent() or not params.record then
        return
    end
    local parent = self:GetParent()
    local t = parent[CHARGED_RECORDS_KEY]
    if t then
        t[params.record] = nil
    end
end

function modifier_fireworks_tracker:OnDeath(params)
    if not IsServer() then
        return
    end
    local parent = self:GetParent()
    if parent and not parent:IsNull() and params.unit == parent then
        parent[CHARGED_RECORDS_KEY] = {}
    end
end

function modifier_fireworks_tracker:OnTakeDamage(keys)
    if not IsServer() then
        return
    end

    local parent = self:GetParent()
    if not parent or parent:IsNull() or keys.attacker ~= parent then
        return
    end

    if not keys.unit or keys.unit:IsNull() then
        return
    end

    if keys.damage_category ~= DOTA_DAMAGE_CATEGORY_ATTACK then
        return
    end

    if (keys.damage or 0) <= 0 then
        return
    end

    local flags = keys.damage_flags or 0
    if bit.band(flags, DOTA_DAMAGE_FLAG_SECONDARY_PROJECTILE_ATTACK) == DOTA_DAMAGE_FLAG_SECONDARY_PROJECTILE_ATTACK then
        return
    end

    if not keys.record then
        return
    end

    local charged = parent[CHARGED_RECORDS_KEY]
    if not charged or not charged[keys.record] then
        return
    end

    local ability = parent:FindAbilityByName("ability_fireworks")
    if not ability or ability:IsNull() or ability:GetLevel() <= 0 then
        charged[keys.record] = nil
        return
    end

    if not fireworks_is_valid_proc_target(keys.unit) then
        return
    end

    charged[keys.record] = nil

    local attack_dmg = keys.original_damage or keys.damage or 0
    fireworks_run_proc(parent, ability, keys.unit, attack_dmg)
end
