-- Метка лесного крипа, который несёт бун (game_managers/neutral_boons.lua).
-- Знак над головой как у Track Охотника за головами, только синий (цвет осколка Аганима):
-- particles/neutral_boons/boon_carrier_mark.vpcf (исходник в content/.../particles/neutral_boons/).
-- Эффект модификатора виден всем, но только пока крип виден: в тумане войны метки нет.
-- Отдельный файл без require и return: движок загружает его сам при создании модификатора.
--
-- Для отладки есть два запасных вида метки (команда neutral_boons_mark_effect red|aegis|blue):
-- знак Track (свой particles/map/boons/bounty_hunter_track_shield_mark.vpcf, вид red — по умолчанию) и свечение Аегиса на земле. Каждый вид — свой класс, чтобы эффект
-- не зависел от данных, которые клиент может получить позже модификатора.

local function DefineMark(name, effect, attach)
    local modifier = class({})

    function modifier:IsHidden() return false end
    function modifier:IsPurgable() return false end
    function modifier:IsPurgeException() return false end
    function modifier:RemoveOnDeath() return true end
    function modifier:IsDebuff() return false end
    function modifier:GetTexture() return "item_boon_aghanim" end
    function modifier:GetEffectName() return effect end
    function modifier:GetEffectAttachType() return attach end

    _G[name] = modifier
    if getfenv then
        local env = getfenv(1)
        if env then
            env[name] = modifier
        end
    end
end

DefineMark("modifier_neutral_boon_carrier",
    "particles/neutral_boons/boon_carrier_mark.vpcf", PATTACH_OVERHEAD_FOLLOW)
DefineMark("modifier_neutral_boon_carrier_red",
    "particles/map/boons/bounty_hunter_track_shield_mark.vpcf", PATTACH_OVERHEAD_FOLLOW)
DefineMark("modifier_neutral_boon_carrier_aegis",
    "particles/generic_gameplay/dropped_aegis.vpcf", PATTACH_ABSORIGIN_FOLLOW)
