-- Модификатор-мыслитель для проверки героев в радиусе
modifier_xp_shrine_gold_thinker = modifier_xp_shrine_gold_thinker or class({})

function modifier_xp_shrine_gold_thinker:IsHidden()
    return true
end

function modifier_xp_shrine_gold_thinker:IsPurgable()
    return false
end

function modifier_xp_shrine_gold_thinker:OnCreated()
    if IsServer() then
        self.radius = 300
        self.is_active = true -- Шрайн начинается в активном состоянии
        self.heroes_used = {} -- Таблица для отслеживания героев, которые уже использовали шрайн
        self.cooldown_end_time = 0 -- Время окончания кулдауна
        
        self.game_start_time = GameRules:GetGameTime()
        
        -- Создаем активную анимацию шрайна
        self.active_particle = ParticleManager:CreateParticle("particles/units/heroes/hero_omniknight/omniknight_repel.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
        
        -- Создаем анимацию висящего камня (Aghanim's Shard)
        self.hanging_shard_particle = ParticleManager:CreateParticle("particles/items_fx/aghanims_shard_hanging.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
        
        self:GetParent():SetModel("models/props_structures/xp_shrine/xp_shrine_depleted.vmdl")
        
        -- Запускаем проверку каждые 2 секунды
        self:StartIntervalThink(2.0)
    end
end

function modifier_xp_shrine_gold_thinker:OnDestroy()
    if IsServer() then
        -- Удаляем частицы при уничтожении модификатора
        if self.active_particle then
            ParticleManager:DestroyParticle(self.active_particle, false)
            ParticleManager:ReleaseParticleIndex(self.active_particle)
        end
        if self.hanging_shard_particle then
            ParticleManager:DestroyParticle(self.hanging_shard_particle, false)
            ParticleManager:ReleaseParticleIndex(self.hanging_shard_particle)
        end
        if self.sleep_particle then
            ParticleManager:DestroyParticle(self.sleep_particle, false)
            ParticleManager:ReleaseParticleIndex(self.sleep_particle)
        end
    end
end

function modifier_xp_shrine_gold_thinker:OnIntervalThink()
    if IsServer() then
        local current_time = GameRules:GetGameTime()
        local time_since_start = current_time - self.game_start_time
        
        -- Временно убираем 7-минутную задержку для тестирования
        -- if time_since_start < 420 then -- 7 минут = 420 секунд
        --     return
        -- end
        
        -- Если шрайн спящий, не делаем ничего
        if not self.is_active then
            return
        end
        
        -- Проверяем кулдаун
        if current_time < self.cooldown_end_time then
            print("[XP SHRINE] На кулдауне, осталось: " .. (self.cooldown_end_time - current_time) .. " секунд")
            return
        end
        
        -- Восстанавливаем анимацию висящего камня после кулдауна
        if not self.hanging_shard_particle then
            print("[XP SHRINE] Восстанавливаем анимацию камня и сбрасываем список героев")
            self.hanging_shard_particle = ParticleManager:CreateParticle("particles/items_fx/aghanims_shard_hanging.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
            
            -- Сбрасываем список использовавших героев после кулдауна
            self.heroes_used = {}
            self:GetParent():SetModel("models/props_structures/xp_shrine/xp_shrine_depleted.vmdl")
        end
        
        local parent = self:GetParent()
        local parent_pos = parent:GetAbsOrigin()
        
        -- Ищем героев в радиусе
        local heroes = FindUnitsInRadius(
            parent:GetTeamNumber(),
            parent_pos,
            nil,
            self.radius,
            DOTA_UNIT_TARGET_TEAM_BOTH,
            DOTA_UNIT_TARGET_HERO,
            DOTA_UNIT_TARGET_FLAG_NONE,
            FIND_ANY_ORDER,
            false
        )
        
        -- Если есть герои в радиусе, выдаем Aghanim's Shard
        if #heroes > 0 then
            local shard_given = false
            
            for _, hero in pairs(heroes) do
                if hero:IsRealHero() and not hero:IsNull() then
                    local hero_entindex = hero:entindex()
                    
                    -- Проверяем, не получал ли этот герой уже Shard
                    if not self.heroes_used[hero_entindex] then
                        -- Проверяем, есть ли у героя уже Aghanim's Shard
                        if not hero:HasModifier("modifier_item_aghanims_shard") then
                            -- Выдаем Aghanim's Shard
                            hero:AddItemByName("item_aghanims_shard")
                            
                            -- Создаем эффект получения Shard
                            local particle = ParticleManager:CreateParticle("particles/items_fx/aghanims_shard.vpcf", PATTACH_EYES_FOLLOW, hero)
                            ParticleManager:ReleaseParticleIndex(particle)
                            
                            -- Создаем анимацию падения камня
                            local falling_shard_particle = ParticleManager:CreateParticle("particles/items_fx/aghanims_shard_falling.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
                            ParticleManager:ReleaseParticleIndex(falling_shard_particle)
                            
                            -- Проигрываем звук
                            EmitSoundOn("Item.AghanimsShard", hero)
                            
                            -- Отмечаем, что этот герой уже получил Shard
                            self.heroes_used[hero_entindex] = true
                            shard_given = true
                        end
                    end
                end
            end
            
            -- Если выдали Shard, создаем эффект на шрайне
            if shard_given then
                -- Создаем эффект на шрайне
                local shrine_particle = ParticleManager:CreateParticle("particles/items_fx/veil_of_discord.vpcf", PATTACH_ABSORIGIN_FOLLOW, parent)
                ParticleManager:ReleaseParticleIndex(shrine_particle)
                
                -- Проигрываем звук на шрайне
                EmitSoundOn("Item.VeilOfDiscord.Activate", parent)
                
                -- Устанавливаем 30-секундный кулдаун
                self.cooldown_end_time = current_time + 30.0
                
                -- Удаляем анимацию висящего камня на время кулдауна
                if self.hanging_shard_particle then
                    ParticleManager:DestroyParticle(self.hanging_shard_particle, false)
                    ParticleManager:ReleaseParticleIndex(self.hanging_shard_particle)
                    self.hanging_shard_particle = nil
                end
                self:GetParent():SetModel("models/props_structures/xp_shrine/xp_shrine_depleted.vmdl")
            end
        end
    end
end

function modifier_xp_shrine_gold_thinker:SetShrineToSleep()
    if IsServer() then
        self.is_active = false
        
        -- Удаляем активную анимацию
        if self.active_particle then
            ParticleManager:DestroyParticle(self.active_particle, false)
            ParticleManager:ReleaseParticleIndex(self.active_particle)
            self.active_particle = nil
        end
        
        -- Создаем спящую анимацию (можно использовать другую частицу или оставить без анимации)
        -- self.sleep_particle = ParticleManager:CreateParticle("particles/base_static/experience_shrine_sleep.vpcf", PATTACH_ABSORIGIN_FOLLOW, self:GetParent())
        
        -- Проигрываем звук перехода в спящий режим
        EmitSoundOn("General.ShrineDeactivate", self:GetParent())
    end
end

xp_shrine_gold = xp_shrine_gold or class({})

function xp_shrine_gold:OnSpellStart()
end

function xp_shrine_gold:OnUpgrade()
    if IsServer() then
        local caster = self:GetCaster()
        if caster then
            caster:AddNewModifier(caster, self, "modifier_xp_shrine_gold_thinker", {})
        end
    end
end

-- Регистрируем модификатор
LinkLuaModifier("modifier_xp_shrine_gold_thinker", "abilities/xp_shrine_gold", LUA_MODIFIER_MOTION_NONE)

print("SetBodygroup called") 