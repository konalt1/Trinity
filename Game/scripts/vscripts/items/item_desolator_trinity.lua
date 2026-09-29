-- Trinity: Desolator и Stygian Desolator (Lua-версии, общий модуль).
--   * Пассив: бонус к урону + заряды. Убийство вражеского героя даёт bonus_damage_per_kill зарядов,
--     помощь (по правилам KillfeedSystem) — bonus_damage_per_assist. 1 заряд = +1 к урону, максимум max_damage.
--   * Атаки снижают броню цели на corruption_armor на corruption_duration сек. Эффекты разных
--     Desolator не складываются: действует самый сильный.
--   * Stygian Desolator собирается из Desolator и забирает его заряды.
-- Значения берутся из KV (npc_items_custom.txt, "item_desolator" / "item_desolator_2").

LinkLuaModifier("modifier_item_desolator_trinity", "items/item_desolator_trinity", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_desolator_trinity_corruption", "items/item_desolator_trinity", LUA_MODIFIER_MOTION_NONE)

local PROJECTILE = "particles/items_fx/desolator_projectile.vpcf"

TrinityDesolator = TrinityDesolator or {}
-- Последний Desolator, чей пассив сняли с героя: [entindex героя] = { item, charges }.
-- Stygian при первом появлении в инвентаре забирает заряды, если этот Desolator уже уничтожен (ушёл в сборку).
TrinityDesolator.last_removed = TrinityDesolator.last_removed or {}

local function IsValidHandle(h)
    return h ~= nil and not h:IsNull()
end

local function AddCharges(item, amount)
    if amount <= 0 then return end
    local max_charges = item:GetSpecialValueFor("max_damage")
    local charges = math.min(item:GetCurrentCharges() + amount, max_charges)
    item:SetCurrentCharges(charges)
end

local function SharedPrecache(context)
    PrecacheResource("particle", PROJECTILE, context)
end

item_desolator = class({})
item_desolator.Precache = function(self, context) SharedPrecache(context) end
function item_desolator:GetIntrinsicModifierName()
    return "modifier_item_desolator_trinity"
end

item_desolator_2 = class({})
item_desolator_2.Precache = function(self, context) SharedPrecache(context) end
function item_desolator_2:GetIntrinsicModifierName()
    return "modifier_item_desolator_trinity"
end

-- ============================================================
-- Пассив владельца: урон + заряды + снижение брони атаками
-- ============================================================
modifier_item_desolator_trinity = class({
    IsHidden      = function(self) return true end,
    IsPurgable    = function(self) return false end,
    RemoveOnDeath = function(self) return false end,
    GetAttributes = function(self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
})

function modifier_item_desolator_trinity:OnCreated()
    local ability = self:GetAbility()
    if not ability then return end
    self.bonus_damage = ability:GetSpecialValueFor("bonus_damage")
    self.max_damage = ability:GetSpecialValueFor("max_damage")
    self.is_stygian = ability:GetAbilityName() == "item_desolator_2"

    if not IsServer() then return end
    self.charges = ability:GetCurrentCharges()
    -- Перенос зарядов откладываем на кадр: в момент сборки Desolator ещё может быть не уничтожен.
    if self.is_stygian and not ability.trinity_charges_inherited then
        self:StartIntervalThink(0.1)
    end
end

function modifier_item_desolator_trinity:OnRefresh()
    self:OnCreated()
end

function modifier_item_desolator_trinity:OnIntervalThink()
    self:StartIntervalThink(-1)
    local ability = self:GetAbility()
    local parent = self:GetParent()
    if not IsValidHandle(ability) or ability.trinity_charges_inherited then return end
    ability.trinity_charges_inherited = true
    if parent:IsIllusion() then return end

    local record = TrinityDesolator.last_removed[parent:entindex()]
    if record and not IsValidHandle(record.item) then
        TrinityDesolator.last_removed[parent:entindex()] = nil
        AddCharges(ability, record.charges or 0)
        self.charges = ability:GetCurrentCharges()
    end
end

function modifier_item_desolator_trinity:OnDestroy()
    if not IsServer() or self.is_stygian then return end
    local parent = self:GetParent()
    if not IsValidHandle(parent) or parent:IsIllusion() then return end
    local ability = self:GetAbility()
    local charges = IsValidHandle(ability) and ability:GetCurrentCharges() or self.charges or 0
    TrinityDesolator.last_removed[parent:entindex()] = { item = ability, charges = charges }
end

function modifier_item_desolator_trinity:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
        MODIFIER_PROPERTY_PROJECTILE_NAME,
        MODIFIER_EVENT_ON_ATTACK_LANDED,
        MODIFIER_EVENT_ON_DEATH,
    }
end

function modifier_item_desolator_trinity:GetModifierPreAttack_BonusDamage()
    local ability = self:GetAbility()
    if not ability or ability:IsNull() then return 0 end
    return (self.bonus_damage or 0) + math.min(ability:GetCurrentCharges(), self.max_damage or 0)
end

function modifier_item_desolator_trinity:GetModifierProjectileName()
    return PROJECTILE
end

function modifier_item_desolator_trinity:OnAttackLanded(params)
    if not IsServer() then return end
    local parent = self:GetParent()
    if params.attacker ~= parent then return end
    local target = params.target
    if not IsValidHandle(target) or target:IsOther() then return end
    if target:GetTeamNumber() == parent:GetTeamNumber() then return end
    -- Несколько Desolator у одного героя: срабатывает только первый модификатор.
    if parent:FindModifierByName(self:GetName()) ~= self then return end

    local ability = self:GetAbility()
    target:AddNewModifier(parent, ability, "modifier_item_desolator_trinity_corruption", {
        duration = ability:GetSpecialValueFor("corruption_duration"),
        armor = ability:GetSpecialValueFor("corruption_armor"),
    })
    EmitSoundOn("Item_Desolator.Target", target)
end

function modifier_item_desolator_trinity:OnDeath(params)
    if not IsServer() then return end
    local parent = self:GetParent()
    local victim = params.unit
    if parent:IsIllusion() or not parent:IsRealHero() then return end
    if not IsValidHandle(victim) or not victim:IsRealHero() or victim:IsIllusion() then return end
    if victim.IsTempestDouble and victim:IsTempestDouble() then return end
    if victim.IsReincarnating and victim:IsReincarnating() then return end
    if victim:GetTeamNumber() == parent:GetTeamNumber() then return end

    local ability = self:GetAbility()
    if not IsValidHandle(ability) then return end

    local owner_id = parent:GetPlayerOwnerID()
    local killer = params.attacker
    local killer_hero = killer
    if KillfeedSystem and KillfeedSystem.ResolveKillerHero then
        killer_hero = KillfeedSystem:ResolveKillerHero(killer)
    end
    local killer_id = IsValidHandle(killer_hero) and killer_hero:GetPlayerOwnerID() or -1

    if killer_id == owner_id then
        AddCharges(ability, ability:GetSpecialValueFor("bonus_damage_per_kill"))
    elseif KillfeedSystem and KillfeedSystem.GetAssistPlayerIDs then
        for _, id in pairs(KillfeedSystem:GetAssistPlayerIDs(victim, killer_id)) do
            if id == owner_id then
                AddCharges(ability, ability:GetSpecialValueFor("bonus_damage_per_assist"))
                break
            end
        end
    end
    self.charges = ability:GetCurrentCharges()
end

-- ============================================================
-- Снижение брони. Разные Desolator не складываются: остаётся самое сильное снижение.
-- ============================================================
modifier_item_desolator_trinity_corruption = class({
    IsHidden   = function(self) return false end,
    IsDebuff   = function(self) return true end,
    IsPurgable = function(self) return true end,
    GetTexture = function(self) return "item_desolator" end,
})

function modifier_item_desolator_trinity_corruption:OnCreated(kv)
    self.armor = kv.armor or 0
    if IsServer() then
        self:SetHasCustomTransmitterData(true)
    end
end

function modifier_item_desolator_trinity_corruption:OnRefresh(kv)
    if not IsServer() then return end
    -- Слабый источник продлевает, но не ослабляет текущее снижение.
    self.armor = math.min(self.armor or 0, kv.armor or 0)
    self:SendBuffRefreshToClients()
end

function modifier_item_desolator_trinity_corruption:AddCustomTransmitterData()
    return { armor = self.armor }
end

function modifier_item_desolator_trinity_corruption:HandleCustomTransmitterData(data)
    self.armor = data.armor or 0
end

function modifier_item_desolator_trinity_corruption:DeclareFunctions()
    return { MODIFIER_PROPERTY_PHYSICAL_ARMOR_BONUS }
end

function modifier_item_desolator_trinity_corruption:GetModifierPhysicalArmorBonus()
    return self.armor or 0
end
