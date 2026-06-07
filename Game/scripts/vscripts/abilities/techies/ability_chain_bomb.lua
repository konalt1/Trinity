LinkLuaModifier("modifier_ability_chain_bomb_mine", "abilities/techies/ability_chain_bomb", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_ability_chain_bomb_mine_immobile", "abilities/techies/ability_chain_bomb", LUA_MODIFIER_MOTION_NONE)

ability_chain_bomb = ability_chain_bomb or class({})

local CHAIN_BOMB_MODEL = "models/heroes/techies/fx_techies_remotebomb.vmdl"

function ability_chain_bomb:Precache(context)
    PrecacheResource("model", CHAIN_BOMB_MODEL, context)
end

function ability_chain_bomb:OnSpellStart()
    local caster = self:GetCaster()
    local point = GetGroundPosition(self:GetCursorPosition(), nil)
    local mine = CreateUnitByName("npc_dota3_chainbomb", point, true, caster, caster, DOTA_TEAM_NEUTRALS)

    if not mine then
        return
    end

    self:SetupMine(mine)
end

function ability_chain_bomb:ApplyMineMovementState(mine)
    if not IsServer() or not mine or mine:IsNull() then
        return
    end

    local owner = mine:GetOwner()
    if not owner or owner:IsNull() then
        local owner_index = mine.chain_bomb_owner_entindex
        if owner_index then
            owner = EntIndexToHScript(owner_index)
        end
    end

    if not owner or owner:IsNull() then
        return
    end

    local ability = self
    if not ability or ability:IsNull() then
        ability = owner.FindAbilityByName and owner:FindAbilityByName("ability_chain_bomb") or nil
    end

    local speed = 0
    if owner:IsRealHero() and owner:HasScepter() and ability and not ability:IsNull() then
        speed = ability:GetSpecialValueFor("scepter_mine_movespeed")
    end

    -- Движение в KV должно быть GROUND — иначе клиент считает юнит неподвижным и отклоняет приказы
    -- (SetMoveCapability на сервере этого не исправляет). Без скипетра держим ROOT + скорость 0.
    local immobile = "modifier_ability_chain_bomb_mine_immobile"
    if speed > 0 then
        mine:RemoveModifierByName(immobile)
        mine:SetBaseMoveSpeed(speed)
    else
        mine:Stop()
        mine:SetBaseMoveSpeed(0)
        if not mine:FindModifierByName(immobile) then
            mine:AddNewModifier(owner, ability, immobile, {})
        end
    end
end

function ability_chain_bomb:SetupMine(mine)
    local caster = self:GetCaster()

    mine:SetOwner(caster)
    mine:SetControllableByPlayer(caster:GetPlayerID(), true)
    mine:SetBaseMaxHealth(10)
    mine:SetMaxHealth(10)
    mine:SetHealth(10)
    mine:SetModel(CHAIN_BOMB_MODEL)
    mine:SetOriginalModel(CHAIN_BOMB_MODEL)
    mine:SetModelScale(0.75)
    mine:SetRenderColor(80, 255, 80)
    mine.chain_bomb_owner_entindex = caster:entindex()
    mine.chain_bomb_owner_team = caster:GetTeamNumber()

    mine:AddNewModifier(caster, self, "modifier_ability_chain_bomb_mine", {})

    self:ApplyMineMovementState(mine)

    EmitSoundOnLocationWithCaster(mine:GetAbsOrigin(), "Hero_Techies.RemoteMine.Plant", caster)
end

function ability_chain_bomb:GetMineDamage()
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

function ability_chain_bomb:DetonateMine(mine, source_attacker)
    if not IsServer() or not mine or mine:IsNull() then
        return
    end

    if mine.chain_bomb_detonating then
        return
    end

    mine.chain_bomb_detonating = true

    local caster = self:GetCaster()
    local owner_team = mine.chain_bomb_owner_team or caster:GetTeamNumber()
    local enemy_team = owner_team == DOTA_TEAM_GOODGUYS and DOTA_TEAM_BADGUYS or DOTA_TEAM_GOODGUYS
    local origin = mine:GetAbsOrigin()
    local hero_for_aoe = caster
    local owner_index = mine.chain_bomb_owner_entindex
    if owner_index then
        local owner = EntIndexToHScript(owner_index)
        if owner and not owner:IsNull() and owner:IsHero() then
            hero_for_aoe = owner
        end
    end
    local base_radius = self:GetSpecialValueFor("radius")
    local aoe_flat = GetHeroBonusSpellAoE and GetHeroBonusSpellAoE(hero_for_aoe) or 0
    local radius = base_radius + aoe_flat
    local damage = self:GetMineDamage()
    local building_damage_pct = self:GetSpecialValueFor("building_damage_pct") * 0.01
    local neutral_attacker = source_attacker or mine

    local fx = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_techies/techies_remote_mines_detonate.vpcf",
        PATTACH_WORLDORIGIN,
        nil
    )
    ParticleManager:SetParticleControl(fx, 0, origin)
    ParticleManager:SetParticleControl(fx, 1, Vector(radius, radius, radius))
    ParticleManager:ReleaseParticleIndex(fx)

    EmitSoundOnLocationWithCaster(origin, "Hero_Techies.RemoteMine.Detonate", caster)

    local enemies = FindUnitsInRadius(
        enemy_team,
        origin,
        nil,
        radius,
        DOTA_UNIT_TARGET_TEAM_FRIENDLY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC + DOTA_UNIT_TARGET_BUILDING,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )

    for _, enemy in ipairs(enemies) do
        local current_damage = damage

        if enemy:IsBuilding() then
            current_damage = current_damage * building_damage_pct
        end

        ApplyDamage({
            victim = enemy,
            attacker = caster,
            damage = current_damage,
            damage_type = DAMAGE_TYPE_MAGICAL,
            ability = self,
        })
    end

    local neutral_units = FindUnitsInRadius(
        DOTA_TEAM_NEUTRALS,
        origin,
        nil,
        radius,
        DOTA_UNIT_TARGET_TEAM_FRIENDLY,
        DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER,
        false
    )

    for _, neutral_unit in ipairs(neutral_units) do
        if neutral_unit ~= mine then
            ApplyDamage({
                victim = neutral_unit,
                attacker = neutral_attacker,
                damage = damage,
                damage_type = DAMAGE_TYPE_MAGICAL,
                ability = self,
            })
        end
    end

    if mine:IsAlive() then
        mine:ForceKill(false)
    end
