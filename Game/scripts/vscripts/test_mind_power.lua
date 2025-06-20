-- Тестовый файл для проверки функции GetHeroMindPower
print("=== Тест функции GetHeroMindPower ===")

if GetHeroMindPower then
    print("✅ Функция GetHeroMindPower доступна")
else
    print("❌ Функция GetHeroMindPower НЕ доступна")
end

-- Проверяем, что функция работает
local test_hero = nil
local result = GetHeroMindPower(test_hero)
print("Результат теста с nil: " .. tostring(result)) 