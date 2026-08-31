LinkLuaModifier(
    "modifier_caravan_aghanim_laser_thinker",
    "map_modifications/Bosses/caravan/caravan_aghanim_laser",
    LUA_MODIFIER_MOTION_NONE
)
LinkLuaModifier(
    "modifier_caravan_aghanim_laser_debuff",
    "map_modifications/Bosses/caravan/caravan_aghanim_laser",
    LUA_MODIFIER_MOTION_NONE
)

caravan_aghanim_laser = class({})

local function IsValidUnit(unit)
    return unit and not unit:IsNull() and IsValidEntity(unit)
end

local function Assets()
    if not CaravanAssets then
        require("map_modifications/Bosses/caravan/caravan_assets")
    end
    return CaravanAssets
end

function caravan_aghanim_laser:Precache(context)
    local assets = Assets()
    PrecacheResource("particle", assets.PARTICLE.beam_channel, context)
    PrecacheResource("particle", assets.PARTICLE.staff_beam, context)
    PrecacheResource("particle", assets.PARTICLE.staff_beam_tgt, context)
    PrecacheResource("particle", assets.PARTICLE.staff_beam_linger, context)
    PrecacheResource("particle", assets.PARTICLE.laser_status, context)
    PrecacheResource("soundfile", "soundevents/game_sounds_heroes/game_sounds_leshrac.vsndevts", context)
end

function caravan_aghanim_laser:GetChannelTime()
    return self:GetSpecialValueFor("channel_time")
end

function caravan_aghanim_laser:OnSpellStart()
    if not IsServer() then
        return
    end

    local caster = self:GetCaster()
    local duration = self:GetChannelTime()
    if CourierCaravan and CourierCaravan.MarkAghanimBusy then
        CourierCaravan:MarkAghanimBusy(caster, duration + 0.1)
    end

    caster:StartGesture(ACT_DOTA_CAST_ABILITY_2)
    caster:EmitSound("Hero_Leshrac.Pulse_Nova")

    local assets = Assets()
    self.channelFx = ParticleManager:CreateParticle(assets.PARTICLE.beam_channel, PATTACH_ABSORIGIN_FOLLOW, caster)
    self.laserThinkers = {}
    self:SyncBeams()
end

function caravan_aghanim_laser:OnChannelThink(interval)
    if not IsServer() then
        return
    end

    self.syncAccum = (self.syncAccum or 0) + (interval or 0.03)
    if self.syncAccum < 0.45 then
        return
    end

    self.syncAccum = 0
    self:SyncBeams()
end

function caravan_aghanim_laser:OnChannelFinish()
    if not IsServer() then
        return
    end

    local caster = self:GetCaster()
    if caster and not caster:IsNull() then
        caster:StopSound("Hero_Leshrac.Pulse_Nova")
        caster:RemoveGesture(ACT_DOTA_CAST_ABILITY_2)
    end

    if self.channelFx then
        ParticleManager:DestroyParticle(self.channelFx, false)
        ParticleManager:ReleaseParticleIndex(self.channelFx)
        self.channelFx = nil
    end

    if self.laserThinkers then
        for _, thinker in pairs(self.laserThinkers) do
            if thinker and not thinker:IsNull() then
                UTIL_Remove(thinker)
            end
        end
        self.laserThinkers = {}
    end

    if CourierCaravan and CourierCaravan.FinishAghanimCast then
        CourierCaravan:FinishAghanimCast(caster)
    end
end

