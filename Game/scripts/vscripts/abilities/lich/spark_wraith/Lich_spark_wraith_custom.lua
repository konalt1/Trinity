LinkLuaModifier( "modifier_lich_spark_wraith_thinker", "abilities/lich/spark_wraith/Lich_spark_wraith_custom", LUA_MODIFIER_MOTION_NONE )
LinkLuaModifier( "modifier_lich_spark_wraith_return_tracker", "abilities/lich/spark_wraith/Lich_spark_wraith_custom", LUA_MODIFIER_MOTION_NONE )

-- Глобальная таблица для хранения данных о сожженной мане
_G.lich_spark_wraith_mana_data = _G.lich_spark_wraith_mana_data or {}

lich_spark_wraith = class({})

function lich_spark_wraith:Precache(context)
	if self:GetCaster() and self:GetCaster():IsIllusion() then return end

	PrecacheResource( "particle", "particles/units/heroes/hero_arc_warden/arc_warden_wraith_cast.vpcf", context )
	PrecacheResource( "particle", "particles/units/heroes/hero_arc_warden/arc_warden_wraith.vpcf", context )
	PrecacheResource( "particle", "particles/units/heroes/hero_arc_warden/arc_warden_wraith_prj.vpcf", context )
	PrecacheResource( "sound", "Hero_ArcWarden.SparkWraith.Cast", context )
	PrecacheResource( "sound", "Hero_ArcWarden.SparkWraith.Appear", context )
	PrecacheResource( "sound", "Hero_ArcWarden.SparkWraith.Loop", context )
	PrecacheResource( "sound", "Hero_ArcWarden.SparkWraith.Activate", context )
	PrecacheResource( "sound", "Hero_ArcWarden.SparkWraith.Damage", context )
end

function lich_spark_wraith:GetAOERadius()
	return self:GetSpecialValueFor("radius")
end

function lich_spark_wraith:GetAbilityTextureName()
	return "arc_warden_spark_wraith"
end

function lich_spark_wraith:GetDamage()
	local base_damage = self:GetSpecialValueFor("spark_damage_base")
	local caster = self:GetCaster()
	
	-- Добавляем бонусный урон от Mind Power
	if caster and GetHeroMindPower then
		local mind_power = GetHeroMindPower(caster)
		local mind_power_multiplier = self:GetSpecialValueFor("mind_power_multiplier") or 0
		local bonus_damage = mind_power * mind_power_multiplier
		return base_damage + bonus_damage
	end
	
	return base_damage
end

function lich_spark_wraith:GetManaBurn()
	local base_mana_burn = self:GetSpecialValueFor("mana_burn_base")
	local caster = self:GetCaster()
	
	-- Добавляем бонус от силы разума (Mind Power)
	if caster and GetHeroMindPower then
		local mind_power = GetHeroMindPower(caster)
		local mind_power_multiplier = self:GetSpecialValueFor("mind_power_multiplier") or 0
		local bonus_mana_burn = mind_power * mind_power_multiplier
		return base_mana_burn + bonus_mana_burn
	end
	
	return base_mana_burn
end

function lich_spark_wraith:OnAbilityPhaseStart()
	self:GetCaster():EmitSound("Hero_ArcWarden.SparkWraith.Cast")
	return true
end

function lich_spark_wraith:OnSpellStart()
	local caster = self:GetCaster()
	local cast_point = self:GetCursorPosition()

	local particle = "particles/units/heroes/hero_arc_warden/arc_warden_wraith_cast.vpcf"
	local cast_particle = ParticleManager:CreateParticle(particle, PATTACH_ABSORIGIN_FOLLOW, caster)
	ParticleManager:SetParticleControl(cast_particle, 1, caster:GetAbsOrigin() + caster:GetForwardVector()*110)
	ParticleManager:ReleaseParticleIndex(cast_particle)

	EmitSoundOnLocationWithCaster(cast_point, "Hero_ArcWarden.SparkWraith.Appear", caster)

	local duration = self:GetSpecialValueFor("duration")

	CreateModifierThinker(caster, self, "modifier_lich_spark_wraith_thinker", {duration = duration}, cast_point + Vector(0, 0, 10), caster:GetTeamNumber(), false)
end 

