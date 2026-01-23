modifier_leash_to_spawn = class({})

function modifier_leash_to_spawn:IsHidden()
	return true
end

function modifier_leash_to_spawn:IsPurgable()
	return false
end

function modifier_leash_to_spawn:RemoveOnDeath()
	return false
end

function modifier_leash_to_spawn:OnCreated(keys)
	if not IsServer() then return end
	
	-- Сохраняем позицию спавна
	self.spawn_position = self:GetParent():GetAbsOrigin()
	self.leash_radius = keys.radius or 1000
	
	-- Запускаем проверку каждые 0.1 секунды
	self:StartIntervalThink(0.1)
end

function modifier_leash_to_spawn:OnIntervalThink()
	if not IsServer() then return end
	
	local parent = self:GetParent()
	
	-- Проверяем, жив ли юнит
	if not parent or not parent:IsAlive() then
		return
	end
	
	local current_position = parent:GetAbsOrigin()
	local distance = (current_position - self.spawn_position):Length2D()
	
	-- Если юнит вышел за границу привязки
	if distance > self.leash_radius then
		-- Останавливаем все команды
		parent:Stop()
		
		-- Телепортируем обратно к точке спавна
		FindClearSpaceForUnit(parent, self.spawn_position, false)
		
		-- Восстанавливаем здоровье
		parent:SetHealth(parent:GetMaxHealth())
		
		-- Опционально: можно добавить эффект
		-- local particle = ParticleManager:CreateParticle("particles/generic_gameplay/rune_teleport_end.vpcf", PATTACH_ABSORIGIN, parent)
		-- ParticleManager:ReleaseParticleIndex(particle)
	end
end

function modifier_leash_to_spawn:DeclareFunctions()
	return {}
end
