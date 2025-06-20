# Система Mind Power

## Обзор

Система Mind Power была модифицирована для поддержки бонусов от предметов и способностей. Теперь mind power рассчитывается как сумма базового интеллекта героя и всех бонусов от предметов и модификаторов.

## Как это работает

### 1. Основная функция
```lua
GetHeroMindPower(hero)
```
Эта функция возвращает полное значение mind power героя, учитывая:
- Базовый интеллект героя (`GetIntellect(false)`)
- Бонусы от предметов с параметром `mind_power_bonus`
- Бонусы от модификаторов с функцией `GetModifierMindPowerBonus()`

### 2. Модификатор mind_power
Модификатор `modifier_mind_power` теперь:
- Обновляется каждые 0.1 секунды
- Использует функцию `GetHeroMindPower()` для получения актуального значения
- Отображает итоговое значение в стеке модификатора

## Как добавить бонус к mind power

### Через предметы

1. **Добавьте параметр в AbilityValues:**
```txt
"AbilityValues"
{
    "mind_power_bonus" "100"
}
```

2. **Создайте скрипт предмета с модификатором:**
```lua
modifier_item_example = class({
    IsHidden = function(self) return false end,
    IsPurgable = function(self) return false end,
    IsBuff = function(self) return true end,
    RemoveOnDeath = function(self) return false end,
})

function modifier_item_example:OnCreated()
    if not IsServer() then return end
    self.mind_power_bonus = self:GetAbility():GetSpecialValueFor("mind_power_bonus")
end

function modifier_item_example:GetModifierMindPowerBonus()
    return self.mind_power_bonus or 0
end
```

### Через способности

1. **Добавьте параметр в AbilityValues:**
```txt
"AbilityValues"
{
    "mind_power_bonus" "50"
    "duration" "10.0"
}
```

2. **Создайте модификатор способности:**
```lua
modifier_ability_example = class({
    IsHidden = function(self) return false end,
    IsPurgable = function(self) return true end,
    IsBuff = function(self) return true end,
    RemoveOnDeath = function(self) return true end,
})

function modifier_ability_example:OnCreated()
    if not IsServer() then return end
    self.mind_power_bonus = self:GetAbility():GetSpecialValueFor("mind_power_bonus")
end

function modifier_ability_example:GetModifierMindPowerBonus()
    return self.mind_power_bonus or 0
end
```

## Примеры использования

### В способностях (например, Frost Shield)
```lua
local caster = self:GetCaster()
local mind_power = GetHeroMindPower(caster)
local bonus_damage = mind_power * self.intelligence_multiplier
local total_damage = base_damage + bonus_damage
```

### В предметах
Предмет Kaya теперь дает +100 к mind power вместо spell_amp.

### В способностях
Создана способность `mind_power_buff`, которая дает временный бонус к mind power.

## Отладка

Система выводит отладочную информацию в консоль:
```
Total Mind Power: 150, Display value: 150
```

Это помогает отслеживать изменения mind power в реальном времени.

## Совместимость

- Система обратно совместима с существующим кодом
- Функция `GetHeroMindPower()` может использоваться в любых скриптах
- Модификаторы автоматически учитывают все источники бонусов 