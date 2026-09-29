-- Trinity: Orchid Malevolence и Scythe of Vyse (Lua-версии, общий модуль).
--   * Orchid: статы + активка «Сожжение души» (Soul Burn): безмолвие на silence_duration сек,
--     по окончании цель получает silence_damage_percent% урона, полученного за это время (магический).
--   * Scythe of Vyse = Orchid + Kaya + рецепт. Статы Orchid и Kaya (Сила Магии через mind_power_bonus
--     читает GetHeroMindPower из KV). Активка: превращение на sheep_duration сек; всё это время на цели
--     усиленное Сожжение души (silence_damage_percent хекса), взрыв - когда превращение заканчивается.
--     Своего безмолвия у хексового Сожжения нет: цель и так безмолвна, пока она хрюшка.
-- Значения берутся из KV (npc_items_custom.txt, "item_orchid" / "item_sheepstick").

LinkLuaModifier("modifier_item_orchid_trinity", "items/item_orchid_trinity", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_orchid_trinity_soul_burn", "items/item_orchid_trinity", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_item_sheepstick_trinity_hex", "items/item_orchid_trinity", LUA_MODIFIER_MOTION_NONE)

local ORCHID_SOUND = "DOTA_Item.Orchid.Activate"
local ORCHID_DEBUFF_FX = "particles/items2_fx/orchid.vpcf"
local ORCHID_POP_FX = "particles/items2_fx/orchid_pop.vpcf"
local HEX_SOUND = "DOTA_Item.Sheepstick.Activate"
local HEX_FX = "particles/items_fx/item_sheepstick.vpcf"
local HEX_MODEL = "models/props_gameplay/pig.vmdl"

local function IsValidHandle(h)
    return h ~= nil and not h:IsNull()
end

local function SharedPrecache(context)
    PrecacheResource("particle", ORCHID_DEBUFF_FX, context)
    PrecacheResource("particle", ORCHID_POP_FX, context)
    PrecacheResource("particle", HEX_FX, context)
    PrecacheResource("model", HEX_MODEL, context)
end

-- Вешает Сожжение души. Длительность уменьшается сопротивлением эффектам (движок, дебафф от врага).
-- silence = false - только накопление урона (хекс). Уже висящее Сожжение не укорачивается:
-- если Orchid наложен раньше и держится дольше, остаётся его время и безмолвие.
local function ApplySoulBurn(caster, ability, target, duration, silence)
    local existing = target:FindModifierByName("modifier_item_orchid_trinity_soul_burn")
    if existing then
        duration = math.max(duration, existing:GetRemainingTime())
    end
    target:AddNewModifier(caster, ability, "modifier_item_orchid_trinity_soul_burn", {
        duration = duration,
        silence = silence and 1 or 0,
    })
end

-- ============================================================
-- Orchid Malevolence
-- ============================================================
item_orchid = class({})
item_orchid.Precache = function(self, context) SharedPrecache(context) end

function item_orchid:GetIntrinsicModifierName()
    return "modifier_item_orchid_trinity"
end

function item_orchid:OnSpellStart()
    local caster = self:GetCaster()
    local target = self:GetCursorTarget()
    if not IsValidHandle(target) then return end

    caster:EmitSound(ORCHID_SOUND)
    if target:TriggerSpellAbsorb(self) then return end

    ApplySoulBurn(caster, self, target, self:GetSpecialValueFor("silence_duration"), true)
end

-- ============================================================
-- Scythe of Vyse
-- ============================================================
item_sheepstick = class({})
item_sheepstick.Precache = function(self, context) SharedPrecache(context) end

function item_sheepstick:GetIntrinsicModifierName()
    return "modifier_item_orchid_trinity"
end