function caravan_aghanim_laser:SyncBeams()
    local caster = self:GetCaster()
    if not IsValidUnit(caster) then
        return
    end

    self.laserThinkers = self.laserThinkers or {}
    local radius = self:GetSpecialValueFor("radius")
    local duration = self:GetSpecialValueFor("channel_time")
    local enemies = FindUnitsInRadius(
        caster:GetTeamNumber(),
        caster:GetAbsOrigin(),
        nil,
        radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO,
        DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES + DOTA_UNIT_TARGET_FLAG_FOW_VISIBLE,
        FIND_ANY_ORDER,
        false
    )

    for _, hero in ipairs(enemies) do
        if hero and hero:IsRealHero() and hero:IsAlive() then
            local index = hero:entindex()
            local existing = self.laserThinkers[index]
            if not existing or existing:IsNull() then
                local thinker = CreateModifierThinker(
                    caster,
                    self,
                    "modifier_caravan_aghanim_laser_thinker",
                    {
                        duration = duration,
                        target_entindex = index,
                    },
                    caster:GetAbsOrigin(),
                    caster:GetTeamNumber(),
                    false
                )
                self.laserThinkers[index] = thinker
            end
        end
    end
end

modifier_caravan_aghanim_laser_thinker = class({})

function modifier_caravan_aghanim_laser_thinker:IsHidden()
    return true
end

function modifier_caravan_aghanim_laser_thinker:IsPurgable()
    return false
end

function modifier_caravan_aghanim_laser_thinker:OnCreated(keys)
    if not IsServer() then
        return
    end

    self.target = keys and EntIndexToHScript(keys.target_entindex or -1) or nil
    local caster = self:GetCaster()
    self.beamPos = caster and caster:GetAbsOrigin() or self:GetParent():GetAbsOrigin()
    self.timeUnderBeam = 0
    self.interval = 0.03
    self.lingerAccum = 0
    self.lingerFx = {}

    local assets = Assets()
    local parent = self:GetParent()
    self.beamFx = ParticleManager:CreateParticle(assets.PARTICLE.staff_beam, PATTACH_CUSTOMORIGIN, caster)
    self.tgtFx = ParticleManager:CreateParticle(assets.PARTICLE.staff_beam_tgt, PATTACH_CUSTOMORIGIN, parent)
    self:UpdateParticle()
    self:StartIntervalThink(self.interval)
end

function modifier_caravan_aghanim_laser_thinker:UpdateParticle()
    local caster = self:GetCaster()
    local assets = Assets()
    local startPos = assets:GetAttachOrigin(caster)
    local endPos = self.beamPos + Vector(0, 0, 8)
    local attachName = assets:GetAttachName(caster)

    if self.beamFx then
        if caster and not caster:IsNull() and attachName then
            ParticleManager:SetParticleControlEnt(
                self.beamFx,
                0,
                caster,
                PATTACH_POINT_FOLLOW,
                attachName,
                startPos,
                true
            )
        else
            ParticleManager:SetParticleControl(self.beamFx, 0, startPos)
        end
        ParticleManager:SetParticleControl(self.beamFx, 1, endPos)
        ParticleManager:SetParticleControl(self.beamFx, 9, endPos)
    end

    if self.tgtFx then
        ParticleManager:SetParticleControl(self.tgtFx, 0, endPos)
        ParticleManager:SetParticleControl(self.tgtFx, 1, endPos)
    end
end

function modifier_caravan_aghanim_laser_thinker:DestroyFx(fx, immediate)
    if not fx then
        return
    end

    ParticleManager:DestroyParticle(fx, immediate == true)
    ParticleManager:ReleaseParticleIndex(fx)
end

function modifier_caravan_aghanim_laser_thinker:DropLinger()
    local assets = Assets()
    local fx = ParticleManager:CreateParticle(assets.PARTICLE.staff_beam_linger, PATTACH_WORLDORIGIN, nil)
    ParticleManager:SetParticleControl(fx, 0, self.beamPos)
    ParticleManager:SetParticleControl(fx, 1, self.beamPos)
    self.lingerFx = self.lingerFx or {}
    table.insert(self.lingerFx, fx)

    local thinker = self
    Timers:CreateTimer(0.65, function()
        if not thinker or thinker:IsNull() then
            return nil
        end

        for i, stored in ipairs(thinker.lingerFx or {}) do
            if stored == fx then
                table.remove(thinker.lingerFx, i)
                break
            end
        end
        thinker:DestroyFx(fx, false)
        return nil
    end)
end

