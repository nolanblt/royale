--!strict
--[[
	Le salon avec les vrais reglages : les groupes (inviter, quitter, le chef
	qui part), le mode qui suit la taille du groupe, qui part au compte a
	rebours.
]]

local Config = require("../../src/shared/Config")
local Lobby = require("../../src/shared/Lobby")

local harness = require("../harness")

return function(t: harness.Harness)
	local LB = Config.lobby
	local sizes = Config.squads.sizes

	t.section("Les groupes")
	local s = Lobby.new()
	for _, id in { "josh", "ami", "autre", "x", "y" } do
		Lobby.add(s, id, "solo", LB.privacies[1])
	end
	t.check("chacun seul au depart", s.groupOf.josh == "josh" and s.groupOf.ami == "ami")
	t.check("ami accepte l'invitation de josh", Lobby.join(s, "josh", "ami", LB.maxGroup))
	t.check("ils sont ensemble, josh chef", s.groupOf.ami == "josh" and #s.groups.josh.members == 2)
	t.check("pas deux fois", not Lobby.join(s, "josh", "ami", LB.maxGroup))
	Lobby.join(s, "josh", "autre", LB.maxGroup)
	Lobby.join(s, "josh", "x", LB.maxGroup)
	t.check("4 au plus", not Lobby.join(s, "josh", "y", LB.maxGroup))
	Lobby.leave(s, "josh", true)
	t.check(
		"le chef part : le suivant devient chef",
		s.groupOf.ami == "ami" and #s.groups.ami.members == 3
	)
	t.check("et lui est seul de nouveau", s.groupOf.josh == "josh")

	t.section("Le mode")
	local PUBLIC = LB.privacies[1]
	Lobby.cycleMode(s, "ami", LB.modes)
	t.equal("un groupe de 3 peut jouer en duo", s.groups.ami.mode, "duo")
	Lobby.cycleMode(s, "ami", LB.modes)
	Lobby.cycleMode(s, "ami", LB.modes)
	t.equal("et en solo, chacun pour soi", s.groups.ami.mode, "solo")
	Lobby.cycleMode(s, "ami", LB.modes)
	Lobby.cycleMode(s, "ami", LB.modes)
	t.equal("puis escouade", s.groups.ami.mode, "squad")
	Lobby.setReady(s, "autre", true)
	t.check("seul le chef se dit pret", not s.groups.ami.ready)
	Lobby.setReady(s, "ami", true)
	t.check("le chef, oui", s.groups.ami.ready)
	t.equal("les groupes prets de l'escouade", #Lobby.readyGroups(s, "squad", PUBLIC), 1)
	t.equal("personne en solo", #Lobby.readyGroups(s, "solo", PUBLIC), 0)
	Lobby.join(s, "ami", "josh", LB.maxGroup)
	t.check("quelqu'un arrive : le groupe n'est plus pret", not s.groups.ami.ready)

	t.section("La partie privee")
	t.equal("un nouveau groupe est public", s.groups.y.privacy, PUBLIC)
	Lobby.cyclePrivacy(s, "y", LB.privacies)
	t.equal("puis prive avec bots", s.groups.y.privacy, "privateBots")
	Lobby.setReady(s, "y", true)
	t.equal("un groupe prive pret part seul", #Lobby.readyPrivate(s, PUBLIC), 1)
	t.equal("et jamais avec les publics", #Lobby.readyGroups(s, s.groups.y.mode, PUBLIC), 0)
	Lobby.cyclePrivacy(s, "y", LB.privacies)
	t.equal("puis prive sans bots", s.groups.y.privacy, "privateAlone")
	t.check("changer de partie annule le pret", not s.groups.y.ready)
	Lobby.cyclePrivacy(s, "y", LB.privacies)
	t.equal("et de nouveau public", s.groups.y.privacy, PUBLIC)

	t.section("Les reglages")
	for _, p in LB.privacies do
		t.check(
			p .. " a son nom et ses regles",
			LB.privacyNames[p] ~= nil and LB.privacyRules[p] ~= nil
		)
	end
	for _, p in LB.privacies do
		t.check(
			p .. " : seules les parties publiques comptent (Josh)",
			LB.privacyRules[p].ranked == (p == LB.privacies[1])
		)
	end
	t.check(
		"les modes du salon existent tous",
		sizes[LB.modes[1]] and sizes[LB.modes[2]] and sizes[LB.modes[3]] and true or false
	)
	t.check("un groupe tient dans l'escouade", LB.maxGroup == sizes.squad)
	t.check(
		"le compte a rebours laisse le temps de se joindre (10 s au moins)",
		LB.countdownSeconds >= 10
	)
end
