-- Created by Elfansoer
--[[
    Generic Jump Arc

    kv data (default):
    -- direction, provide just one (or none for default):
        dir_x/y (forward), for direction
        target_x/y (forward), for target point
    -- horizontal motion, provide 2 of 3, duration-only (for vertical arc), or all 3
        speed (0)
        duration (0)
        distance (0): zero means no horizontal motion
    -- vertical motion.
        height (0): max height. zero means no vertical motion
        start_offset (0), height offset from ground at start of jump
        end_offset (0), height offset from ground at end of jump
    -- arc types (use true/false or 1/0; omitted = default below)
        fix_end (default true): if true, landing z-pos is the same as jumping z-pos, not respecting on landing terrain height (Pounce)
        fix_duration (default true): if false, arc ends when unit touches ground, not respecting duration (Shield Crash)
        fix_height (default true): if false, arc max height depends on jump distance, height provided is max-height (Tree Dance)
    -- other
        isStun (false), parent is stunned
        isRestricted (false), parent is command restricted
        isForward (false), lock parent forward facing
        activity (none), activity when leaping
]]
-- Plain modifier: motion is driven by OnIntervalThink (motion controllers are nil in some environments).
LinkLuaModifier("modifier_generic_arc_lua", "modifiers/modifier_generic_arc_lua", 0)

modifier_generic_arc_lua = class({})

--------------------------------------------------------------------------------
-- Classifications
function modifier_generic_arc_lua:IsHidden()
	return true
end

function modifier_generic_arc_lua:IsDebuff()
	return false
end

function modifier_generic_arc_lua:IsStunDebuff()
	return false
end

function modifier_generic_arc_lua:IsPurgable()
	return false
end

function modifier_generic_arc_lua:GetAttributes()
	return MODIFIER_ATTRIBUTE_MULTIPLE
end

--------------------------------------------------------------------------------
-- Initializations
function modifier_generic_arc_lua:OnCreated(kv)
	if not IsServer() then
		return
	end
	self:StartIntervalThink(-1)
	self.ability = self:GetAbility()
	self.interrupted = false
	self:SetJumpParameters(kv)
	self.lastThinkGameTime = GameRules:GetGameTime() - (1 / 120)
	self:StartIntervalThink(1 / 120)
end

function modifier_generic_arc_lua:OnRefresh(kv)
	self:OnCreated(kv)
end

function modifier_generic_arc_lua:OnRemoved()
end

function modifier_generic_arc_lua:OnDestroy()
	if not IsServer() then
		return
	end

	self:StartIntervalThink(-1)

	-- preserve height
	local pos = self:GetParent():GetOrigin()

	-- preserve height if has end offset
	if self.end_offset ~= 0 then
		self:GetParent():SetOrigin(pos)
	end

	if self.endCallback then
		self.endCallback(self.interrupted)
	end
end

--------------------------------------------------------------------------------
-- Modifier Effects
function modifier_generic_arc_lua:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_DISABLE_TURNING,
	}
	if self:GetStackCount() > 0 then
		table.insert(funcs, MODIFIER_PROPERTY_OVERRIDE_ANIMATION)
	end

	return funcs
end

function modifier_generic_arc_lua:GetModifierDisableTurning()
	if not self.isForward then
		return
	end
	return 1
end

function modifier_generic_arc_lua:GetOverrideAnimation()
	return self:GetStackCount()
end

--------------------------------------------------------------------------------
-- Status Effects
function modifier_generic_arc_lua:CheckState()
	local state = {
		[MODIFIER_STATE_STUNNED] = self.isStun or false,
		[MODIFIER_STATE_COMMAND_RESTRICTED] = self.isRestricted or false,
		[MODIFIER_STATE_NO_UNIT_COLLISION] = true,
	}
	return state
end

--------------------------------------------------------------------------------
-- Manual motion (no Apply*MotionController)
function modifier_generic_arc_lua:OnIntervalThink()
	if not IsServer() then
		return
	end
	local parent = self:GetParent()
	if parent == nil or parent:IsNull() then
		self.interrupted = true
		self:Destroy()
		return
	end

	local now = GameRules:GetGameTime()
	local dt = now - (self.lastThinkGameTime or now)
	self.lastThinkGameTime = now
	if dt <= 0 then
		dt = 1 / 120
	end
	if dt > 0.15 then
		dt = 0.15
	end

	self:ArcPhysicsStep(parent, dt)
end

--------------------------------------------------------------------------------
-- Motion step helpers
function modifier_generic_arc_lua:ArcPhysicsStep(me, dt)
	if self.fix_duration then
		self:ArcPhysicsStepFixedDuration(me, dt)
	else
		self:UpdateHorizontalMotion(me, dt)
		self:UpdateVerticalMotion(me, dt)
	end
end

-- Fixed-duration arcs: one timeline (arc_time) for H+V so we never overshoot distance
-- (GameRules dt vs GetElapsedTime() desync + last full-dt step caused flying past the click).
function modifier_generic_arc_lua:ArcPhysicsStepFixedDuration(me, dt)
	local t0 = self.arc_time or 0
	if t0 >= self.duration then
		return
	end

	local step_dt = math.min(dt, self.duration - t0)
	if step_dt <= 0 then
		return
	end

	local t1 = t0 + step_dt
	local pos = me:GetOrigin()

	local h_done = 0
	if self.distance > 0 and self.duration > 0 then
		h_done = math.min(self.distance, self.speed * math.min(t1, self.duration))
	end
	pos.x = self.arc_origin.x + self.direction.x * h_done
	pos.y = self.arc_origin.y + self.direction.y * h_done

	if self.height > 0 and self.const1 then
		local vz = self:GetVerticalSpeed(t0)
		pos.z = pos.z + vz * step_dt
	end

	me:SetOrigin(pos)
	self.arc_time = t1

	-- End as soon as the arc timeline is done; do not wait on SetDuration (different clock → hang before landing).
	if t1 >= self.duration - 1e-4 then
		self:StartIntervalThink(-1)
		self:Destroy()
	end
