LinkLuaModifier("modifier_omniknight_innate_oaa", "abilities/oaa_oracle_innate", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_omniknight_innate_damage", "abilities/oaa_oracle_innate", LUA_MODIFIER_MOTION_NONE)

omniknight_innate_oaa = class({})

function omniknight_innate_oaa:GetIntrinsicModifierName()
  return "modifier_omniknight_innate_oaa"
end

---------------------------------------------------------------------------------------------------

modifier_omniknight_innate_oaa = class({
    IsHidden = function(self) return true end,
    IsDebuff = function(self) return false end,
    IsPurgable = function(self) return false end,
    RemoveOnDeath = function(self) return false end,
})


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

    local function AccumulateDamage()
      if unit:GetTeamNumber() == parent:GetTeamNumber() then
        -- Сохраняем HP до исцеления
        local unit_hp_before = unit:GetHealth()
        local unit_max_hp = unit:GetMaxHealth()
        
        -- Используем небольшую задержку для точного определения реального исцеления
        Timers:CreateTimer(0.01, function()
          local unit_hp_after = unit:GetHealth()
          local actual_heal = unit_hp_after - unit_hp_before
          
          -- Убеждаемся что исцеление положительное
          if actual_heal <= 0 then
            return
          end
          
          -- Накапливаем урон только за реально восстановленное здоровье
          local damage_per_heal = innate:GetSpecialValueFor("damage_per_heal") or 0.5
          local bonus_damage = math.floor(actual_heal * damage_per_heal)
          
          if bonus_damage > 0 then
            -- Добавляем или обновляем модификатор урона на Omniknight
            local damage_modifier = parent:FindModifierByName("modifier_omniknight_innate_damage")
            if not damage_modifier then
              damage_modifier = parent:AddNewModifier(parent, innate, "modifier_omniknight_innate_damage", {})
            end
            
            if damage_modifier then
              damage_modifier:AddDamageStack(bonus_damage)
            end
          end
        end)
      end
    end

    -- We check what is inflictor just in case Valve randomly changes inflictor handle type or if someone put a caster instead of the ability when using the Heal method
    if inflictor.GetAbilityName == nil then
      -- Inflictor is not an ability or item
      if parent ~= inflictor then
        -- Inflictor is not the parent -> parent is not the healer
        return
      end

      AccumulateDamage()
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
          AccumulateDamage()
        end
      end
    end
  end
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