function lich_spark_wraith:DealDamage(target, not_main)
	if not IsServer() then return end 

	local caster = self:GetCaster() 
	local damage = self:GetDamage()

	local k = 1
	if not_main then 
		k = self:GetSpecialValueFor("damage_near")/100
	end

	target:EmitSound("Hero_ArcWarden.SparkWraith.Damage")

	-- Нанесение урона
	ApplyDamage({
		victim = target,
		damage = damage * k,
		damage_type = DAMAGE_TYPE_MAGICAL,
		attacker = caster,
		ability = self
	})
end 

function lich_spark_wraith:LaunchSpark(target, source)
	if not IsServer() then return end 

	local caster = self:GetCaster()
	local speed = self:GetSpecialValueFor("wraith_speed_base")
	local wraith_vision_radius = self:GetSpecialValueFor("wraith_vision_radius")
	local origin = source:GetAbsOrigin()

	source:EmitSound("Hero_ArcWarden.SparkWraith.Activate")

	local proj_pfx = "particles/units/heroes/hero_arc_warden/arc_warden_wraith_prj.vpcf"

	ProjectileManager:CreateTrackingProjectile({
		EffectName = proj_pfx,
		Ability = self,
		Source = source,
		vSourceLoc = origin,
		Target = target,
		iMoveSpeed = speed,
		bDodgeable = false,
		bVisibleToEnemies = true,
		bProvidesVision = true,
		iVisionRadius = wraith_vision_radius,
		iVisionTeamNumber = caster:GetTeamNumber(),
	})
end

function lich_spark_wraith:LaunchSparkReturn(origin, target_entity, initial_mana_burned)
	if not IsServer() then return end 

	local caster = self:GetCaster()
	local speed = self:GetSpecialValueFor("wraith_speed_base")
	local wraith_vision_radius = self:GetSpecialValueFor("wraith_vision_radius")

	local proj_pfx = "particles/units/heroes/hero_arc_warden/arc_warden_wraith_prj.vpcf"

	-- Создаем уникальный ID для этого снаряда
	local projectile_id = DoUniqueString("spark_wraith_return")
	
	-- Инициализируем счетчик с уже сожженной маной
	_G.lich_spark_wraith_mana_data[projectile_id] = initial_mana_burned or 0

	-- Создаем thinker для отслеживания коллизий
	CreateModifierThinker(
		caster, 
		self, 
		"modifier_lich_spark_wraith_return_tracker", 
		{
			speed = speed,
			projectile_id = projectile_id,
			original_target_id = target_entity:GetEntityIndex()
		}, 
		origin, 
		caster:GetTeamNumber(), 
		false
	)

	ProjectileManager:CreateTrackingProjectile({
		EffectName = proj_pfx,
		Ability = self,
		vSourceLoc = origin,
		Target = caster,
		iMoveSpeed = speed,
		bDodgeable = false,
		bVisibleToEnemies = true,
		bProvidesVision = true,
		iVisionRadius = wraith_vision_radius,
		iVisionTeamNumber = caster:GetTeamNumber(),
		ExtraData = {
			is_returning = 1,
			projectile_id = projectile_id
		}
	})
end 

function lich_spark_wraith:OnProjectileHit_ExtraData(target, location, ExtraData)
	if not target then return end

	local caster = self:GetCaster()
	
	-- Если это возвращающийся снаряд
	if ExtraData and ExtraData.is_returning == 1 then
		-- Если снаряд достиг Лича - восстанавливаем ману
		if target == caster then
			local projectile_id = ExtraData.projectile_id
			local mana_to_restore = _G.lich_spark_wraith_mana_data[projectile_id] or 0
			
			-- Восстанавливаем ману только если Лич жив
			if caster:IsAlive() and mana_to_restore > 0 then
				local current_mana = caster:GetMana()
				local max_mana = caster:GetMaxMana()
				local new_mana = math.min(current_mana + mana_to_restore, max_mana)
				caster:SetMana(new_mana)
				
				-- Визуальный эффект восстановления маны
				SendOverheadEventMessage(nil, OVERHEAD_ALERT_MANA_ADD, caster, mana_to_restore, nil)
			end
			
			-- Очищаем данные из глобальной таблицы
			_G.lich_spark_wraith_mana_data[projectile_id] = nil
		end
		return true
	end

	local damage_radius = self:GetSpecialValueFor("damage_radius")

	AddFOWViewer(caster:GetTeamNumber(), location, self:GetSpecialValueFor("wraith_vision_radius"), self:GetSpecialValueFor("wraith_vision_duration"), true)

	-- Нанесение урона в области
	local enemies = FindUnitsInRadius(
		caster:GetTeamNumber(),
		target:GetAbsOrigin(),
		nil,
		damage_radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_NONE,
		FIND_ANY_ORDER,
		false
	)

	local total_mana_burned = 0
	local mana_burn = self:GetManaBurn()

	for _, unit in pairs(enemies) do 
		self:DealDamage(unit, unit ~= target)
		
		-- Сжигаем ману при основном попадании
		if unit:GetMana() > 0 then
			local current_mana = unit:GetMana()
			local mana_to_burn = math.min(mana_burn, current_mana)
			unit:SetMana(current_mana - mana_to_burn)
			total_mana_burned = total_mana_burned + mana_to_burn
			
			-- Визуальный эффект
			SendOverheadEventMessage(nil, OVERHEAD_ALERT_MANA_LOSS, unit, mana_to_burn, nil)
		else
			-- Если у цели нет маны (крипы), считаем полное сжигание маны как потенциальную сожженную ману
			total_mana_burned = total_mana_burned + mana_burn
		end
	end

	-- Возвращаем спарк к личу при попадании по любой цели
	if caster:IsAlive() then
		self:LaunchSparkReturn(target:GetAbsOrigin(), target, total_mana_burned)
	end

	return true