function item_sheepstick:OnSpellStart()
    local caster = self:GetCaster()
    local target = self:GetCursorTarget()
    if not IsValidHandle(target) then return end

    target:EmitSound(HEX_SOUND)
    if target:TriggerSpellAbsorb(self) then return end

    -- Как в ванилле: иллюзии уничтожаются сразу.
    if target:IsIllusion() and not target:IsStrongIllusion() then
        target:Kill(self, caster)
        return
    end

    local fx = ParticleManager:CreateParticle(HEX_FX, PATTACH_ABSORIGIN, target)
    ParticleManager:ReleaseParticleIndex(fx)

    -- Сожжение получает ту же базовую длительность, что и превращение: сопротивление эффектам
    -- движок режет у обоих одинаково, и взрыв совпадает с концом превращения.
    local duration = self:GetSpecialValueFor("sheep_duration")
    target:AddNewModifier(caster, self, "modifier_item_sheepstick_trinity_hex", { duration = duration })
    ApplySoulBurn(caster, self, target, duration, false)
end

-- ============================================================
-- Пассив владельца: статы (общий для Orchid и Scythe of Vyse)
-- ============================================================
modifier_item_orchid_trinity = class({
    IsHidden      = function(self) return true end,
    IsPurgable    = function(self) return false end,
    RemoveOnDeath = function(self) return false end,
    GetAttributes = function(self) return MODIFIER_ATTRIBUTE_MULTIPLE end,
})

function modifier_item_orchid_trinity:OnCreated()
    local ability = self:GetAbility()
    if not ability then return end
    self.intellect = ability:GetSpecialValueFor("bonus_intellect")
    self.attack_speed = ability:GetSpecialValueFor("bonus_attack_speed")
    self.damage = ability:GetSpecialValueFor("bonus_damage")
    self.mana_regen = ability:GetSpecialValueFor("bonus_mana_regen")
    self.mana_regen_amp = ability:GetSpecialValueFor("mana_regen_multiplier")
end

function modifier_item_orchid_trinity:OnRefresh()
    self:OnCreated()
end

function modifier_item_orchid_trinity:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_STATS_INTELLECT_BONUS,
        MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
        MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
        MODIFIER_PROPERTY_MANA_REGEN_CONSTANT,
        MODIFIER_PROPERTY_MP_REGEN_AMPLIFY_PERCENTAGE,
    }
end

function modifier_item_orchid_trinity:GetModifierBonusStats_Intellect()
    return self.intellect or 0
end

function modifier_item_orchid_trinity:GetModifierAttackSpeedBonus_Constant()
    return self.attack_speed or 0
end

function modifier_item_orchid_trinity:GetModifierPreAttack_BonusDamage()
    return self.damage or 0
end

function modifier_item_orchid_trinity:GetModifierConstantManaRegen()
    return self.mana_regen or 0
end

function modifier_item_orchid_trinity:GetModifierMPRegenAmplify_Percentage()
    return self.mana_regen_amp or 0
end

-- ============================================================
-- Сожжение души: накопление урона, взрыв по окончании; от Orchid - ещё и безмолвие
-- ============================================================
modifier_item_orchid_trinity_soul_burn = class({
    IsHidden   = function(self) return false end,
    IsDebuff   = function(self) return true end,
    IsPurgable = function(self) return true end,
})

function modifier_item_orchid_trinity_soul_burn:GetTexture()
    return "item_orchid"
end

function modifier_item_orchid_trinity_soul_burn:GetEffectName()
    return ORCHID_DEBUFF_FX
end

function modifier_item_orchid_trinity_soul_burn:GetEffectAttachType()
    return PATTACH_OVERHEAD_FOLLOW
end

function modifier_item_orchid_trinity_soul_burn:OnCreated(kv)
    local ability = self:GetAbility()
    self.damage_pct = ability and ability:GetSpecialValueFor("silence_damage_percent") or 0
    if not IsServer() then return end
    self.stored = self.stored or 0
    -- Безмолвие храним в стаках (1 = есть), чтобы CheckState на клиенте видел то же, что сервер.
    self:SetStackCount((kv and kv.silence == 1) and 1 or 0)
end

function modifier_item_orchid_trinity_soul_burn:OnRefresh(kv)
    -- Накопленный урон сохраняется; процент берём наибольший. Безмолвие от Orchid не снимается хексом.
    local ability = self:GetAbility()
    local pct = ability and ability:GetSpecialValueFor("silence_damage_percent") or 0
    self.damage_pct = math.max(self.damage_pct or 0, pct)
    if IsServer() and kv and kv.silence == 1 then
        self:SetStackCount(1)
    end
