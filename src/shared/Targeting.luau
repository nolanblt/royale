--!strict
--[[
	Targeting — qui chaque faisceau poursuit (CONCEPT.md, l'Oeil chasse en
	permanence).

	Logique pure. A chaque pas, on donne les faisceaux (position, cible,
	memoire restante) et les joueurs vus en ce moment (par n'importe quel
	faisceau). Regle :

	1. un faisceau garde sa cible tant qu'il la voit, ou tant que sa memoire
	   n'est pas epuisee apres l'avoir perdue ;
	2. sinon il prend le joueur vu le plus proche qu'aucun autre faisceau ne
	   poursuit ;
	3. sinon il n'a pas de cible (il erre, ou fait le menage).
]]

local Targeting = {}

export type Beam = { x: number, z: number, target: string?, memory: number }
export type Seen = { id: string, x: number, z: number }

-- Rend, pour chaque faisceau dans l'ordre, sa cible (ou nil) et sa memoire.
function Targeting.assign(
	beams: { Beam },
	seen: { Seen },
	memorySeconds: number,
	dt: number
): { Beam }
	local visible: { [string]: Seen } = {}
	for _, s in seen do
		visible[s.id] = s
	end
	local taken: { [string]: boolean } = {}
	local out: { Beam } = {}
	-- D'abord ceux qui gardent leur cible.
	for i, beam in beams do
		local target = beam.target
		if target and visible[target] then
			out[i] = { x = beam.x, z = beam.z, target = target, memory = memorySeconds }
			taken[target] = true
		elseif target and beam.memory - dt > 0 and not taken[target] then
			out[i] = { x = beam.x, z = beam.z, target = target, memory = beam.memory - dt }
			taken[target] = true
		end
	end
	-- Puis les libres prennent le joueur vu le plus proche.
	for i, beam in beams do
		if out[i] == nil then
			local best: Seen? = nil
			local bestD = math.huge
			for _, s in seen do
				if not taken[s.id] then
					local d = (s.x - beam.x) ^ 2 + (s.z - beam.z) ^ 2
					if d < bestD then
						best, bestD = s, d
					end
				end
			end
			if best then
				taken[best.id] = true
				out[i] = { x = beam.x, z = beam.z, target = best.id, memory = memorySeconds }
			else
				out[i] = { x = beam.x, z = beam.z, target = nil, memory = 0 }
			end
		end
	end
	return out
end

export type Candidate = { id: string, x: number, z: number, exposed: boolean }

-- Ou va un faisceau sans cible (Josh, le 16 novembre 2026 : « il ne me
-- cherchait jamais quand j'etais dehors ») : vers le plus proche des
-- participants a decouvert (dehors, pas sous un toit ni cache) qu'aucun
-- autre faisceau errant n'a deja pris ; s'il n'y en a pas, vers le plus
-- proche de tous. `taken` se remplit au fil des faisceaux.
-- Il ne voit toujours pas a travers les murs : il se dirige, il ne detecte
-- pas (la jauge ne monte que sous sa lumiere, ligne de vue comprise).
function Targeting.roamGoal(
	x: number,
	z: number,
	candidates: { Candidate },
	taken: { [string]: boolean }
): Candidate?
	local function nearest(onlyExposed: boolean, skipTaken: boolean): Candidate?
		local best: Candidate? = nil
		local bestD = math.huge
		for _, c in candidates do
			if (onlyExposed and not c.exposed) or (skipTaken and taken[c.id]) then
				continue
			end
			local d = (c.x - x) ^ 2 + (c.z - z) ^ 2
			if d < bestD then
				best, bestD = c, d
			end
		end
		return best
	end
	local goal = nearest(true, true) or nearest(true, false) or nearest(false, false)
	if goal then
		taken[goal.id] = true
	end
	return goal
end

-- Ou un faisceau vise : la cible, decalee de son erreur de visee (`ex`, `ez`
-- entre -1 et 1, tires par l'appelant). Avec l'erreur a 5, pile sur toi.
function Targeting.aimPoint(
	x: number,
	z: number,
	aimError: number,
	ex: number,
	ez: number
): (number, number)
	return x + ex * aimError, z + ez * aimError
end

-- Un pas du faisceau vers un point, a vitesse donnee, sans le depasser.
function Targeting.chaseStep(
	x: number,
	z: number,
	tx: number,
	tz: number,
	speed: number,
	dt: number
): (number, number)
	local dx, dz = tx - x, tz - z
	local distance = math.sqrt(dx * dx + dz * dz)
	local step = speed * dt
	if distance <= step or distance == 0 then
		return tx, tz
	end
	return x + dx / distance * step, z + dz / distance * step
end

return Targeting