end

--------------------------------------------------------------------------------
-- Modifier: Thinker (Spark Wraith на земле)
--------------------------------------------------------------------------------
modifier_lich_spark_wraith_thinker = class({})

function modifier_lich_spark_wraith_thinker:IsHidden()
	return true
end

function modifier_lich_spark_wraith_thinker:IsPurgable()
	return false
end

function modifier_lich_spark_wraith_thinker:OnCreated(table)
	self.ability = self:GetAbility()
	self.parent = self:GetParent()
	self.caster = self:GetCaster()
	self.radius = self.ability:GetSpecialValueFor("radius")
	self.activation_delay = self.ability:GetSpecialValueFor("base_activation_delay")
	self.think_interval = self.ability:GetSpecialValueFor("think_interval")
	self.wraith_vision_radius = self.ability:GetSpecialValueFor("wraith_vision_radius")

	if not IsServer() then return end

	self.parent:EmitSound("Hero_ArcWarden.SparkWraith.Loop")

	local particle_name = "particles/units/heroes/hero_arc_warden/arc_warden_wraith.vpcf"
	self.wraith_particle = ParticleManager:CreateParticle(particle_name, PATTACH_ABSORIGIN_FOLLOW, self.parent)
	ParticleManager:SetParticleControl(self.wraith_particle, 1, Vector(self.radius, 1, 1))
	self:AddParticle(self.wraith_particle, false, false, -1, false, false)

	self.origin = self.parent:GetAbsOrigin()

	AddFOWViewer(self.caster:GetTeamNumber(), self.origin, self.wraith_vision_radius, self.activation_delay, false)

	self:StartIntervalThink(self.activation_delay)
end

function modifier_lich_spark_wraith_thinker:OnIntervalThink()
	if not IsServer() then return end 

	AddFOWViewer(self.caster:GetTeamNumber(), self.origin, self.wraith_vision_radius, self.think_interval, false)

	-- Поиск врагов в радиусе
	local enemies = FindUnitsInRadius(
		self.caster:GetTeamNumber(),
		self.origin,
		nil,
		self.radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES + DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE + DOTA_UNIT_TARGET_FLAG_NO_INVIS,
		FIND_CLOSEST,
		false
	)

	if #enemies > 0 then
		self.ability:LaunchSpark(enemies[1], self.parent)
		self:Destroy()
		return
	end

	self:StartIntervalThink(self.think_interval)
end

function modifier_lich_spark_wraith_thinker:OnDestroy()
	if not IsServer() then return end
	self.parent:StopSound("Hero_ArcWarden.SparkWraith.Loop")
end

--------------------------------------------------------------------------------
-- Modifier: Return Tracker (отслеживание коллизий возвращающегося снаряда)
--------------------------------------------------------------------------------
modifier_lich_spark_wraith_return_tracker = class({})

function modifier_lich_spark_wraith_return_tracker:IsHidden()
	return true
end

function modifier_lich_spark_wraith_return_tracker:IsPurgable()
	return false
end

