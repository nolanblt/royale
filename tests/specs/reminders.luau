--!strict
--[[
	Les rappels par notification (Reminders, Config.notifications ; choisis
	avec Josh le 15 novembre 2026) : seuls les absents de la fenetre, une
	fois par jour.
]]

local Config = require("../../src/shared/Config")
local Reminders = require("../../src/shared/Reminders")

local harness = require("../harness")

return function(t: harness.Harness)
	local N = Config.notifications
	t.section("Qui recoit le rappel du jour")
	local now = 30000 * 24 * 60 + 12 * 60
	local hour = 60
	t.check("parti il y a une heure : pas encore", not Reminders.due(N, now - hour, nil, now))
	t.check(
		"parti hier, il y a assez longtemps : oui",
		Reminders.due(N, now - (N.remindAfterHours + 1) * hour, nil, now)
	)
	t.check(
		"deja prevenu aujourd'hui : non",
		not Reminders.due(N, now - (N.remindAfterHours + 1) * hour, Reminders.dayOf(now), now)
	)
	t.check(
		"parti depuis trop longtemps : on le laisse",
		not Reminders.due(N, now - (N.remindUntilHours + 1) * hour, nil, now)
	)
	t.check(
		"au plus trois rappels par absence (la fenetre fait moins de trois jours)",
		N.remindUntilHours - N.remindAfterHours < 72
	)
	t.check("un rappel attend au moins une nuit", N.remindAfterHours >= 12)
end
