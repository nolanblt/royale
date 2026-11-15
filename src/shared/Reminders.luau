--!strict
--[[
	Les rappels par notification (choisis avec Josh le 15 novembre 2026) :
	qui prevenir, et quand. Roblox n'en livre qu'une par jour et par joueur,
	seulement a qui les a acceptees (13 ans et plus) ; ici, on decide qui le
	merite, pour ne jamais en envoyer sans raison.

	Logique pure : les reglages (Config.notifications) arrivent en argument.
	Les temps sont en minutes (un OrderedDataStore ne garde que des entiers).
]]

local Reminders = {}

export type Settings = {
	remindAfterHours: number,
	remindUntilHours: number,
}

-- Le jour (UTC) d'un instant en minutes : la recompense du jour change a
-- minuit UTC, le rappel suit le meme calendrier.
function Reminders.dayOf(minutes: number): number
	return minutes // (24 * 60)
end

-- La fenetre ou chercher les absents : vus il y a entre ces deux bornes
-- (minutes, la plus ancienne d'abord).
function Reminders.window(settings: Settings, now: number): (number, number)
	return now - settings.remindUntilHours * 60, now - settings.remindAfterHours * 60
end

-- Un absent recoit le rappel du jour s'il est dans la fenetre et qu'aucun
-- rappel ne lui est deja parti aujourd'hui (lastSent : un jour, ou nil).
function Reminders.due(
	settings: Settings,
	lastSeen: number,
	lastSent: number?,
	now: number
): boolean
	local oldest, newest = Reminders.window(settings, now)
	if lastSeen < oldest or lastSeen > newest then
		return false
	end
	return lastSent ~= Reminders.dayOf(now)
end

return Reminders
