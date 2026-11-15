--!strict
--[[
	Daily — les recompenses quotidiennes, sans Roblox (choisi avec Josh le
	14 novembre 2026).

	Un cycle de `length` cases (4 semaines de 7 jours). Chaque jour de
	connexion fait avancer d'une case ; chaque jour rate fait reculer d'une
	case (jamais avant la premiere). Apres la derniere case, le cycle
	repart (les objets deja obtenus rendent des credits, cote serveur).

	Logique pure : aucun require, aucune API Roblox ; le jour (UTC) arrive en
	argument.
]]

local Daily = {}

export type State = { last: number?, step: number }

-- La case a recuperer aujourd'hui, ou nil si c'est deja fait. Rend aussi
-- l'etat a sauvegarder.
function Daily.claim(state: State, today: number, length: number): (number?, State)
	if state.last == today then
		return nil, state
	end
	local step: number
	if state.last == nil then
		step = 1
	else
		local missed = math.max(0, today - (state.last :: number) - 1)
		step = math.max(1, state.step + 1 - missed)
	end
	-- Apres la derniere case, le cycle repart.
	step = (step - 1) % length + 1
	return step, { last = today, step = step }
end

-- La semaine et le jour (1 a 7) d'une case.
function Daily.weekDay(step: number, days: number): (number, number)
	return (step - 1) // days + 1, (step - 1) % days + 1
end

return Daily
