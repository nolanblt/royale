--!strict
--[[
	Eclairage — des maisons habitees de lumiere (Josh, le 16 novembre 2026 :
	« il fait trop sombre dans les maisons… des lumieres ou des bougies, au
	moins dans certaines »).

	Sur les meubles a fouiller des maisons (Carte.Fouilles : cuisines,
	armoires), une maison sur deux environ recoit des bougies sur le plan
	de travail de sa cuisine, et parfois une lanterne sur son armoire. Rien
	ne bloque le regard de l'Oeil ni les joueurs (pas de collision, pas de
	rayon) : c'est de la lumiere, pas un abri.
	Le tirage est fixe (graine) : reconstruire donne les memes maisons
	eclairees.
]]

return function()
	local CHANCE_KITCHEN = 0.55
	local CHANCE_LANTERN = 0.35
	local SEED = 1611
	local WAX = Color3.fromRGB(236, 226, 200)
	local FLAME = Color3.fromRGB(255, 170, 70)
	local LIGHT = Color3.fromRGB(255, 176, 96)
	local IRON = Color3.fromRGB(46, 42, 40)
	local CANDLE_RANGE = 16
	local CANDLE_BRIGHTNESS = 1.4
	local LANTERN_RANGE = 22
	local LANTERN_BRIGHTNESS = 1.8

	local function part(
		parent: Instance,
		name: string,
		size: Vector3,
		cf: CFrame,
		color: Color3,
		material: Enum.Material
	): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material
		p.Parent = parent
		return p
	end

	local function light(on: BasePart, range: number, brightness: number)
		local l = Instance.new("PointLight")
		l.Color = LIGHT
		l.Range = range
		l.Brightness = brightness
		l.Shadows = true
		l.Parent = on
	end

	-- Trois bougies de tailles differentes, posees sur le dessus d'un meuble.
	local function candles(parent: Instance, top: CFrame, random: Random)
		local group = Instance.new("Model")
		group.Name = "Bougies"
		group.Parent = parent
		for i = 1, 3 do
			local height = random:NextNumber(0.6, 1.3)
			local at = top
				* CFrame.new(
					random:NextNumber(-1.2, 1.2),
					height / 2,
					random:NextNumber(-0.25, 0.25)
				)
			local wax = part(
				group,
				"Cire",
				Vector3.new(height, 0.34, 0.34),
				at * CFrame.Angles(0, 0, math.pi / 2),
				WAX,
				Enum.Material.SmoothPlastic
			)
			wax.Shape = Enum.PartType.Cylinder
			local flame = part(
				group,
				"Flamme",
				Vector3.new(0.16, 0.3, 0.16),
				at * CFrame.new(0, height / 2 + 0.16, 0),
				FLAME,
				Enum.Material.Neon
			)
			if i == 1 then
				light(flame, CANDLE_RANGE, CANDLE_BRIGHTNESS)
			end
		end
	end

	-- Une lanterne de fer, la flamme derriere des vitres.
	local function lantern(parent: Instance, top: CFrame)
		local group = Instance.new("Model")
		group.Name = "Lanterne"
		group.Parent = parent
		part(
			group,
			"Socle",
			Vector3.new(0.6, 0.1, 0.6),
			top * CFrame.new(0, 0.05, 0),
			IRON,
			Enum.Material.Metal
		)
		part(
			group,
			"Vitre",
			Vector3.new(0.5, 0.7, 0.5),
			top * CFrame.new(0, 0.45, 0),
			Color3.fromRGB(255, 220, 160),
			Enum.Material.Glass
		).Transparency =
			0.5
		local flame = part(
			group,
			"Flamme",
			Vector3.new(0.14, 0.3, 0.14),
			top * CFrame.new(0, 0.4, 0),
			FLAME,
			Enum.Material.Neon
		)
		part(
			group,
			"Toit",
			Vector3.new(0.66, 0.1, 0.66),
			top * CFrame.new(0, 0.85, 0),
			IRON,
			Enum.Material.Metal
		)
		part(
			group,
			"Anse",
			Vector3.new(0.06, 0.3, 0.06),
			top * CFrame.new(0, 1.05, 0),
			IRON,
			Enum.Material.Metal
		)
		light(flame, LANTERN_RANGE, LANTERN_BRIGHTNESS)
	end

	-- Le dessus d'un meuble, oriente comme lui.
	local function topOf(p: BasePart): CFrame
		return p.CFrame * CFrame.new(0, p.Size.Y / 2, 0)
	end

	return function(root: Instance): string
		local random = Random.new(SEED)
		local containers = root:FindFirstChild("Fouilles")
		local old = root:FindFirstChild("Lumieres")
		if old then
			old:Destroy()
		end
		local folder = Instance.new("Folder")
		folder.Name = "Lumieres"
		folder.Parent = root
		if containers == nil then
			return "Eclairage : pas de meubles a fouiller"
		end
		-- Les meubles de chaque maison (« Maison12_Cuisine » -> « Maison12 »).
		local houses: { [string]: { [string]: BasePart } } = {}
		local names: { string } = {}
		for _, p in containers:GetChildren() do
			local house, room = string.match(p.Name, "^(.+)_(%a+)$")
			if p:IsA("BasePart") and house and room then
				if houses[house] == nil then
					houses[house] = {}
					table.insert(names, house)
				end
				houses[house][room] = p
			end
		end
		-- Toujours le meme ordre : le tirage ne depend pas de l'ordre des enfants.
		table.sort(names)
		local lit, lanterns = 0, 0
		for _, house in names do
			local rooms = houses[house]
			if rooms.Cuisine and random:NextNumber() < CHANCE_KITCHEN then
				candles(folder, topOf(rooms.Cuisine), random)
				lit += 1
				if rooms.Armoire and random:NextNumber() < CHANCE_LANTERN then
					lantern(folder, topOf(rooms.Armoire))
					lanterns += 1
				end
			end
		end
		return string.format(
			"Eclairage : %d maison(s) sur %d eclairees a la bougie, %d lanterne(s)",
			lit,
			#names,
			lanterns
		)
	end
end
