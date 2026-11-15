--!strict
--[[
	Les boutons au doigt (Config.touch, TouchControls ; choisi avec Josh le
	15 novembre 2026) : autour du bouton de saut, aucun ne doit en toucher un
	autre, ni le saut, ni sortir de l'ecran d'un telephone ; et chaque bouton
	de l'arc remplace un vrai bouton de manette du jeu.
]]

local Config = require("../../src/shared/Config")

local harness = require("../harness")

return function(t: harness.Harness)
	local T = Config.touch
	t.section("L'arc autour du saut")
	-- Le calcul de TouchControls.place, en tailles du bouton de saut (centre
	-- du saut a l'origine, le haut de l'ecran vers -y).
	type Disc = { id: string, x: number, y: number, r: number }
	local discs: { Disc } = { { id = "saut", x = 0, y = 0, r = 0.5 } }
	for id, spot in T.layout do
		local a = math.rad(spot.angle)
		table.insert(discs, {
			id = id,
			x = math.cos(a) * spot.ring,
			y = -math.sin(a) * spot.ring,
			r = spot.size / 2,
		})
	end
	for i = 1, #discs do
		for j = i + 1, #discs do
			local d1, d2 = discs[i], discs[j]
			local gap = math.sqrt((d1.x - d2.x) ^ 2 + (d1.y - d2.y) ^ 2) - d1.r - d2.r
			t.check(
				string.format("%s et %s ne se touchent pas (ecart %.2f)", d1.id, d2.id, gap),
				gap > 0.05
			)
		end
	end
	-- Sur le plus petit telephone courant (667 x 375), avec le saut de Roblox
	-- (70 pixels, centre a 60 / 55 du coin) : tout reste dans l'ecran, et
	-- au-dessus du bas.
	local unit = T.fallbackJump
	local cx, cy = 667 - T.fallbackCenter[1], 375 - T.fallbackCenter[2]
	for _, d in discs do
		local x, y, r = cx + d.x * unit, cy + d.y * unit, d.r * unit
		t.check(
			d.id .. " tient dans un petit ecran",
			x - r >= 0 and x + r <= 667 and y - r >= 0 and y + r <= 375
		)
	end
	-- Un doigt, c'est ~44 pixels ; les fleches du sac, plus petites, en
	-- gardent 38 (sur le plus petit saut de Roblox).
	for id, spot in T.layout do
		t.check(id .. " se touche au doigt (38 pixels au moins)", spot.size * unit >= 38)
	end
	t.check("les petits boutons du haut font 44 pixels au moins", T.small >= 44)

	t.section("Chaque bouton remplace un bouton du jeu")
	local onFoot = Config.controls.contexts.onFoot
	for id in T.layout do
		t.check(id .. " est une action a pied", onFoot[id] ~= nil)
	end
end
