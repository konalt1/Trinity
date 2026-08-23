modifier_trinity_warmup_zone = class({})

function modifier_trinity_warmup_zone:IsHidden()
	return true
end

function modifier_trinity_warmup_zone:IsPurgable()
	return false
end

function modifier_trinity_warmup_zone:RemoveOnDeath()
	return false
end

function modifier_trinity_warmup_zone:OnCreated()
	if not IsServer() then
		return
	end
	self:StartIntervalThink(0.03)
end

function modifier_trinity_warmup_zone:OnIntervalThink()
	if not IsServer() then
		return
	end
	if DraftSpawn and DraftSpawn.KeepHeroInWarmupZone then
		DraftSpawn:KeepHeroInWarmupZone(self:GetParent())
	end
end
