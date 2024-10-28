LinkLuaModifier("modifier_lycan_wolfes_custom_buff", "abilities/lycan/lycan_summon_wolves_custom", LUA_MODIFIER_MOTION_NONE)

lycan_summon_wolves_custom = class({})

function lycan_summon_wolves_custom:OnSpellStart()
    local caster = self:GetCaster()
    local wolfCount = self:GetSpecialValueFor("wolf_count")
    local wolfIndex = self:GetSpecialValueFor("wolf_index") 
    local wolfDuration = self:GetSpecialValueFor("wolf_duration")
    local wolfHp = self:GetSpecialValueFor("wolf_hp")
    local wolfDamage = self:GetSpecialValueFor("wolf_damage")
    local wolfBat = self:GetSpecialValueFor("wolf_bat")
    if not caster.wolves then caster.wolves = {} end

    if not HasShard(caster) then
        for _,wolf in ipairs(caster.wolves) do
            if IsValidEntity(wolf) and wolf:IsAlive() then 
                wolf:ForceKill(false)
            end
        end
        caster.wolves = {}
    end 
 
    for i = 1, wolfCount do
        local point = caster:GetAbsOrigin() + RandomVector(100)
        local wolf = CreateUnitByName("npc_dota_lycan_wolf" .. wolfIndex, point, true, caster, caster, caster:GetTeamNumber())
        table.insert(caster.wolves, wolf)
        wolf:SetOwner(caster)
        wolf:SetControllableByPlayer(caster:GetPlayerID(), true)
        FindClearSpaceForUnit(wolf, point, false)
        local nFXIndex = ParticleManager:CreateParticle( "particles/units/heroes/hero_lycan/lycan_summon_wolves_cast.vpcf", PATTACH_CUSTOMORIGIN, self:GetCaster() )
        ParticleManager:SetParticleControlEnt( nFXIndex, 0, self:GetCaster(), PATTACH_POINT_FOLLOW, "attach_attack1", self:GetCaster():GetAbsOrigin(), true )
        ParticleManager:ReleaseParticleIndex( nFXIndex )
        ParticleManager:ReleaseParticleIndex(  ParticleManager:CreateParticle( "particles/units/heroes/hero_lycan/lycan_summon_wolves_spawn.vpcf", PATTACH_ABSORIGIN_FOLLOW, wolf ) )

        wolf:AddNewModifier(caster, self, "modifier_kill", {duration = wolfDuration})
        
        if HasShard(caster) then
            wolf:AddNewModifier(caster, self, "modifier_lycan_wolfes_custom_buff", {})
        end

        wolf:SetBaseMaxHealth(wolfHp)
        wolf:SetBaseAttackTime(wolfBat)
        wolf:SetBaseDamageMin(wolfDamage)
        wolf:SetBaseDamageMax(wolfDamage)
    end

    
    
    EmitSoundOn("Hero_Lycan.SummonWolves", caster)
end

modifier_lycan_wolfes_custom_buff = class({})

function modifier_lycan_wolfes_custom_buff:IsHidden() return true end
function modifier_lycan_wolfes_custom_buff:IsPurgable() return false end
function modifier_lycan_wolfes_custom_buff:RemoveOnDeath() return false end

function modifier_lycan_wolfes_custom_buff:DeclareFunctions()
    return { MODIFIER_EVENT_ON_ATTACK_LANDED }
end

function modifier_lycan_wolfes_custom_buff:OnAttackLanded(params)
    if params.attacker == self:GetParent() then
        local target = params.target
        local duration = 0
        local ability = self:GetAbility()

        if target:IsHero() then
            duration = ability:GetSpecialValueFor("hero_attack_second_shard")
        elseif target:IsCreep() then
            duration = ability:GetSpecialValueFor("creep_attack_second")
        else 
            return
        end
        local modifier = self:GetParent():FindModifierByName("modifier_kill")
        local currentDuration = modifier:GetRemainingTime()
        modifier:SetDuration(currentDuration + duration, true)
    end
end

 