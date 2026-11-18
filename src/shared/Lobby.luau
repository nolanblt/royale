--!strict
--[[
	Lobby — les groupes du salon : qui est avec qui, le mode choisi par le
	chef, qui est pret, et qui part quand le compte a rebours finit.

	Logique pure : aucun require, aucune API Roblox. Les joueurs sont des ids
	(texte). Chaque joueur est toujours dans un groupe (seul, il est son
	propre chef).
]]

local Lobby = {}

-- `privacy` : publique (on part avec les autres groupes prets du meme mode)
-- ou privee (le groupe part seul, avec ou sans bots) ; les noms sont ceux de
-- Config.lobby.privacies.
export type Group = {
	leader: string,
	members: { string },
	mode: string,
	ready: boolean,
	privacy: string,
}
export type State = { groups: { [string]: Group }, groupOf: { [string]: string } }

function Lobby.new(): State
	return { groups = {}, groupOf = {} }
end

-- Un joueur arrive : seul dans son groupe, au mode et a la confidentialite
-- par defaut.
function Lobby.add(s: State, id: string, mode: string, privacy: string)
	if s.groupOf[id] then
		return
	end
	s.groups[id] = { leader = id, members = { id }, mode = mode, ready = false, privacy = privacy }
	s.groupOf[id] = id
end

-- Il quitte son groupe (ou le serveur) : seul de nouveau, ou retire. Si
-- c'etait le chef, le suivant le devient.
function Lobby.leave(s: State, id: string, stay: boolean)
	local leader = s.groupOf[id]
	local g = leader and s.groups[leader]
	if g == nil then
		return
	end
	local i = table.find(g.members, id)
	if i then
		table.remove(g.members, i)
	end
	s.groupOf[id] = nil
	s.groups[leader] = nil
	if #g.members > 0 then
		local nextLeader = g.members[1]
		g.leader = nextLeader
		g.ready = false
		s.groups[nextLeader] = g
		for _, m in g.members do
			s.groupOf[m] = nextLeader
		end
	end
	if stay then
		Lobby.add(s, id, g.mode, g.privacy)
	end
end

-- `id` rejoint le groupe de `host` (il a accepte son invitation). Refuse si
-- le groupe est plein ou si c'est deja le meme.
function Lobby.join(s: State, host: string, id: string, maxGroup: number): boolean
	local leader = s.groupOf[host]
	local g = leader and s.groups[leader]
	if g == nil or s.groupOf[id] == leader or #g.members >= maxGroup then
		return false
	end
	Lobby.leave(s, id, false)
	-- Le depart a pu changer le chef du groupe hote (si `id` en etait).
	leader = s.groupOf[host]
	g = s.groups[leader]
	table.insert(g.members, id)
	s.groupOf[id] = leader
	g.ready = false
	return true
end

-- Le suivant dans une liste, en boucle.
-- Le mode choisi dans le menu (le chef seulement, un mode connu). Tout
-- groupe peut prendre tout mode (choisi avec Josh le 16 novembre 2026 :
-- jouer en solo entre amis sans quitter son groupe) : en partie, un groupe
-- plus grand que l'equipe est coupe en equipes successives
-- (Squads.assignGroups). Changer annule le « pret ».
function Lobby.setMode(s: State, id: string, modes: { string }, mode: string)
	local g = s.groups[id]
	if g == nil or table.find(modes, mode) == nil or g.mode == mode then
		return
	end
	g.mode = mode
	g.ready = false
end

-- Publique, privee avec bots, privee sans bots (le chef seulement).
function Lobby.setPrivacy(s: State, id: string, privacies: { string }, privacy: string)
	local g = s.groups[id]
	if g == nil or table.find(privacies, privacy) == nil or g.privacy == privacy then
		return
	end
	g.privacy = privacy
	g.ready = false
end

function Lobby.setReady(s: State, id: string, ready: boolean)
	local g = s.groups[s.groupOf[id] or ""]
	if g == nil or g.leader ~= id then
		return
	end
	g.ready = ready
end

-- Les groupes publics prets de ce mode, dans l'ordre de leurs chefs : ils
-- partent ensemble au compte a rebours.
function Lobby.readyGroups(s: State, mode: string, public: string): { Group }
	local out: { Group } = {}
	for _, g in s.groups do
		if g.ready and g.mode == mode and g.privacy == public then
			table.insert(out, g)
		end
	end
	table.sort(out, function(a, b)
		return a.leader < b.leader
	end)
	return out
end

-- Les groupes prives prets : chacun part seul.
function Lobby.readyPrivate(s: State, public: string): { Group }
	local out: { Group } = {}
	for _, g in s.groups do
		if g.ready and g.privacy ~= public then
			table.insert(out, g)
		end
	end
	table.sort(out, function(a, b)
		return a.leader < b.leader
	end)
	return out
end

return Lobby
