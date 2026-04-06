print("[Mage Slayer] Script loading")
LinkLuaModifier("modifier_item_mage_slayer", "items/item_mage_slayer", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_mage_slayer_debuff", "items/item_mage_slayer", LUA_MODIFIER_MOTION_NONE)

-- Дебаг: true = показывать сообщения на экране (ShowMessage), false = только print в консоль
local MAGE_SLAYER_DEBUG_SCREEN = true

-- Обход: OnAttackLanded не срабатывает для intrinsic modifier предмета.
-- Используем SetDamageFilter — вызывается при любом уроне, можно применить дебафф.
local _mage_slayer_debug_count = 0
function MageSlayer_DamageFilter(event)
    if not IsServer() then return true end
    -- Дебаг: вывести ключи первых 2 событий
    _mage_slayer_debug_count = _mage_slayer_debug_count + 1
    if _mage_slayer_debug_count <= 2 then
        local keys_str = ""
        for k, v in pairs(event) do keys_str = keys_str .. tostring(k) .. "=" .. tostring(v) .. " " end
        print("[Mage Slayer] DamageFilter #" .. _mage_slayer_debug_count .. " keys: " .. keys_str)
        if MAGE_SLAYER_DEBUG_SCREEN and ShowMessage then ShowMessage("[Mage Slayer] DmgFilter #" .. _mage_slayer_debug_count) end
    end
    local victim_idx = event.entindex_victim_const or event.entindex_victim
    local attacker_idx = event.entindex_attacker_const or event.entindex_attacker
    local victim = victim_idx and EntIndexToHScript(victim_idx) or nil
    local attacker = attacker_idx and EntIndexToHScript(attacker_idx) or nil
    if not victim or victim:IsNull() or not attacker or attacker:IsNull() then return true end
    if victim:IsInvulnerable() or victim:IsBuilding() then return true end
    if not (victim:IsHero() or victim:IsCreep()) then return true end
    if not attacker:IsHero() then return true end

    local mage_slayer = nil
    for i = 0, 8 do
        local item = attacker:GetItemInSlot(i)
        if item and item:GetName() == "item_mage_slayer" then
            mage_slayer = item
            break
        end
    end
    if not mage_slayer then return true end

    -- Только физический урон (атаки)
    local dmg_type = event.damagetype_const or event.damage_type or event.damagetype
    if dmg_type and dmg_type ~= DAMAGE_TYPE_PHYSICAL then return true end

    local duration = mage_slayer:GetSpecialValueFor("duration")
    victim:AddNewModifier(attacker, mage_slayer, "modifier_item_mage_slayer_debuff", { duration = duration })

    local msg = "[Mage Slayer] DamageFilter debuff -> " .. victim:GetUnitName() .. " " .. duration .. "s"
    print(msg)
    if MAGE_SLAYER_DEBUG_SCREEN and ShowMessage then ShowMessage(msg) end
    return true
end

item_mage_slayer = class({})

function item_mage_slayer:GetIntrinsicModifierName()
    return "modifier_item_mage_slayer"
end

-- ============================================================
-- Пассивный баф владельца предмета
-- ============================================================
modifier_item_mage_slayer = class({
    IsHidden      = function(self) return false end,
    IsPurgable    = function(self) return false end,
    IsBuff        = function(self) return true end,
    RemoveOnDeath = function(self) return false end,
})

function modifier_item_mage_slayer:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_ATTACK_LANDED,
        MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS,
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
        MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
        MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
        MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
    }
end

function modifier_item_mage_slayer:OnAttackLanded(params)
    -- Дебаг: самый первый лог — вызывается ли вообще колбэк
    local a = params.attacker and not params.attacker:IsNull() and params.attacker:GetUnitName() or "nil"
    local t = params.target and not params.target:IsNull() and params.target:GetUnitName() or "nil"
    local dbg = "[Mage Slayer] OnAttackLanded CALLED a=" .. a .. " t=" .. t .. " IsSrv=" .. tostring(IsServer())
    print(dbg)
    if MAGE_SLAYER_DEBUG_SCREEN and IsServer() and ShowMessage then ShowMessage(dbg) end

    if not IsServer() then return end
    if params.attacker ~= self:GetParent() then return end

    local target = params.target
    if not target or target:IsNull() then return end
    if target:IsInvulnerable() or target:IsBuilding() then return end
    if not (target:IsHero() or target:IsCreep()) then return end

    local ability = self:GetAbility()
    if not ability or ability:IsNull() then return end

    local duration = ability:GetSpecialValueFor("duration")
    local msg = "[Mage Slayer] OnAttackLanded: debuff -> " .. target:GetUnitName() .. " " .. duration .. "s"
    print(msg)
    if MAGE_SLAYER_DEBUG_SCREEN and ShowMessage then ShowMessage(msg) end
    target:AddNewModifier(self:GetParent(), ability, "modifier_item_mage_slayer_debuff", { duration = duration })
end

function modifier_item_mage_slayer:GetTexture()
    return "item_mage_slayer"
end

function modifier_item_mage_slayer:GetModifierMagicalResistanceBonus()
    local ability = self:GetAbility()
    return ability and ability:GetSpecialValueFor("bonus_magical_armor") or 0