function modifier_caravan_aghanim_laser_thinker:OnIntervalThink()
    if not IsServer() then
        return
    end

    local caster = self:GetCaster()
    local target = self.target
    local parent = self:GetParent()
    if not IsValidUnit(caster) or not IsValidUnit(target) or not target:IsAlive() then
        self:Destroy()
        return
    end

    if not caster:IsChanneling() then
        self:Destroy()
        return
    end

    local ability = self:GetAbility()
    local followSpeed = ability and ability:GetSpecialValueFor("follow_speed") or 220
    local beamWidth = ability and ability:GetSpecialValueFor("beam_width") or 90
    local toTarget = target:GetAbsOrigin() - self.beamPos
    toTarget.z = 0
    local distance = toTarget:Length2D()
    local maxStep = followSpeed * self.interval
    if distance > 0 then
        if distance <= maxStep then
            self.beamPos = target:GetAbsOrigin()
        else
            self.beamPos = self.beamPos + toTarget:Normalized() * maxStep
        end
    end
    self.beamPos.z = GetGroundHeight(self.beamPos, target)
    parent:SetAbsOrigin(self.beamPos)
    self:UpdateParticle()

    self.lingerAccum = (self.lingerAccum or 0) + self.interval
    if self.lingerAccum >= 0.4 then
        self.lingerAccum = 0
        self:DropLinger()
    end

    local offset = target:GetAbsOrigin() - self.beamPos
    offset.z = 0
    if offset:Length2D() <= beamWidth then
        self.timeUnderBeam = self.timeUnderBeam + self.interval
        local baseDamage = ability and ability:GetSpecialValueFor("base_damage") or 20
        local ramp = ability and ability:GetSpecialValueFor("damage_ramp") or 12
        local damage = (baseDamage + self.timeUnderBeam * ramp) * self.interval
        ApplyDamage({
            attacker = caster,
            victim = target,
            damage = damage,
            damage_type = DAMAGE_TYPE_MAGICAL,
            ability = ability,
        })
        local debuffDuration = ability and ability:GetSpecialValueFor("debuff_linger") or 0.4
        target:AddNewModifier(caster, ability, "modifier_caravan_aghanim_laser_debuff", {
            duration = debuffDuration,
        })
    end
end

function modifier_caravan_aghanim_laser_thinker:OnDestroy()
    if not IsServer() then
        return
    end

    if self.beamFx then
        self:DestroyFx(self.beamFx, true)
        self.beamFx = nil
    end
    if self.tgtFx then
        self:DestroyFx(self.tgtFx, true)
        self.tgtFx = nil
    end

    for _, fx in ipairs(self.lingerFx or {}) do
        self:DestroyFx(fx, true)
    end
    self.lingerFx = {}
end

modifier_caravan_aghanim_laser_debuff = class({})

function modifier_caravan_aghanim_laser_debuff:IsHidden()
    return false
end

function modifier_caravan_aghanim_laser_debuff:IsDebuff()
    return true
end

function modifier_caravan_aghanim_laser_debuff:IsPurgable()
    return true
end

function modifier_caravan_aghanim_laser_debuff:OnCreated()
    local ability = self:GetAbility()
    self.slow = ability and ability:GetSpecialValueFor("slow_pct") or 30
    self.miss = ability and ability:GetSpecialValueFor("miss_pct") or 100
end

function modifier_caravan_aghanim_laser_debuff:OnRefresh()
    self:OnCreated()
end

function modifier_caravan_aghanim_laser_debuff:DeclareFunctions()
    return {
        MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
        MODIFIER_PROPERTY_MISS_PERCENTAGE,
    }
end

function modifier_caravan_aghanim_laser_debuff:GetModifierMoveSpeedBonus_Percentage()
    return -self.slow
end

function modifier_caravan_aghanim_laser_debuff:GetModifierMiss_Percentage()
    return self.miss
end

function modifier_caravan_aghanim_laser_debuff:GetStatusEffectName()
    return "particles/status_fx/status_effect_electrical.vpcf"
end

function modifier_caravan_aghanim_laser_debuff:GetTexture()
    return "phoenix_sun_ray"
end
