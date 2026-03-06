LinkLuaModifier("modifier_omniknight_innate_oaa", "abilities/omniknight/oaa_oracle_innate", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_omniknight_innate_damage", "abilities/omniknight/oaa_oracle_innate", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_omniknight_talent_heal_movespeed", "abilities/omniknight/oaa_oracle_innate", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_omniknight_talent_overheal_barrier", "abilities/omniknight/oaa_oracle_innate", LUA_MODIFIER_MOTION_NONE)

local OMNI_HEAL_MS_TALENT_NAME = "special_bonus_unique_custom_omniknight_1"
local OMNI_HEAL_DAMAGE_TALENT_NAME = "special_bonus_unique_custom_omniknight_2"
local OMNI_OVERHEAL_BARRIER_TALENT_NAME = "special_bonus_unique_custom_omniknight_3"
local PERIODIC_HEAL_SOURCES = {
  holy_ground = true,
  item_flask = true,
  item_tango = true,
  item_tango_single = true,
  item_spirit_vessel = true,
  item_urn_of_shadows = true,
}

omniknight_innate_oaa = class({})

function omniknight_innate_oaa:GetIntrinsicModifierName()
  return "modifier_omniknight_innate_oaa"
end

function omniknight_innate_oaa:Precache(context)
  PrecacheResource("particle", "particles/generic_gameplay/rune_haste_owner.vpcf", context)
end

---------------------------------------------------------------------------------------------------

modifier_omniknight_innate_oaa = class({
    IsHidden = function(self) return true end,
    IsDebuff = function(self) return false end,
    IsPurgable = function(self) return false end,
    RemoveOnDeath = function(self) return false end,
})

function modifier_omniknight_innate_oaa:IsPeriodicHealSource(ability_name)
  return ability_name ~= nil and PERIODIC_HEAL_SOURCES[ability_name] == true
end

function modifier_omniknight_innate_oaa:ApplyHealMoveSpeedBuff(unit, actual_heal, source_ability_name)
  local parent = self:GetParent()
  if not unit or unit:IsNull() or not parent or parent:IsNull() then
    return
  end

  if not (unit:IsHero() or unit:IsCreep()) then
    return
  end

  if self:IsPeriodicHealSource(source_ability_name) then
    return
  end

  local talent = parent:FindAbilityByName(OMNI_HEAL_MS_TALENT_NAME)
  if not talent or talent:IsNull() or talent:GetLevel() <= 0 then
    return
  end

  local min_heal = talent:GetSpecialValueFor("min_heal") or 50
  if actual_heal <= min_heal then
    return
  end

  local duration = talent:GetSpecialValueFor("duration") or 5
  local bonus_ms = talent:GetSpecialValueFor("bonus_ms") or 15
  if duration <= 0 or bonus_ms == 0 then
    return
  end

  unit:AddNewModifier(parent, talent, "modifier_omniknight_talent_heal_movespeed", {
    duration = duration,
    bonus_ms = bonus_ms
  })
end

function modifier_omniknight_innate_oaa:ApplyOverhealBarrier(unit, overheal)
  local parent = self:GetParent()
  if not unit or unit:IsNull() or not parent or parent:IsNull() then
    return
  end

  if overheal <= 0 then
    return
  end

  local talent = parent:FindAbilityByName(OMNI_OVERHEAL_BARRIER_TALENT_NAME)
  if not talent or talent:IsNull() or talent:GetLevel() <= 0 then
    return
  end

  local barrier_coef = talent:GetSpecialValueFor("overheal_to_barrier_coef") or 1
  local duration = talent:GetSpecialValueFor("barrier_duration") or 10
  if barrier_coef <= 0 or duration <= 0 then
    return
  end

  local barrier_amount = math.floor(overheal * barrier_coef)
  if barrier_amount <= 0 then
    return
  end

  unit:AddNewModifier(parent, talent, "modifier_omniknight_talent_overheal_barrier", {
    duration = duration,
    shield_health = barrier_amount
  })
end


function modifier_omniknight_innate_oaa:DeclareFunctions()
  return {
    MODIFIER_EVENT_ON_HEAL_RECEIVED,
  }
end

-- Альтернативный метод: отслеживаем изменения HP напрямую
function modifier_omniknight_innate_oaa:OnTakeDamage(event)
  -- Этот метод не используется, но может пригодиться для других проверок
end

if IsServer() then
  function modifier_omniknight_innate_oaa:OnHealReceived(event)
    local parent = self:GetParent()
    local inflictor = event.inflictor -- Heal ability
    local unit = event.unit -- Healed unit
    local amount = event.gain -- Amount healed

    if parent:PassivesDisabled() or parent:IsIllusion() then
      return
    end

    local innate = self:GetAbility()
    if not innate or innate:IsNull() then
      return
    end

    -- Don't continue if healing entity/ability doesn't exist
    if not inflictor or inflictor:IsNull() then
      return
    end

    -- Don't continue if healed unit doesn't exist
    if not unit or unit:IsNull() then
      return
    end

    if amount <= 0 then
      return
    end

    local function AccumulateDamage(source_ability_name)
      if unit:GetTeamNumber() == parent:GetTeamNumber() then
        -- OnHealReceived срабатывает до применения хила, поэтому считаем оверхил напрямую
        local hp_room = unit:GetMaxHealth() - unit:GetHealth()
        local actual_heal = math.min(amount, hp_room)
        local overheal = math.max(0, amount - hp_room)

        self:ApplyHealMoveSpeedBuff(unit, actual_heal, source_ability_name)
        self:ApplyOverhealBarrier(unit, overheal)

        -- Накапливаем урон только за реально восстановленное здоровье.
        -- Если изучен талант, используем отдельные коэффициенты для себя/союзников из KV Молота.
        local damage_per_heal = innate:GetSpecialValueFor("damage_per_heal") or 0.5
        local damage_talent = parent:FindAbilityByName(OMNI_HEAL_DAMAGE_TALENT_NAME)
        if damage_talent and not damage_talent:IsNull() and damage_talent:GetLevel() > 0 then
          if unit == parent then
            damage_per_heal = innate:GetSpecialValueFor("talent_self_damage_per_heal") or damage_per_heal
          else
            damage_per_heal = innate:GetSpecialValueFor("talent_ally_damage_per_heal") or damage_per_heal
          end
        end
        local bonus_damage = math.floor(actual_heal * damage_per_heal)

        if bonus_damage > 0 then
          local damage_modifier = parent:FindModifierByName("modifier_omniknight_innate_damage")
          if not damage_modifier then
            damage_modifier = parent:AddNewModifier(parent, innate, "modifier_omniknight_innate_damage", {})
          end
          if damage_modifier then
            damage_modifier:AddDamageStack(bonus_damage)
          end
        end
      end
    end

    -- We check what is inflictor just in case Valve randomly changes inflictor handle type or if someone put a caster instead of the ability when using the Heal method
    if inflictor.GetAbilityName == nil then
      -- Inflictor is not an ability or item
      if parent ~= inflictor then
        -- Inflictor is not the parent -> parent is not the healer
        return
      end

      AccumulateDamage(nil)
    else
      -- Inflictor is an ability
      local name = inflictor:GetAbilityName()
      local ability = parent:FindAbilityByName(name)
      if not ability then
        -- Parent doesn't have this ability
        -- Check items:
        local found_item
        local max_slot = DOTA_ITEM_SLOT_6
        if parent:HasModifier("modifier_spoons_stash_oaa") then
          max_slot = DOTA_ITEM_SLOT_9
        end
        for i = DOTA_ITEM_SLOT_1, max_slot do
          local item = parent:GetItemInSlot(i)
          if item and item:GetName() == name then
            found_item = true
            ability = item
            break
          end
        end
        if not found_item then
          --  Parent doesn't have this item -> parent is not the healer
          return
        end
      end
      if ability:GetLevel() > 0 or ability:IsItem() then
        -- Parent has this ability or item with the same name as inflictor
        -- Check if it's exactly the same by comparing indexes
        if ability:entindex() == inflictor:entindex() then
          -- Indexes are the same -> parent is the healer
          -- if index of the ability changes randomly and this never happens, then thank you Valve
          -- Apply buff/debuff to the unit
          AccumulateDamage(name)
        end
      end
    end
  end
end

---------------------------------------------------------------------------------------------------

modifier_omniknight_talent_heal_movespeed = class({
    IsHidden = function(self) return false end,
    IsDebuff = function(self) return false end,
    IsPurgable = function(self) return true end,
    RemoveOnDeath = function(self) return true end,
})

function modifier_omniknight_talent_heal_movespeed:GetAttributes()
  return MODIFIER_ATTRIBUTE_MULTIPLE
end

function modifier_omniknight_talent_heal_movespeed:OnCreated(kv)
  self.bonus_ms = tonumber(kv.bonus_ms) or 15
  local ability = self:GetAbility()
  if ability and not ability:IsNull() and self.bonus_ms == 0 then
    self.bonus_ms = ability:GetSpecialValueFor("bonus_ms") or 15
  end
end

function modifier_omniknight_talent_heal_movespeed:DeclareFunctions()
  return {
    MODIFIER_PROPERTY_MOVESPEED_BONUS_CONSTANT,
  }
end

function modifier_omniknight_talent_heal_movespeed:GetModifierMoveSpeedBonus_Constant()
  return self.bonus_ms or 0
end

function modifier_omniknight_talent_heal_movespeed:GetEffectName()
  return "particles/generic_gameplay/rune_haste_owner.vpcf"
end

function modifier_omniknight_talent_heal_movespeed:GetEffectAttachType()
  return PATTACH_ABSORIGIN_FOLLOW
end

function modifier_omniknight_talent_heal_movespeed:GetTexture()
  return "omniknight_guardian_angel"
end

---------------------------------------------------------------------------------------------------

modifier_omniknight_talent_overheal_barrier = class({
    IsHidden = function(self) return false end,
    IsDebuff = function(self) return false end,
    IsPurgable = function(self) return true end,
    RemoveOnDeath = function(self) return true end,
})

function modifier_omniknight_talent_overheal_barrier:GetAttributes()
  return MODIFIER_ATTRIBUTE_MULTIPLE
end

function modifier_omniknight_talent_overheal_barrier:OnCreated(kv)
  self.max_shield = tonumber(kv.shield_health) or 0
  self.current_shield = self.max_shield
  self:SetHasCustomTransmitterData(true)
  if IsServer() and self.current_shield <= 0 then
    self:Destroy()
  end
end

function modifier_omniknight_talent_overheal_barrier:AddCustomTransmitterData()
  return {
    max_shield = self.max_shield,
    current_shield = self.current_shield,
  }
end

function modifier_omniknight_talent_overheal_barrier:HandleCustomTransmitterData(data)
  self.max_shield = data.max_shield
  self.current_shield = data.current_shield
end

function modifier_omniknight_talent_overheal_barrier:DeclareFunctions()
  return {
    MODIFIER_PROPERTY_INCOMING_DAMAGE_CONSTANT,
    MODIFIER_PROPERTY_TOOLTIP,
  }
end

function modifier_omniknight_talent_overheal_barrier:GetModifierIncomingDamageConstant(params)
  if not IsServer() then
    if params.report_max then
      return self.max_shield
    else
      return self.current_shield
    end
  end

  if not params or params.damage_type ~= DAMAGE_TYPE_PHYSICAL then
    return 0
  end

  if params.damage > self.current_shield then
    local blocked = self.current_shield
    self.current_shield = 0
    self:Destroy()
    return -blocked
  else
    self.current_shield = self.current_shield - params.damage
    self:SendBuffRefreshToClients()
    return -params.damage
  end
end

function modifier_omniknight_talent_overheal_barrier:OnTooltip()
  return self.shield_health or 0
end

function modifier_omniknight_talent_overheal_barrier:GetTexture()
  return "omniknight_guardian_angel"
end

---------------------------------------------------------------------------------------------------

modifier_omniknight_innate_damage = class({
    IsHidden = function(self) return false end,
    IsDebuff = function(self) return false end,
    IsPurgable = function(self) return false end,
    RemoveOnDeath = function(self) return true end,
})


function modifier_omniknight_innate_damage:OnCreated()
  if IsServer() then
    self.damage_stacks = {} -- Таблица стаков с временем истечения
    self:SetStackCount(0)
    
    -- Проверяем стаки каждую секунду
    self:StartIntervalThink(1.0)
  end
end

function modifier_omniknight_innate_damage:OnIntervalThink()
  if IsServer() then
    local current_time = GameRules:GetGameTime()
    local total_damage = 0
    
    -- Удаляем истекшие стаки
    for i = #self.damage_stacks, 1, -1 do
      if current_time >= self.damage_stacks[i].expire_time then
        table.remove(self.damage_stacks, i)
      else
        total_damage = total_damage + self.damage_stacks[i].damage
      end
    end
    
    -- Применяем максимальный лимит урона
    local ability = self:GetAbility()
    if ability and not ability:IsNull() then
      local max_damage = ability:GetSpecialValueFor("max_bonus_damage")
      if max_damage and total_damage > max_damage then
        total_damage = max_damage
      end
    end
    
    -- Обновляем отображение
    self:SetStackCount(total_damage)
    
    -- Если стаков не осталось, удаляем модификатор
    if #self.damage_stacks == 0 and total_damage == 0 then
      self:Destroy()
    end
  end
end

function modifier_omniknight_innate_damage:AddDamageStack(damage)
  if IsServer() then
    local current_time = GameRules:GetGameTime()
    local ability = self:GetAbility()
    local stack_duration = 10.0
    
    if ability and not ability:IsNull() then
      stack_duration = ability:GetSpecialValueFor("stack_duration") or 10.0
    end
    
    local expire_time = current_time + stack_duration
    
    table.insert(self.damage_stacks, {
      damage = damage,
      expire_time = expire_time
    })
    
    -- Немедленно обновляем отображение
    self:OnIntervalThink()
  end
end

function modifier_omniknight_innate_damage:DeclareFunctions()
  return {
    MODIFIER_PROPERTY_PREATTACK_BONUS_DAMAGE,
  }
end

function modifier_omniknight_innate_damage:GetModifierPreAttack_BonusDamage()
  return self:GetStackCount()
end

function modifier_omniknight_innate_damage:GetTexture()
  return "omniknight_hammer_of_purity"
end

function modifier_omniknight_innate_damage:GetTooltip()
  if IsServer() and self.damage_stacks then
    return self:GetStackCount() .. " урона (стаков: " .. #self.damage_stacks .. ")"
  end
  return self:GetStackCount()
end