end

function modifier_item_mage_slayer:GetModifierAttackSpeedBonus_Constant()
    local ability = self:GetAbility()
    return ability and ability:GetSpecialValueFor("bonus_attack_speed") or 0
end

function modifier_item_mage_slayer:GetModifierConstantHealthRegen()
    local ability = self:GetAbility()
    return ability and ability:GetSpecialValueFor("bonus_health_regen") or 0
end

function modifier_item_mage_slayer:GetModifierConstantManaRegen()
    local ability = self:GetAbility()
    return ability and ability:GetSpecialValueFor("bonus_mana_regen") or 0
end

function modifier_item_mage_slayer:GetModifierPreAttack_BonusDamage()
    local ability = self:GetAbility()
    return ability and ability:GetSpecialValueFor("bonus_damage") or 0
end

-- ============================================================
-- Дебафф на цель (снижение Mind Power + DPS)
-- ============================================================
modifier_item_mage_slayer_debuff = class({
    IsHidden      = function(self) return false end,
    IsPurgable    = function(self) return true end,
    IsBuff        = function(self) return false end,
    IsDebuff      = function(self) return true end,
    RemoveOnDeath = function(self) return true end,
})

function modifier_item_mage_slayer_debuff:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_TOOLTIP
    }
end

function modifier_item_mage_slayer_debuff:GetTexture()
    return "item_mage_slayer"
end

function modifier_item_mage_slayer_debuff:OnCreated()
    local ability = self:GetAbility()
    self.mind_power_debuff = (ability and not ability:IsNull()) and ability:GetSpecialValueFor("mind_power_debuff") or 40
    local msg = "[Mage Slayer Debuff] OnCreated: " .. self:GetParent():GetUnitName() .. " MP-" .. (self.mind_power_debuff or 0)
    if MAGE_SLAYER_DEBUG_SCREEN and IsServer() and ShowMessage then ShowMessage(msg) end
    if not IsServer() then return end
    local dps = (ability and not ability:IsNull()) and ability:GetSpecialValueFor("dps") or 0
    self:SetStackCount(math.max(0, math.floor(dps)))
    self:StartIntervalThink(1.0)
end

function modifier_item_mage_slayer_debuff:OnRefresh()
    local ability = self:GetAbility()
    self.mind_power_debuff = (ability and not ability:IsNull()) and ability:GetSpecialValueFor("mind_power_debuff") or 40
    local msg = "[Mage Slayer Debuff] OnRefresh: " .. self:GetParent():GetUnitName() .. " MP-" .. (self.mind_power_debuff or 0)
    if MAGE_SLAYER_DEBUG_SCREEN and IsServer() and ShowMessage then ShowMessage(msg) end
    if not IsServer() then return end
    local dps = (ability and not ability:IsNull()) and ability:GetSpecialValueFor("dps") or 0
    self:SetStackCount(math.max(0, math.floor(dps)))
    self:StartIntervalThink(1.0)
end

function modifier_item_mage_slayer_debuff:OnDestroy()
    if IsServer() then
        local parent = self:GetParent()
        if parent and not parent:IsNull() then
            print("[Mage Slayer Debuff] OnDestroy: target=" .. parent:GetUnitName())
        end
    end
end

function modifier_item_mage_slayer_debuff:OnIntervalThink()
    local parent = self:GetParent()
    if not parent or parent:IsNull() then return end

    local ability = self:GetAbility()
    local dps = self:GetStackCount()

    if dps > 0 then
        print("[Mage Slayer Buff] OnIntervalThink: DPS " .. dps .. " to " .. parent:GetUnitName())
        ApplyDamage({
            victim    = parent,
            attacker  = self:GetCaster(),
            damage    = dps,
            damage_type = DAMAGE_TYPE_MAGICAL,
            ability   = ability,
        })
    end
end

-- Регистрация в глобальном реестре Mind Power.
-- GetModifierMindPowerBonus() не вызывается напрямую движком — значение
-- читается через реестр по имени модификатора в GetHeroMindPower().
MIND_POWER_MODIFIER_REGISTRY = MIND_POWER_MODIFIER_REGISTRY or {}
MIND_POWER_MODIFIER_REGISTRY["modifier_item_mage_slayer_debuff"] = function(modifier)
    local ability = modifier:GetAbility()
    return -((ability and not ability:IsNull()) and ability:GetSpecialValueFor("mind_power_debuff") or 0)
end

-- Регистрация DamageFilter (обход: OnAttackLanded не работает для предметов)
if Timers then
    Timers:CreateTimer(0.5, function()
        local gm = GameRules and GameRules:GetGameModeEntity()
        if gm and gm.SetDamageFilter then
            gm:SetDamageFilter(MageSlayer_DamageFilter, nil)
            if MAGE_SLAYER_DEBUG_SCREEN and ShowMessage then ShowMessage("[Mage Slayer] DamageFilter OK") end
        else
            print("[Mage Slayer] ERROR: SetDamageFilter not available")
        end
        return nil
    end)
end

function modifier_item_mage_slayer_debuff:OnTooltip()
    return self:GetStackCount()
end
