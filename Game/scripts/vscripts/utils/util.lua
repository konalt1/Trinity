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

-- Вспомогательная функция для получения mind power героя
function GetHeroMindPower(hero)
    if not hero then return 0 end
    
    -- Получаем базовый интеллект героя
    local base_intelligence = hero:GetIntellect(false)
    
    -- Получаем все бонусы mind power от предметов и способностей
    local mind_power_bonus = 0
    
    -- Проверяем все предметы героя
    for i = 0, 8 do
        local item = hero:GetItemInSlot(i)
        if item then
            local mind_power_bonus_value = item:GetSpecialValueFor("mind_power_bonus")
            if mind_power_bonus_value and mind_power_bonus_value > 0 then
                mind_power_bonus = mind_power_bonus + mind_power_bonus_value
            end
        end
    end
    
    -- Проверяем все модификаторы героя на предмет mind_power_bonus
    for _, modifier in pairs(hero:FindAllModifiers()) do
        if modifier.GetModifierMindPowerBonus then
            mind_power_bonus = mind_power_bonus + modifier:GetModifierMindPowerBonus()
        end
    end
    
    -- Итоговое значение mind power
    return base_intelligence + mind_power_bonus
end