function modifier_lich_spark_wraith_return_tracker:OnCreated(params)
	if not IsServer() then return end

	self.parent = self:GetParent()
	self.caster = self:GetCaster()
	self.ability = self:GetAbility()
	
	-- Получаем параметры движения
	self.speed = params.speed
	self.collision_radius = 150 -- Радиус проверки коллизий
	self.projectile_id = params.projectile_id
	self.original_target_id = params.original_target_id -- ID оригинальной цели для исключения
	self.finish_distance = 100 -- Расстояние до Лича, на котором tracker уничтожается
	
	-- Интервал проверки (чем меньше, тем точнее, но больше нагрузка)
	self.think_interval = 0.03
	
	-- Таблица для отслеживания уже пораженных целей
	self.hit_targets = {}
	
	-- Счетчик сожженной маны (для отслеживания локально)
	self.total_mana_burned = 0
	
	self:StartIntervalThink(self.think_interval)
end

function modifier_lich_spark_wraith_return_tracker:OnIntervalThink()
	if not IsServer() then return end
	
	-- Проверяем, жив ли Лич
	if not self.caster:IsAlive() then
		self:Destroy()
		return
	end
	
	-- Получаем текущие позиции
	local current_pos = self.parent:GetAbsOrigin()
	local target_pos = self.caster:GetAbsOrigin()
	
	-- Вычисляем расстояние до Лича
	local distance_to_lich = (target_pos - current_pos):Length2D()
	
	-- Проверяем, достигли ли Лича
	if distance_to_lich <= self.finish_distance then
		self:Destroy()
		return
	end
	
	-- Вычисляем направление к Личу (обновляется каждый тик!)
	local direction = (target_pos - current_pos):Normalized()
	
	-- Двигаем thinker к Личу
	local move_distance = self.speed * self.think_interval
	local new_pos = current_pos + direction * move_distance
	self.parent:SetAbsOrigin(new_pos)
	
	-- Проверяем коллизии с врагами
	local enemies = FindUnitsInRadius(
		self.caster:GetTeamNumber(),
		self.parent:GetAbsOrigin(),
		nil,
		self.collision_radius,
		DOTA_UNIT_TARGET_TEAM_ENEMY,
		DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
		DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES + DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE,
		FIND_ANY_ORDER,
		false
	)
	
	-- Если нашли врагов - проверяем, не были ли они уже задеты
	if #enemies > 0 then
		for _, enemy in pairs(enemies) do
			local enemy_id = enemy:GetEntityIndex()
			
			-- Исключаем оригинальную цель (она уже получила урон при первом попадании)
			if enemy_id ~= self.original_target_id and not self.hit_targets[enemy_id] then
				self.hit_targets[enemy_id] = true
				
				local damage = self.ability:GetDamage()
				local mana_burn = self.ability:GetManaBurn()
				
				-- Наносим урон
				ApplyDamage({
					victim = enemy,
					damage = damage,
					damage_type = DAMAGE_TYPE_MAGICAL,
					attacker = self.caster,
					ability = self.ability
				})
				
				-- Сжигаем ману (независимо от урона)
				local mana_to_add = 0
				if enemy:GetMana() > 0 then
					local current_mana = enemy:GetMana()
					local mana_to_burn = math.min(mana_burn, current_mana)
					enemy:SetMana(current_mana - mana_to_burn)
					mana_to_add = mana_to_burn
					
					-- Визуальный эффект
					SendOverheadEventMessage(nil, OVERHEAD_ALERT_MANA_LOSS, enemy, mana_to_burn, nil)
				else
					-- Если у цели нет маны (крипы), считаем полное сжигание маны как потенциальную сожженную ману
					mana_to_add = mana_burn
				end
				
				-- Добавляем к общему счетчику сожженной маны
				self.total_mana_burned = self.total_mana_burned + mana_to_add
				local current_total = _G.lich_spark_wraith_mana_data[self.projectile_id] or 0
				_G.lich_spark_wraith_mana_data[self.projectile_id] = current_total + mana_to_add
			end
		end
	end
end

function modifier_lich_spark_wraith_return_tracker:OnDestroy()
	if not IsServer() then return end
	
	-- Если Лич мертв - очищаем данные, так как снаряд не восстановит ману
	if not self.caster:IsAlive() then
		if self.projectile_id and _G.lich_spark_wraith_mana_data[self.projectile_id] then
			_G.lich_spark_wraith_mana_data[self.projectile_id] = nil
		end
	end
	-- Иначе НЕ очищаем данные! Tracker уничтожается при достижении цели, 
	-- но снаряд еще не попал в Лича. Очистка происходит в OnProjectileHit_ExtraData
end
