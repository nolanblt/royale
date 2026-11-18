--!strict
--[[
	La traduction (Lang, Strings ; choisie avec Josh le 15 novembre 2026) :
	le dictionnaire se compile, chaque {n} de l'anglais a son morceau, les
	textes tels que le jeu les compose se traduisent en entier, et chaque nom
	ou texte de Config montre aux joueurs a son anglais.
]]

local Config = require("../../src/shared/Config")
local Lang = require("../../src/shared/Lang")
local Strings = require("../../src/shared/Strings")

local harness = require("../harness")

return function(t: harness.Harness)
	t.section("Le dictionnaire")
	local c = Lang.compile(Strings.en)
	local badRefs = {}
	for fr, en in Strings.en do
		local _, n = string.gsub(fr, "%%[%d%.]*[sdf]", "")
		for ref in string.gmatch(en, "{(%d)}") do
			if tonumber(ref) :: number > n then
				table.insert(badRefs, fr)
			end
		end
	end
	t.check("chaque {n} de l'anglais a son morceau dans le francais", #badRefs == 0)
	for _, fr in badRefs do
		print("   {n} sans morceau : " .. fr)
	end

	t.section("Les textes tels que le jeu les compose")
	local function same(label: string, fr: string, en: string)
		local got = Lang.translate(c, fr)
		t.check(label, got == en)
		if got ~= en then
			print("   " .. fr .. " -> " .. tostring(got))
		end
	end
	same("un mot", "Prêt", "Ready")
	same("un compte", string.format("Survivants : %d", 12), "Survivors: 12")
	same(
		"un Regard et son titre, puis l'heure",
		string.format("Regard %d — %s", 2, Config.regards[2].title) .. "   1:23",
		"Gaze 2 — It sees farther   1:23"
	)
	same(
		"un defi (format de Config dans un message)",
		"Défi du jour réussi : " .. string.format(Config.challenges.list.play.text, 2),
		"Daily challenge complete: Play 2 match(es)"
	)
	same(
		"un message avec un nom de joueur et un objet",
		"Josh a pris la Relique : " .. Config.items.bat.name,
		"Josh took the Relic: Bat"
	)
	same("une rarete en capitales", Lang.upper(Config.rarities.legendary.name), "LEGENDARY")
	same("une liste de pouvoirs", "Ses pouvoirs : La rage, Le flair", "Its powers: Rage, The nose")
	same(
		"plusieurs lignes",
		"Choisis où l'Œil te crache\nglisse le doigt pour viser",
		"Choose where the Eye spits you out\ndrag your finger to aim"
	)
	same(
		"l'objet choisi, ce qu'il fait et son bouton",
		Config.items.smoke.name
			.. " — "
			.. Config.items.smoke.blurb
			.. " · R2 lancer · L2 viser",
		"Smoke Bomb — a cloud it can't see through · R2 throw · L2 aim"
	)
	same(
		"un nouveau pouvoir sur deux lignes",
		"L'ŒIL APPREND : La rage\nUne rafale sur deux, un faisceau de plus.",
		"THE EYE LEARNS: Rage\nEvery other burst, one more beam."
	)
	same(
		"le mode et la partie privee, en capitales",
		Lang.upper(Config.lobby.modeNames.solo .. " · " .. Config.lobby.privacyNames.privateBots),
		"SOLO · PRIVATE + BOTS"
	)
	same(
		"caché, avec le nom de la cachette",
		"Caché (Buisson) · X sortir · R2 jaillir",
		"Hidden (Bush) · X get out · R2 burst out"
	)
	same(
		"une ligne de la liste des joueurs",
		"[2] Josh « Survivant » — aspiré",
		"[2] Josh “Survivor” — taken"
	)
	same(
		"un nombre a deux chiffres",
		"Aujourd'hui — nouveaux objets dans 3 h 05",
		"Today — new items in 3 h 05"
	)
	t.check("un nom de joueur reste tel quel", Lang.translate(c, "Tobyzarbi") == nil)

	t.section("Chaque texte de Config a son anglais")
	local missing: { string } = {}
	local function need(s: string?)
		if typeof(s) == "string" and s ~= "" and Lang.translate(c, s) == nil then
			table.insert(missing, s)
		end
	end
	for _, r in Config.regards do
		need(r.title)
	end
	for _, p in Config.eyePowers.list do
		need(p.name)
		need(p.text)
	end
	for _, r in Config.rarities do
		need(r.name)
	end
	for _, def in Config.items do
		need(def.name)
		need(def.blurb)
	end
	for _, def in Config.cosmetics.items do
		need(def.name)
	end
	for _, name in Config.cosmetics.slotNames do
		need(name)
	end
	for _, name in Config.lobby.modeNames do
		need(name)
	end
	for _, name in Config.lobby.privacyNames do
		need(name)
	end
	for _, name in Config.map.zoneNames do
		need(name)
	end
	for _, kind in Config.repris.kinds do
		need(kind.name)
	end
	for base in Config.hiding.capacity do
		need(Config.hiding.displayNames[base] or base)
	end
	for _, name in Config.hiding.displayNames do
		need(name)
	end
	for _, text in Config.hiding.actionText do
		need(text)
	end
	need(Config.hiding.defaultAction)
	for _, ch in Config.challenges.list do
		need(string.format(ch.text, 3))
	end
	for _, name in Config.view.keyNames do
		need(name)
	end
	for _, kind in Config.signals.kinds do
		need(kind.text)
	end
	need(Config.squads.reviveText)
	need(Config.squads.giveText)
	t.check("aucun texte de Config sans anglais", #missing == 0)
	for _, s in missing do
		print("   sans anglais : " .. s)
	end
end
