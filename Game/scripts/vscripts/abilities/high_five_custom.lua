LinkLuaModifier('modifier_high_five_search', 'abilities/high_five_custom', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier('modifier_dummy', 'abilities/high_five_custom', LUA_MODIFIER_MOTION_NONE)

high_five_custom = class({})

function high_five_custom:Precache(context)
    PrecacheResource( "particle", "particles/econ/events/plus/high_five/high_five_impact.vpcf", context )
end

function high_five_custom:Spawn()
    if IsClient() then return end
    self:SetLevel(1)
end

function high_five_custom:IsHiddenAbilityCastable()
    return true
end

function high_five_custom:OnSpellStart()
    local caster = self:GetCaster()
    if not caster:IsAlive() then return end
    if caster:HasModifier("modifier_high_five_search") then return end

    caster:AddNewModifier(caster, self, "modifier_high_five_search", {duration = self:GetSpecialValueFor("request_duration")})

    caster:EmitSound("high_five.cast");
end

function high_five_custom:OnProjectileHit(target, _)
    local caster = self:GetCaster()

    if not self.dummy then return end

    local particle = ParticleManager:CreateParticle("particles/econ/events/plus/high_five/high_five_impact.vpcf", PATTACH_ABSORIGIN_FOLLOW, self.dummy)
    ParticleManager:SetParticleControl(particle, 3, self.dummy:GetAbsOrigin())
    ParticleManager:ReleaseParticleIndex(particle)

    EmitSoundOn("high_five.impact", self.dummy)
    self.dummy:ForceKill(false)

    self:EndCooldown()
    self:StartCooldown(self:GetSpecialValueFor("acknowledged_cooldown"))

    self.target = nil
end

function high_five_custom:IsStealable()
    return false

end
 
modifier_high_five_search = class({
    IsHidden                 = function(self) return true end,
    IsPurgable                 = function(self) return false end,
    GetEffectName              = function(self) return "particles/econ/events/plus/high_five/high_five_lvl1_overhead.vpcf" end,
    GetEffectAttachType        = function(self) return PATTACH_OVERHEAD_FOLLOW end,
})

function modifier_high_five_search:OnCreated()
    local ability = self:GetAbility()
    self.findRadius = ability:GetSpecialValueFor("acknowledge_range")
    self.speed = ability:GetSpecialValueFor("high_five_speed")
    self.parent = self:GetParent()

    self:StartIntervalThink(ability:GetSpecialValueFor("think_interval"))
end

function modifier_high_five_search:OnDestroy()
    if IsClient() or self.finded then return end

    local towers = FindUnitsInRadius(
        self.parent:GetTeamNumber(),
        self.parent:GetAbsOrigin(),
        nil, self.findRadius, DOTA_UNIT_TARGET_TEAM_BOTH,
        DOTA_UNIT_TARGET_BUILDING, DOTA_UNIT_TARGET_FLAG_INVULNERABLE,
        FIND_CLOSEST, false
    )

    local towerFind

    for _,tower in ipairs(towers) do
        if (tower:HasAttackCapability() and tower:GetAttackCapability() == DOTA_UNIT_CAP_RANGED_ATTACK and tower:GetClassname() ~= "ent_dota_fountain") or tower:IsFort() then 
            towerFind = tower
            break
        end
    end

    if towerFind then 
        self.finded = true
        local towerOrigin = towerFind:GetAbsOrigin()
        local parentOrigin = self.parent:GetAbsOrigin()

        local center = (towerOrigin + parentOrigin) / 2

        local dummy = CreateDummy(center)

        local ability = self:GetAbility()
        ability.dummy = dummy
        ability.target = towerFind

        local info = {
            Source = self.parent,
            Ability = ability,
            vSpawnOrigin = parentOrigin,
            EffectName = "particles/econ/events/plus/high_five/high_five_lvl1_travel.vpcf",
            fDistance = (center - parentOrigin):Length(),
            fStartRadius = 10,
            fEndRadius = 10,
            vVelocity = (center - parentOrigin):Normalized() * self.speed
        }

        ProjectileManager:CreateLinearProjectile(info)

        info.Source = towerFind
        info.vSpawnOrigin = towerOrigin
        info.fDistance = (center - towerOrigin):Length()
        info.vVelocity = (center - towerOrigin):Normalized() * self.speed
        ProjectileManager:CreateLinearProjectile(info)
    else 
        self.parent:EmitSound("high_five.fail")
    end
end

function modifier_high_five_search:OnIntervalThink()
    if IsClient() then return end

    local units = FindUnitsInRadius(
        self.parent:GetTeamNumber(),
        self.parent:GetAbsOrigin(),
        nil, self.findRadius, DOTA_UNIT_TARGET_TEAM_BOTH,
        DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_INVULNERABLE + DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
        FIND_CLOSEST, false
    )

    local unitFind

    for _,unit in ipairs(units) do
        if unit:HasModifier("modifier_high_five_search") and unit ~= self.parent then 
            unitFind = unit
            break
        end
    end

    if unitFind then 
        self.finded = true

        local unitAbility = unitFind:FindAbilityByName("high_five_custom")
        local unitOrigin = unitFind:GetAbsOrigin()
        local unitModifier = unitFind:FindModifierByName("modifier_high_five_search")
        local parentOrigin = self.parent:GetAbsOrigin()

        local center = (unitOrigin + parentOrigin) / 2

        local dummy = CreateDummy(center)

        local ability = self:GetAbility()
        ability.dummy = dummy
        ability.target = towerFind
        unitAbility.dummy = dummy

        local info = {
            Source = self.parent,
            Ability = ability,
            vSpawnOrigin = parentOrigin,
            EffectName = "particles/econ/events/plus/high_five/high_five_lvl1_travel.vpcf",
            fDistance = (center - parentOrigin):Length(),
            fStartRadius = 10,
            fEndRadius = 10,
            vVelocity = (center - parentOrigin):Normalized() * self.speed
        }

        ProjectileManager:CreateLinearProjectile(info)

        info.Source = unitFind
        info.Ability = unitAbility
        info.vSpawnOrigin = unitOrigin
        info.fDistance = (center - unitOrigin):Length()
        info.vVelocity = (center - unitOrigin):Normalized() * self.speed
        ProjectileManager:CreateLinearProjectile(info)  

        self:Destroy()
        unitModifier.finded = true
        unitModifier:Destroy()
    end
end
 
 

function CreateDummy(origin, team)
    if origin == nil then origin = Vector(0, 0, 0) end
    if team == nil then team = DOTA_TEAM_NEUTRALS end

    local dummy = CreateUnitByName("npc_dummy_unit", origin, false, nil, nil, team);

    dummy:AddNewModifier(unit, nil, "modifier_dummy", {})
    dummy:AddNewModifier(unit, nil, "modifier_phased", {})

    return dummy
end

modifier_dummy = class({
    IsHidden                 = function(self) return true end,
    IsPurgable                 = function(self) return false end,
    GetAttributes            =  function(self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
    CheckState      = function(self) return 
    {
        [MODIFIER_STATE_INVULNERABLE] = true,
        [MODIFIER_STATE_UNSELECTABLE] = true,
        [MODIFIER_STATE_NOT_ON_MINIMAP] = true,
        [MODIFIER_STATE_NO_HEALTH_BAR] = true,
        [MODIFIER_STATE_OUT_OF_GAME] = true,
    } end,
})