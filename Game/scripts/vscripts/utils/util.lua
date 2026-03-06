function GiveGoldPlayers( gold )
	for index=0 ,4 do
		if PlayerResource:HasSelectedHero(index) then
			local player = PlayerResource:GetPlayer(index)
			local hero = PlayerResource:GetSelectedHeroEntity(index)
			hero:ModifyGold(gold, false, 0)
			SendOverheadEventMessage( player, OVERHEAD_ALERT_GOLD, hero, gold, nil )
		end
	end
end

function GiveExperiencePlayers( experience )
	for index=0 ,4 do
		if PlayerResource:HasSelectedHero(index) then
			local player = PlayerResource:GetPlayer(index)
			local hero = PlayerResource:GetSelectedHeroEntity(index)
			hero:AddExperience(experience, 0, false, true )
		end
	end
end

function GetReductionFromArmor(armor)
	local m = 0.06 * armor
	return 100 * (1 - m/(1+math.abs(m)))
end

function AddModifierLifesteal(parent, stack)
	local modifier = parent:FindModifierByName("modifier_lifesteal_custom")

	if modifier then
		modifier:SetStackCount(modifier:GetStackCount() + stack)
	else
 		local modif = parent:AddNewModifier(parent, nil, "modifier_lifesteal_custom", {})
		modif:SetStackCount(modif:GetStackCount() + stack)
 	end
end
 

function RemoveModifierLifesteal(parent, stack)
	local modifier = parent:FindModifierByName("modifier_lifesteal_custom")
	modifier:SetStackCount(modifier:GetStackCount() - stack)

	if modifier:GetStackCount() <= 0 then
 		modifier:Destroy()
 	end
end

function HasShard(parent)
    return parent:HasModifier("modifier_item_aghanims_shard")
end

-- Реестр модификаторов, дающих бонус к Mind Power.
-- FindAllModifiers() возвращает C++ объекты, поэтому Lua-методы вроде
-- GetModifierMindPowerBonus недоступны напрямую. Вместо этого каждый
-- модификатор регистрирует себя здесь через RegisterMindPowerModifier().
MIND_POWER_MODIFIER_REGISTRY = MIND_POWER_MODIFIER_REGISTRY or {}

function RegisterMindPowerModifier(modifier_name, getter_fn)
    MIND_POWER_MODIFIER_REGISTRY[modifier_name] = getter_fn
end

-- Вспомогательная функция для получения mind power героя
function GetHeroMindPower(hero)
    if not hero then return 0 end

    -- Базовый интеллект
    local total = hero:GetIntellect(false)

    -- base_mind_power из KV способности
    local mp_ability = hero:FindAbilityByName("mind_power")
    if mp_ability then
        total = total + (mp_ability:GetSpecialValueFor("base_mind_power") or 0)
    end

    -- Бонусы от предметов (поле mind_power_bonus в AbilityValues)
    for i = 0, 8 do
        local item = hero:GetItemInSlot(i)
        if item then
            local v = item:GetSpecialValueFor("mind_power_bonus")
            if v and v > 0 then
                total = total + v
            end
        end
    end

    -- Бонусы от модификаторов через реестр (поиск по имени — единственный
    -- надёжный способ, т.к. FindAllModifiers возвращает C++ обёртки)
    for _, modifier in pairs(hero:FindAllModifiers()) do
        local getter = MIND_POWER_MODIFIER_REGISTRY[modifier:GetName()]
        if getter then
            total = total + (getter(modifier) or 0)
        end
    end

    return total
end

function CalculateDirection(point1, point2)
    local direction = (point1 - point2):Normalized()
    return direction
end

function CalculateDistance(point1, point2)
    local distance = (point1 - point2):Length2D()
    return distance
end
