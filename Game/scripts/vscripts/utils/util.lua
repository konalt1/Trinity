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