end

modifier_ability_chain_bomb_mine = modifier_ability_chain_bomb_mine or class({})

function modifier_ability_chain_bomb_mine:IsHidden()
    return true
end

function modifier_ability_chain_bomb_mine:IsPurgable()
    return false
end

function modifier_ability_chain_bomb_mine:GetPriority()
    return MODIFIER_PRIORITY_HIGH
end

function modifier_ability_chain_bomb_mine:OnCreated()
    self.fade_delay = self:GetAbility():GetSpecialValueFor("fade_delay")
    self.created_at = GameRules:GetGameTime()
    self:SetStackCount(0)

    if not IsServer() then
        return
    end

    self:StartIntervalThink(0.2)
end

function modifier_ability_chain_bomb_mine:OnIntervalThink()
    if not IsServer() then
        return
    end

    if self:GetStackCount() == 0 and GameRules:GetGameTime() >= self.created_at + self.fade_delay then
        self:SetStackCount(1)
    end

    local ability = self:GetAbility()
    if ability and not ability:IsNull() then
        ability:ApplyMineMovementState(self:GetParent())
    end

    local vision_radius = 50
    if ability and not ability:IsNull() then
        vision_radius = ability:GetSpecialValueFor("mine_vision_radius")
    end

    local owner = self:GetMineOwner()
    if owner and not owner:IsNull() and owner:IsRealHero() and owner:HasModifier("modifier_item_aghanims_shard") then
        if ability and not ability:IsNull() then
            local shard_radius = ability:GetSpecialValueFor("shard_vision_radius")
            if shard_radius > 0 then
                vision_radius = shard_radius
            end
        end
    end

    AddFOWViewer(self:GetMineOwnerTeam(), self:GetParent():GetAbsOrigin(), vision_radius, 0.25, false)
end

