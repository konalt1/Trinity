modifier_lich_frost_armor_lua = class({})

--------------------------------------------------------------------------------
-- Classifications
function modifier_lich_frost_armor_lua:IsHidden()
	return true
end

function modifier_lich_frost_armor_lua:IsDebuff()
	return false
end

function modifier_lich_frost_armor_lua:IsPurgable()
	return false
end

--------------------------------------------------------------------------------
-- Initializations
function modifier_lich_frost_armor_lua:OnCreated( kv )
end

function modifier_lich_frost_armor_lua:OnRefresh( kv )
end

function modifier_lich_frost_armor_lua:OnDestroy( kv )
end

--------------------------------------------------------------------------------
-- Modifier Effects
function modifier_lich_frost_armor_lua:DeclareFunctions()
	local funcs = {
		-- Убираем автоматический каст
	}

	return funcs
end