end

function modifier_item_orchid_trinity_soul_burn:CheckState()
    if self:GetStackCount() ~= 1 then return {} end
    return {
        [MODIFIER_STATE_SILENCED] = true,
    }
end

function modifier_item_orchid_trinity_soul_burn:DeclareFunctions()
    return {
        MODIFIER_EVENT_ON_TAKEDAMAGE,
        MODIFIER_PROPERTY_TOOLTIP,
    }
end

function modifier_item_orchid_trinity_soul_burn:OnTooltip()
    return self.damage_pct
end

function modifier_item_orchid_trinity_soul_burn:OnTakeDamage(params)
    if not IsServer() then return end
    if params.unit ~= self:GetParent() then return end
    -- Собственный взрыв не учитываем.
    if params.inflictor and params.inflictor == self:GetAbility() then return end
    self.stored = (self.stored or 0) + (params.damage or 0)
end

function modifier_item_orchid_trinity_soul_burn:OnDestroy()
    if not IsServer() then return end
    local parent = self:GetParent()
    local caster = self:GetCaster()
    if not IsValidHandle(parent) or not parent:IsAlive() then return end

    local damage = (self.stored or 0) * (self.damage_pct or 0) / 100
    local fx = ParticleManager:CreateParticle(ORCHID_POP_FX, PATTACH_OVERHEAD_FOLLOW, parent)
    ParticleManager:SetParticleControl(fx, 1, Vector(damage, 0, 0))
    ParticleManager:ReleaseParticleIndex(fx)

    if damage <= 0 or not IsValidHandle(caster) then return end

    local ability = self:GetAbility()
    ApplyDamage({
        victim = parent,
        attacker = caster,
        damage = damage,
        damage_type = DAMAGE_TYPE_MAGICAL,
        damage_flags = DOTA_DAMAGE_FLAG_NO_SPELL_AMPLIFICATION,
        ability = IsValidHandle(ability) and ability or nil,
    })
    SendOverheadEventMessage(nil, OVERHEAD_ALERT_BONUS_SPELL_DAMAGE, parent, damage, nil)
end

-- ============================================================
-- Превращение (Scythe of Vyse)
-- ============================================================
modifier_item_sheepstick_trinity_hex = class({
    IsHidden          = function(self) return false end,
    IsDebuff          = function(self) return true end,
    -- Как в ванилле: снимается только сильным развеиванием.
    IsPurgable        = function(self) return false end,
    IsPurgeException  = function(self) return true end,
})

function modifier_item_sheepstick_trinity_hex:GetTexture()
    return "item_sheepstick"
end

function modifier_item_sheepstick_trinity_hex:OnCreated()
    local ability = self:GetAbility()
    self.move_speed = ability and ability:GetSpecialValueFor("sheep_movement_speed") or 140
end

function modifier_item_sheepstick_trinity_hex:OnRefresh()
    self:OnCreated()
end

function modifier_item_sheepstick_trinity_hex:CheckState()
    return {
        [MODIFIER_STATE_HEXED] = true,
        [MODIFIER_STATE_SILENCED] = true,
        [MODIFIER_STATE_MUTED] = true,
        [MODIFIER_STATE_DISARMED] = true,
    }
end

function modifier_item_sheepstick_trinity_hex:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_MOVESPEED_BASE_OVERRIDE,
        MODIFIER_PROPERTY_MODEL_CHANGE,
    }
end

function modifier_item_sheepstick_trinity_hex:GetModifierMoveSpeedOverride()
    return self.move_speed
end

function modifier_item_sheepstick_trinity_hex:GetModifierModelChange()
    return HEX_MODEL
end

function modifier_item_sheepstick_trinity_hex:OnDestroy()
    if not IsServer() then return end
    local parent = self:GetParent()
    if not IsValidHandle(parent) then return end
    local fx = ParticleManager:CreateParticle(HEX_FX, PATTACH_ABSORIGIN, parent)
    ParticleManager:ReleaseParticleIndex(fx)
end