end

function modifier_generic_arc_lua:UpdateHorizontalMotion(me, dt)
	if self.fix_duration and self:GetElapsedTime() >= self.duration then
		return
	end

	-- set relative position
	local pos = me:GetOrigin() + self.direction * self.speed * dt
	me:SetOrigin(pos)
end

function modifier_generic_arc_lua:UpdateVerticalMotion(me, dt)
	if self.fix_duration and self:GetElapsedTime() >= self.duration then
		return
	end

	local pos = me:GetOrigin()
	local time = self:GetElapsedTime()

	-- set relative position
	local height = pos.z
	local speed = self:GetVerticalSpeed(time)
	pos.z = height + speed * dt
	me:SetOrigin(pos)

	if not self.fix_duration then
		local ground = GetGroundHeight(pos, me) + self.end_offset
		if pos.z <= ground then

			-- below ground, set height as ground then destroy
			pos.z = ground
			me:SetOrigin(pos)
			self:Destroy()
		end
	end
end

--------------------------------------------------------------------------------
-- Motion Helper
local function modifier_generic_arc_kv_bool(kv, key, default)
	local v = kv[key]
	if v == nil then
		return default
	end
	if v == false or v == 0 then
		return false
	end
	if v == true or v == 1 then
		return true
	end
	return default
end

function modifier_generic_arc_lua:SetJumpParameters(kv)
	self.parent = self:GetParent()

	self.fix_end = modifier_generic_arc_kv_bool(kv, "fix_end", true)
	self.fix_duration = modifier_generic_arc_kv_bool(kv, "fix_duration", true)
	self.fix_height = modifier_generic_arc_kv_bool(kv, "fix_height", true)

	-- load other types
	self.isStun = kv.isStun == 1
	self.isRestricted = kv.isRestricted == 1
	self.isForward = kv.isForward == 1
	self.activity = kv.activity or 0
	self:SetStackCount(self.activity)

	-- load direction
	if kv.target_x and kv.target_y then
		local origin = self.parent:GetOrigin()
		local dir = Vector(kv.target_x, kv.target_y, 0) - origin
		dir.z = 0
		dir = dir:Normalized()
		self.direction = dir
	end
	if kv.dir_x and kv.dir_y then
		self.direction = Vector(kv.dir_x, kv.dir_y, 0):Normalized()
	end
	if not self.direction then
		self.direction = self.parent:GetForwardVector()
	end

	-- load horizontal data
	self.duration = kv.duration
	self.distance = kv.distance
	self.speed = kv.speed
	if not self.duration then
		self.duration = self.distance / self.speed
	end
	if not self.distance then
		self.speed = self.speed or 0
		self.distance = self.speed * self.duration
	end
	if not self.speed then
		self.distance = self.distance or 0
		self.speed = self.distance / self.duration
	end

	-- load vertical data
	self.height = kv.height or 0
	self.start_offset = kv.start_offset or 0
	self.end_offset = kv.end_offset or 0

	-- calculate height positions
	local pos_start = self.parent:GetOrigin()
	local pos_end = pos_start + self.direction * self.distance
	local height_start = GetGroundHeight(pos_start, self.parent) + self.start_offset
	local height_end = GetGroundHeight(pos_end, self.parent) + self.end_offset
	local height_max

	-- determine jumping height if not fixed
	if not self.fix_height then

		-- ideal height is proportional to max distance
		self.height = math.min(self.height, self.distance / 4)
	end

	-- determine height max
	if self.fix_end then
		height_end = height_start
		height_max = height_start + self.height
	else
		-- calculate height
		local tempmin, tempmax = height_start, height_end
		if tempmin > tempmax then
			tempmin, tempmax = tempmax, tempmin
		end
		local delta = (tempmax - tempmin) * 2 / 3

		height_max = tempmin + delta + self.height
	end

	-- set duration
	if not self.fix_duration then
		self:SetDuration(-1, false)
	else
		self:SetDuration(self.duration, true)
	end

	-- calculate arc
	if self.duration > 0 then
		self:InitVerticalArc(height_start, height_max, height_end, self.duration)
	end

	local o = self.parent:GetOrigin()
	self.arc_origin = Vector(o.x, o.y, o.z)
	self.arc_time = 0
end

function modifier_generic_arc_lua:InitVerticalArc(height_start, height_max, height_end, duration)
	local height_end = height_end - height_start
	local height_max = height_max - height_start

	-- fail-safe1: height_max cannot be smaller than height delta
	if height_max < height_end then
		height_max = height_end + 0.01
	end

	-- fail-safe2: height-max must be positive
	if height_max <= 0 then
		height_max = 0.01
	end

	-- math magic
	local duration_end = (1 + math.sqrt(1 - height_end / height_max)) / 2
	self.const1 = 4 * height_max * duration_end / duration
	self.const2 = 4 * height_max * duration_end * duration_end / (duration * duration)
end

function modifier_generic_arc_lua:GetVerticalPos(time)
	return self.const1 * time - self.const2 * time * time
end

function modifier_generic_arc_lua:GetVerticalSpeed(time)
	return self.const1 - 2 * self.const2 * time
end

--------------------------------------------------------------------------------
-- Helper
function modifier_generic_arc_lua:SetEndCallback(func)
	self.endCallback = func
end
