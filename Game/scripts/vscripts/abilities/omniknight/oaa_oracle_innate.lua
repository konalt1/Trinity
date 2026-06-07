LinkLuaModifier("modifier_omniknight_innate_oaa", "abilities/omniknight/oaa_oracle_innate", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_omniknight_innate_damage", "abilities/omniknight/oaa_oracle_innate", LUA_MODIFIER_MOTION_NONE)

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

if IsServer() then
  function modifier_omniknight_innate_oaa:OnHealReceived(event)
    local parent = self:GetParent()
    local inflictor = event.inflictor
    local unit = event.unit
    local amount = event.gain

    if parent:PassivesDisabled() or parent:IsIllusion() then
      return
    end

    local innate = self:GetAbility()
    if not innate or innate:IsNull() then
      return
    end

    if not inflictor or inflictor:IsNull() then
      return
    end

    if not unit or unit:IsNull() then
      return
    end

    if amount <= 0 then
      return
    end

    local function AccumulateDamage()
      if unit:GetTeamNumber() ~= parent:GetTeamNumber() then
        return
      end

      local hp_room = unit:GetMaxHealth() - unit:GetHealth()
      local actual_heal = math.min(amount, hp_room)
      local damage_per_heal = innate:GetSpecialValueFor("damage_per_heal") or 0.5
      local bonus_damage = math.floor(actual_heal * damage_per_heal)

      if bonus_damage <= 0 then
        return
      end

      local damage_modifier = parent:FindModifierByName("modifier_omniknight_innate_damage")
      if not damage_modifier then
        damage_modifier = parent:AddNewModifier(parent, innate, "modifier_omniknight_innate_damage", {})
      end
      if damage_modifier then
        damage_modifier:AddDamageStack(bonus_damage)
      end
    end

    if inflictor.GetAbilityName == nil then
      if parent ~= inflictor then
        return
      end

      AccumulateDamage()
    else
      local name = inflictor:GetAbilityName()
      local ability = parent:FindAbilityByName(name)
      if not ability then
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
          return
        end
      end
      if ability:GetLevel() > 0 or ability:IsItem() then
        if ability:entindex() == inflictor:entindex() then
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
    self.damage_stacks = {}
    self:SetStackCount(0)
    self:StartIntervalThink(1.0)
  end
end

function modifier_omniknight_innate_damage:OnIntervalThink()
  if IsServer() then
    local current_time = GameRules:GetGameTime()
    local total_damage = 0

    for i = #self.damage_stacks, 1, -1 do
      if current_time >= self.damage_stacks[i].expire_time then
        table.remove(self.damage_stacks, i)
      else
        total_damage = total_damage + self.damage_stacks[i].damage
      end
    end

    local ability = self:GetAbility()
    if ability and not ability:IsNull() then
      local max_damage = ability:GetSpecialValueFor("max_bonus_damage")
      if max_damage and total_damage > max_damage then
        total_damage = max_damage
      end
    end

    self:SetStackCount(total_damage)

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

    table.insert(self.damage_stacks, {
      damage = damage,
      expire_time = current_time + stack_duration
    })

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
