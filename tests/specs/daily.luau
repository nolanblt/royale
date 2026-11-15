--!strict
--[[
	Les recompenses quotidiennes : avancer d'une case par jour, reculer d'une
	case par jour rate, repartir apres la derniere ; le contenu du cycle
	(choisi avec Josh le 14 novembre 2026).
]]

local Config = require("../../src/shared/Config")
local Daily = require("../../src/shared/Daily")
local Shop = require("../../src/shared/Shop")

local harness = require("../harness")

return function(t: harness.Harness)
	local D = Config.daily
	local length = #D.weeks * D.days

	t.section("Les regles")
	local step, state = Daily.claim({ step = 0 }, 100, length)
	t.equal("premiere connexion : la premiere case", step, 1)
	local again = Daily.claim(state, 100, length)
	t.equal("le meme jour : rien de plus", again, nil)
	step, state = Daily.claim(state, 101, length)
	t.equal("le lendemain : la case suivante", step, 2)
	step, state = Daily.claim(state, 102, length)
	t.equal("encore le lendemain : la troisieme", step, 3)
	-- Un jour rate : on recule d'une case (on refait la meme).
	step, state = Daily.claim(state, 104, length)
	t.equal("un jour rate : on recule d'une case", step, 3)
	-- Trois jours rates : trois cases de recul.
	step, state = Daily.claim(state, 108, length)
	t.equal("trois jours rates : trois cases de recul", step, 1)
	step = Daily.claim({ last = 100, step = 2 }, 200, length)
	t.equal("jamais avant la premiere case", step, 1)
	step = Daily.claim({ last = 100, step = length }, 101, length)
	t.equal("apres la derniere case, le cycle repart", step, 1)
	local w, d = Daily.weekDay(9, D.days)
	t.check("la case 9 est le jour 2 de la semaine 2", w == 2 and d == 2)

	t.section("Le contenu")
	local items = Config.cosmetics.items
	t.equal("4 semaines", #D.weeks, 4)
	local shape, rare = true, true
	for wi, week in D.weeks do
		if #week ~= D.days then
			shape = false
		end
		for di, reward in week do
			if di == 2 or di == 7 then
				local def = reward.item and items[reward.item]
				local want = if di == 2 then "epic" else "legendary"
				if def == nil or def.rarity ~= want or not def.daily then
					rare = false
					print(string.format("   semaine %d jour %d : objet attendu %s", wi, di, want))
				end
			elseif not (reward.credits or reward.fragments) then
				shape = false
			end
		end
	end
	t.check("7 jours par semaine, des credits ou des fragments hors J2 et J7", shape)
	t.check("J2 : un objet epique, J7 : un legendaire, propres aux recompenses", rare)
	local pool = Shop.drawPool(items)
	local leak = false
	for _, id in pool do
		if items[id].daily then
			leak = true
		end
	end
	t.check("jamais un objet quotidien au tirage ni en boutique", not leak)
	t.check(
		"un objet deja obtenu rend des credits",
		D.ownedCredits.epic > 0 and D.ownedCredits.legendary > D.ownedCredits.epic
	)
end