function modifier_ability_chain_bomb_mine:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_INVISIBILITY_LEVEL,
        MODIFIER_PROPERTY_INCOMING_DAMAGE_PERCENTAGE,
        MODIFIER_EVENT_ON_DEATH,
    }
end

function modifier_ability_chain_bomb_mine:GetModifierInvisibilityLevel()
    return 0
end

function modifier_ability_chain_bomb_mine:GetMineOwner()
    local parent = self:GetParent()
    local owner_index = parent.chain_bomb_owner_entindex

    if not owner_index then
        return self:GetCaster()
    end

    local owner = EntIndexToHScript(owner_index)
    if owner and not owner:IsNull() then
        return owner
    end

    return self:GetCaster()
end

function modifier_ability_chain_bomb_mine:GetMineOwnerTeam()
    local parent = self:GetParent()
    return parent.chain_bomb_owner_team or (self:GetCaster() and self:GetCaster():GetTeamNumber()) or DOTA_TEAM_NEUTRALS
end

function modifier_ability_chain_bomb_mine:IsMineFromSameOwner(attacker)
    if not attacker or attacker:IsNull() or attacker:GetUnitName() ~= self:GetParent():GetUnitName() then
        return false
    end

    local attacker_modifier = attacker:FindModifierByName("modifier_ability_chain_bomb_mine")
    if not attacker_modifier then
        return false
    end

    return attacker_modifier:GetMineOwnerTeam() == self:GetMineOwnerTeam()
end

function modifier_ability_chain_bomb_mine:IsFriendlyTrigger(attacker)
    local owner = self:GetMineOwner()

    if not attacker or attacker:IsNull() then
        return false
    end

    if owner and attacker == owner then
        return true
    end

    return self:IsMineFromSameOwner(attacker)
end

function modifier_ability_chain_bomb_mine:GetModifierIncomingDamage_Percentage(params)
    if not IsServer() or params.target ~= self:GetParent() then
        return 0
    end

    local attacker = params.attacker

    if self:IsFriendlyTrigger(attacker) then
        return 0
    end

    if attacker and attacker:GetTeamNumber() == self:GetMineOwnerTeam() then
        return -100
    end

    if params.damage_type ~= DAMAGE_TYPE_PHYSICAL then
        return -100
    end

    return 0
end

function modifier_ability_chain_bomb_mine:OnDeath(event)
    if not IsServer() or event.unit ~= self:GetParent() then
        return
    end

    if self.death_handled then
        return
    end

    local attacker = event.attacker
    if not self:IsFriendlyTrigger(attacker) then
        return
    end

    self.death_handled = true
    local ability = self:GetAbility()
    local mine = self:GetParent()
    local attacker_index = attacker and not attacker:IsNull() and attacker:entindex() or nil

    Timers:CreateTimer(0.1, function()
        if not ability or ability:IsNull() or not mine or mine:IsNull() then
            return nil
        end

        local delayed_attacker = nil
        if attacker_index then
            delayed_attacker = EntIndexToHScript(attacker_index)
        end

        ability:DetonateMine(mine, delayed_attacker)
        return nil
    end)
end

function modifier_ability_chain_bomb_mine:Detonate(attacker)
    local ability = self:GetAbility()

    if not ability or ability:IsNull() then
        return
    end

    ability:DetonateMine(self:GetParent(), attacker)
end

function modifier_ability_chain_bomb_mine:CheckState()
    return {
        [MODIFIER_STATE_INVISIBLE] = self:GetStackCount() == 1,
        [MODIFIER_STATE_NO_UNIT_COLLISION] = true,
        [MODIFIER_STATE_NOT_ON_MINIMAP_FOR_ENEMIES] = true,
        [MODIFIER_STATE_SPECIALLY_DENIABLE] = true,
    }
end

modifier_ability_chain_bomb_mine_immobile = modifier_ability_chain_bomb_mine_immobile or class({})

function modifier_ability_chain_bomb_mine_immobile:IsHidden()
    return true
end

function modifier_ability_chain_bomb_mine_immobile:IsPurgable()
    return false
end

function modifier_ability_chain_bomb_mine_immobile:CheckState()
    return {
        [MODIFIER_STATE_ROOTED] = true,
    }
end
