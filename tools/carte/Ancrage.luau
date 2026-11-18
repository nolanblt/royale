--!strict
--[[
	Ancrage — rien ne flotte (Josh, le 16 novembre 2026 : « des maisons qui
	flottent, des voitures qui flottent »).

	Passe apres les zones, et se mesure elle-meme :
	1. Chaque emplacement de cachette descend jusqu'a ce que la cachette
	   qu'il porte (chaque variante essayee) touche le sol par son point le
	   plus bas. Mesure : des roseaux a 1,5 stud au-dessus de l'eau, un abri
	   a 5 studs sur une pente.
	2. Sous chaque batiment pose sur une pente, un soubassement de pierre
	   comble le vide jusqu'au sol (avant : une ferme avec un coin a 12,5
	   studs en l'air). Le batiment ne bouge pas : ses portes et ses
	   cachettes restent ou elles sont.
	3. Dans le Quartier suspendu (qui flotte expres), ce qui est pose sur un
	   ilot (une voiture) descend jusqu'a l'ilot.
	Le rapport dit combien de chaque, et ce qui reste en l'air.
]]

return function(CONTRACT: any)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	-- L'ecart entre le pied du modele et ce qu'il y a dessous, aux points
	-- donnes (parts de la boite) : le plus petit et le plus grand.
	local function gaps(
		m: Model,
		ignore: { Instance },
		points: { { number } }
	): (number, number, number)
		local box, size = m:GetBoundingBox()
		local bottom = box.Position.Y - size.Y / 2
		local top = box.Position.Y + size.Y / 2
		params.FilterDescendantsInstances = ignore
		local low, high, deepest = math.huge, -math.huge, math.huge
		for _, o in points do
			local p = (box * CFrame.new(o[1] * size.X, 0, o[2] * size.Z)).Position
			local hit = workspace:Raycast(
				Vector3.new(p.X, top + 5, p.Z),
				Vector3.new(0, -(top - bottom) - 200, 0),
				params
			)
			if hit then
				local g = bottom - hit.Position.Y
				low = math.min(low, g)
				high = math.max(high, g)
				deepest = math.min(deepest, hit.Position.Y)
			end
		end
		return low, high, deepest
	end

	local CENTER_AND_CORNERS =
		{ { 0, 0 }, { 0.4, 0.4 }, { -0.4, 0.4 }, { 0.4, -0.4 }, { -0.4, -0.4 } }
	local EDGES = {
		{ 0.47, 0.47 },
		{ -0.47, 0.47 },
		{ 0.47, -0.47 },
		{ -0.47, -0.47 },
		{ 0, 0.47 },
		{ 0, -0.47 },
		{ 0.47, 0 },
		{ -0.47, 0 },
	}
	-- Les noms qui ne sont pas des batiments (on ne les soutient pas).
	local NOT_BUILDINGS = {
		Route = true,
		Pont = true,
		Passerelle = true,
		Poteaux = true,
		Fil = true,
		Ampoule = true,
		Papier = true,
		Lueur = true,
		Fumee = true,
		DebrisFlottant = true,
		Nacelle = true,
		Quai = true,
		Ponton = true,
		Grue = true,
		Cargo = true,
		Voie = true,
		Marquage = true,
		Arbre = true,
		-- Empiles et decales expres (le port echoue) : un pilier dessous
		-- jurerait.
		Conteneur = true,
	}
	-- Plus grand que ca au sol (studs carres), c'est un ensemble (une ferme
	-- et sa cour) : on soutient chacun de ses batiments, pas le tout (avant :
	-- une dalle de 74 x 129 sous toute la ferme).
	local MAX_FOOTPRINT = 2500
	-- Un batiment : assez grand pour qu'un vide dessous se voie.
	local MIN_BUILDING = 6
	-- Au-dela de cet ecart sous un bord, le vide se voit : soubassement.
	local SHOW_GAP = 1
	-- Le soubassement s'enfonce d'autant sous le sol le plus bas.
	local SINK = 1
	-- Un emplacement plus haut que ca au-dessus du sol descend.
	local ANCHOR_GAP = 0.3
	-- Le ciel (Ciel.luau) : l'Oeil et ses debris ne sont pas un sol.
	local SKY = "Ciel"

	return function(kit: any, prefabs: Folder): ({ string }, { string })
		local summaries: { string } = {}
		local problems: { string } = {}

		-- 1. Les emplacements de cachettes.
		local lowered = 0
		local scratch = Instance.new("Folder")
		scratch.Name = "AncrageEssai"
		scratch.Parent = workspace
		for _, anchor in kit.anchors:GetChildren() do
			if not anchor:IsA("BasePart") then
				continue
			end
			local prefab = anchor:GetAttribute("Prefab")
			local worst = -math.huge
			for _, variant in prefabs:GetChildren() do
				if
					not variant:IsA("Model")
					or string.gsub(variant.Name, "%d+$", "") ~= prefab
					or variant.PrimaryPart == nil
				then
					continue
				end
				local model = variant:Clone()
				local socle = model.PrimaryPart :: BasePart
				model:PivotTo(anchor.CFrame * socle.CFrame:ToObjectSpace(model:GetPivot()))
				model.Parent = scratch
				local ignore: { Instance } = { scratch, kit.anchors }
				local sky = kit.root:FindFirstChild(SKY)
				if sky then
					table.insert(ignore, sky)
				end
				local low = gaps(model, ignore, CENTER_AND_CORNERS)
				worst = math.max(worst, if low == math.huge then -math.huge else low)
				model:Destroy()
			end
			if worst > ANCHOR_GAP then
				anchor.CFrame -= Vector3.new(0, worst, 0)
				lowered += 1
			end
		end
		scratch:Destroy()
		table.insert(
			summaries,
			string.format("Ancrage : %d emplacement(s) descendu(s) jusqu'au sol", lowered)
		)

		-- 2. Les batiments sur une pente.
		local plinths = 0
		local zones = kit.root:FindFirstChild(CONTRACT.zones)
		if zones then
			for _, zone in zones:GetChildren() do
				if zone.Name == "QuartierSuspendu" or zone.Name == "Vegetation" then
					continue
				end
				local function consider(m: Instance)
					local base = string.gsub(m.Name, "%d+$", "")
					if not m:IsA("Model") or NOT_BUILDINGS[base] then
						return
					end
					local box, size = m:GetBoundingBox()
					if size.X * size.Z > MAX_FOOTPRINT then
						for _, child in m:GetChildren() do
							consider(child)
						end
						return
					end
					if size.X < MIN_BUILDING or size.Z < MIN_BUILDING or size.Y < MIN_BUILDING then
						return
					end
					local _, high, deepest = gaps(m, { m }, EDGES)
					if high == -math.huge or high <= SHOW_GAP then
						return
					end
					local bottom = box.Position.Y - size.Y / 2
					local depth = bottom - deepest + SINK
					local plinth = Instance.new("Part")
					plinth.Name = "SoubassementAncrage"
					plinth.Anchored = true
					plinth.Size = Vector3.new(size.X, depth, size.Z)
					plinth.CFrame = box * CFrame.new(0, -size.Y / 2 - depth / 2, 0)
					plinth.Material = Enum.Material.Cobblestone
					plinth.Color = Color3.fromRGB(92, 86, 80)
					plinth.Parent = m
					plinths += 1
				end
				for _, m in zone:GetChildren() do
					consider(m)
				end
			end
		end
		table.insert(
			summaries,
			string.format("Ancrage : %d soubassement(s) sous des batiments en pente", plinths)
		)

		-- 3. Ce qui est pose sur les ilots du Quartier suspendu.
		local settled = 0
		local suspended = zones and zones:FindFirstChild("QuartierSuspendu")
		if suspended then
			for _, m in suspended:GetDescendants() do
				if m:IsA("Model") and string.find(m.Name, "Voiture") then
					local low = gaps(m, { m }, CENTER_AND_CORNERS)
					if low ~= math.huge and low > ANCHOR_GAP and low < 20 then
						m:PivotTo(m:GetPivot() - Vector3.new(0, low, 0))
						settled += 1
					end
				end
			end
		end
		table.insert(
			summaries,
			string.format("Ancrage : %d objet(s) reposes sur les ilots suspendus", settled)
		)
		if lowered + plinths + settled == 0 then
			table.insert(summaries, "Ancrage : rien a corriger")
		end
		return summaries, problems
	end
end
