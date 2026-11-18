--!strict
--[[
	LobbyService — le salon (DECISIONS.md, choisi avec Josh le 12 novembre
	2026 : « les deux »).

	Une place en ruine flottant loin de la carte, construite au demarrage. On
	y attend, on forme son groupe (X maintenu sur quelqu'un l'invite ; il
	accepte avec X), le chef choisit le mode (Y) et se dit pret (R2). Un
	compte a rebours part : a la fin, tous les groupes prets de ce mode
	partent ensemble. `onLaunch` decide ou ils jouent (MatchService : sur
	place dans Studio, sur un serveur reserve dans le jeu publie).

	Les invitations et « rejoindre » de Roblox amenent les amis sur ce
	serveur ; croix haut ouvre la fenetre d'invitation de Roblox (client).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Royale = ReplicatedStorage:WaitForChild("Royale")
local Config = require(Royale:WaitForChild("Config"))
local Lobby = require(Royale:WaitForChild("Lobby"))

local Avatar = require(script.Parent.Avatar)
local RemoteGuard = require(script.Parent.RemoteGuard)
local World = require(script.Parent.World)

local LobbyService = {}

local LB = Config.lobby
local PUBLIC = LB.privacies[1]
local ORIGIN = Vector3.new(LB.origin[1], LB.origin[2], LB.origin[3])

local state = Lobby.new()
local byId: { [string]: Player } = {}
-- Ceux qui jouent une partie sur ce serveur : hors du salon jusqu'a la fin.
local away: { [Player]: boolean } = {}
-- L'invitation recue par chacun : qui, et quand.
local invites: { [Player]: { from: Player, at: number } } = {}
local countdown: { mode: string, ends: number }? = nil
-- Le depart de chaque groupe prive pret (os.clock), par chef.
local privateEnds: { [string]: number } = {}
local launching = false
type Launcher = (players: { Player }, mode: string, groups: { { Player } }, privacy: string) -> ()
local onLaunch: Launcher? = nil
local folder: Folder? = nil
local random = Random.new()

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function idOf(player: Player): string
	return tostring(player.UserId)
end

local function part(
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = folder
	return p
end

-- L'AUTEL DE L'OEIL, au centre de la place (choisi avec Josh le 15 novembre
-- 2026 : le brasero et son disque rouge faisaient pauvre). Une estrade a
-- deux marches, un oeil grave au sol (iris en anneau de braise, pupille en
-- fente), des fissures qui courent sur les marches, une vasque de pierre en
-- flammes sur son pilier, et quatre pierres levees marquees de runes.
local function altar()
	local A = LB.altar
	local stone, dark = rgb(LB.colors.stone), rgb(LB.colors.dark)
	local ember = rgb(A.ember)
	local flat = CFrame.Angles(0, 0, math.pi / 2)
	local function disc(
		name: string,
		diameter: number,
		height: number,
		y: number,
		color: Color3,
		material: Enum.Material
	): Part
		local p = part(
			name,
			Vector3.new(height, diameter, diameter),
			CFrame.new(ORIGIN + Vector3.new(0, y + height / 2, 0)) * flat,
			color,
			material
		)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	-- L'estrade.
	-- La marche du bas, en pierre claire : sombre, elle faisait une galette
	-- noire sans relief (vu en image).
	disc("Estrade", A.steps[1], A.stepHeight, 0, stone, Enum.Material.Slate)
	disc("Estrade", A.steps[2], A.stepHeight, A.stepHeight, stone, Enum.Material.Limestone)
	local top = A.stepHeight * 2
	-- L'oeil grave : une pierre sombre, l'iris en anneau de braise, la pupille.
	disc("OeilGrave", A.eye, 0.08, top, Color3.fromRGB(28, 22, 22), Enum.Material.Basalt).CanCollide =
		false
	local n = 28
	for i = 1, n do
		local a = i / n * math.pi * 2
		local seg = part(
			"Iris",
			Vector3.new(A.iris * math.pi / n * 1.1, 0.1, 0.35),
			CFrame.new(
				ORIGIN + Vector3.new(math.cos(a) * A.iris / 2, top + 0.1, math.sin(a) * A.iris / 2)
			) * CFrame.Angles(0, -a + math.pi / 2, 0),
			ember,
			Enum.Material.Neon
		)
		seg.CanCollide = false
	end
	local pupil = part(
		"Pupille",
		Vector3.new(0.9, 0.12, A.iris * 0.55),
		CFrame.new(ORIGIN + Vector3.new(0, top + 0.1, 0)),
		Color3.fromRGB(8, 4, 6),
		Enum.Material.SmoothPlastic
	)
	pupil.CanCollide = false
	-- Les fissures de braise, de l'oeil jusqu'au bord de l'estrade.
	for i = 1, A.cracks do
		local a = i / A.cracks * math.pi * 2 + random:NextNumber(-0.2, 0.2)
		local from = A.iris / 2 + 0.4
		local at = from
		local heading = a
		for _ = 1, 3 do
			heading += random:NextNumber(-0.35, 0.35)
			local step = random:NextNumber(1.2, 2.2)
			local p0 = Vector3.new(math.cos(a) * at, 0, math.sin(a) * at)
			local p1 = p0 + Vector3.new(math.cos(heading), 0, math.sin(heading)) * step
			if p1.Magnitude > A.steps[2] / 2 - 0.3 then
				break
			end
			local mid = (p0 + p1) / 2
			local crack = part(
				"Fissure",
				Vector3.new(0.12, 0.06, step),
				CFrame.lookAt(
					ORIGIN + mid + Vector3.new(0, top + 0.04, 0),
					ORIGIN + p1 + Vector3.new(0, top + 0.04, 0)
				),
				ember,
				Enum.Material.Neon
			)
			crack.CanCollide = false
			at = p1.Magnitude
			a = math.atan2(p1.Z, p1.X)
		end
	end
	-- Le pilier et sa vasque.
	disc("Pilier", A.pillar[1], A.pillar[2], top, stone, Enum.Material.Limestone)
	disc("Pilier", A.pillar[1] + 0.6, 0.4, top, dark, Enum.Material.Slate)
	local bowlY = top + A.pillar[2]
	disc("Vasque", A.bowl[1] * 0.6, A.bowl[2] * 0.5, bowlY, dark, Enum.Material.Slate)
	local bowl = disc(
		"Vasque",
		A.bowl[1],
		A.bowl[2] * 0.5,
		bowlY + A.bowl[2] * 0.5,
		dark,
		Enum.Material.Slate
	)
	disc("Bord", A.bowl[1] + 0.3, 0.2, bowlY + A.bowl[2], ember, Enum.Material.Neon).CanCollide =
		false
	local coals = disc(
		"Braises",
		A.bowl[1] - 0.6,
		0.2,
		bowlY + A.bowl[2] - 0.15,
		Color3.fromRGB(255, 120, 40),
		Enum.Material.Neon
	)
	coals.CanCollide = false
	local fire = Instance.new("Fire")
	fire.Size = A.fire
	fire.Heat = A.heat
	fire.Color = Color3.fromRGB(255, 140, 50)
	fire.SecondaryColor = Color3.fromRGB(200, 40, 15)
	fire.Parent = coals
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = Config.cosmetics.textures.spark
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 190, 90), Color3.fromRGB(255, 70, 20))
	sparks.Size = NumberSequence.new(0.4, 0)
	sparks.LightEmission = 1
	sparks.Rate = A.sparks
	sparks.Lifetime = NumberRange.new(1.2, 2.4)
	sparks.Speed = NumberRange.new(3, 7)
	sparks.SpreadAngle = Vector2.new(25, 25)
	sparks.Acceleration = Vector3.new(0, 2, 0)
	sparks.Parent = coals
	local glow = Instance.new("PointLight")
	glow.Color = rgb(LB.colors.lantern)
	glow.Range = A.lightRange
	glow.Brightness = A.lightBrightness
	glow.Parent = bowl
	-- Les obelisques, aux quatre coins de l'estrade (choisi avec Josh le 15
	-- novembre 2026 : les pierres levees faisaient des piquets) : un socle,
	-- un fut qui s'affine en blocs joints, un chapeau, un oeil de braise qui
	-- brule au sommet, et une rune de braise sur la face tournee vers l'autel.
	local O = A.obelisk
	for i = 1, 4 do
		local a = (i - 0.5) / 4 * math.pi * 2
		local at = ORIGIN
			+ Vector3.new(
				math.cos(a) * A.steps[1] / 2 * O.ring,
				A.stepHeight,
				math.sin(a) * A.steps[1] / 2 * O.ring
			)
		local facing = CFrame.lookAt(at, Vector3.new(ORIGIN.X, at.Y, ORIGIN.Z))
		part(
			"Obelisque",
			Vector3.new(O.base[1], O.base[2], O.base[1]),
			facing * CFrame.new(0, O.base[2] / 2, 0),
			dark,
			Enum.Material.Slate
		)
		part(
			"Obelisque",
			Vector3.new(O.base[1] - 0.5, 0.25, O.base[1] - 0.5),
			facing * CFrame.new(0, O.base[2] + 0.125, 0),
			stone,
			Enum.Material.Slate
		)
		local column = facing
			* CFrame.new(0, O.base[2] + 0.25, 0)
			* CFrame.Angles(
				random:NextNumber(-O.lean, O.lean),
				0,
				random:NextNumber(-O.lean, O.lean)
			)
		local seg = O.height / O.segments
		local function width(k: number): (number, number)
			local shrink = 1 - (1 - O.taper) * k / math.max(1, O.segments - 1)
			return O.shaft[1] * shrink, O.shaft[2] * shrink
		end
		for k = 0, O.segments - 1 do
			local w, d = width(k)
			part(
				"Obelisque",
				Vector3.new(w, seg - 0.08, d),
				column * CFrame.new(0, seg * k + seg / 2, 0),
				stone,
				Enum.Material.Slate
			)
			if k > 0 then
				part(
					"Joint",
					Vector3.new(w + 0.14, 0.14, d + 0.14),
					column * CFrame.new(0, seg * k, 0),
					dark,
					Enum.Material.Slate
				)
			end
		end
		local topW, topD = width(O.segments - 1)
		part(
			"Chapeau",
			Vector3.new(topW + 0.5, 0.3, topD + 0.5),
			column * CFrame.new(0, O.height + 0.15, 0),
			dark,
			Enum.Material.Slate
		)
		local orb = part(
			"OeilBraise",
			Vector3.one * O.orb,
			column * CFrame.new(0, O.height + 0.3 + O.orb / 2, 0),
			ember,
			Enum.Material.Neon
		)
		orb.Shape = Enum.PartType.Ball
		orb.CanCollide = false
		local flame = Instance.new("Fire")
		flame.Size = O.flame
		flame.Heat = O.flame
		flame.Color = Color3.fromRGB(255, 140, 50)
		flame.SecondaryColor = Color3.fromRGB(200, 40, 15)
		flame.Parent = orb
		local light = Instance.new("PointLight")
		light.Color = ember
		light.Range = O.lightRange
		light.Brightness = O.lightBrightness
		light.Parent = orb
		-- La rune, sur le bloc du milieu : un trait, deux branches, un losange.
		local mid = math.floor(O.segments / 2)
		local _, midD = width(mid)
		local face = column * CFrame.new(0, seg * mid + seg / 2, -midD / 2 - 0.02)
		for _, stroke in
			{
				{ CFrame.new(0, 0, 0), Vector3.new(0.1, seg * 0.7, 0.04) },
				{
					CFrame.new(0.17, seg * 0.2, 0) * CFrame.Angles(0, 0, -0.6),
					Vector3.new(0.1, 0.45, 0.04),
				},
				{
					CFrame.new(-0.17, seg * 0.2, 0) * CFrame.Angles(0, 0, 0.6),
					Vector3.new(0.1, 0.45, 0.04),
				},
				{
					CFrame.new(0, -seg * 0.3, 0) * CFrame.Angles(0, 0, math.pi / 4),
					Vector3.new(0.22, 0.22, 0.04),
				},
			}
		do
			part("Rune", stroke[2], face * stroke[1], ember, Enum.Material.Neon).CanCollide = false
		end
		-- Quelques pierres tombees au pied.
		for _ = 1, 3 do
			local r = random:NextNumber(0.3, 0.6)
			local spot = random:NextNumber(0, math.pi * 2)
			part(
				"Eboulis",
				Vector3.new(r, r * 0.7, r),
				facing
					* CFrame.new(
						math.cos(spot) * O.base[1] * 0.75,
						r * 0.35,
						math.sin(spot) * O.base[1] * 0.75
					)
					* CFrame.Angles(random:NextNumber(0, 1), random:NextNumber(0, 3), 0),
				stone,
				Enum.Material.Slate
			).CanCollide =
				false
		end
	end
end

-- La place : un disque de pavés uses, un muret effondre tout autour (et un
-- mur invisible pour ne pas tomber), des lanternes, un brasero au centre.
local function build()
	local old = workspace:FindFirstChild(LB.folder)
	if old then
		old:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = LB.folder
	f.Parent = workspace
	World.ignore(f)
	folder = f
	local stone, dark, lantern = rgb(LB.colors.stone), rgb(LB.colors.dark), rgb(LB.colors.lantern)
	local flat = CFrame.Angles(0, 0, math.pi / 2)
	local r = LB.radius
	local floor = part(
		"Sol",
		Vector3.new(4, r * 2, r * 2),
		CFrame.new(ORIGIN - Vector3.new(0, 2, 0)) * flat,
		stone,
		Enum.Material.Cobblestone
	)
	floor.Shape = Enum.PartType.Cylinder
	local under = part(
		"Dessous",
		Vector3.new(14, r * 2 - 6, r * 2 - 6),
		CFrame.new(ORIGIN - Vector3.new(0, 11, 0)) * flat,
		dark,
		Enum.Material.Rock
	)
	under.Shape = Enum.PartType.Cylinder
	local segments = 36
	for i = 1, segments do
		local a = (i - 0.5) / segments * math.pi * 2
		local at = ORIGIN + Vector3.new(math.cos(a) * (r - 1), 0, math.sin(a) * (r - 1))
		local facing = CFrame.lookAt(at, ORIGIN)
		local h = random:NextNumber(1.5, 6)
		local width = 2 * math.pi * r / segments + 0.4
		part(
			"Muret",
			Vector3.new(width, h, 1.6),
			facing + Vector3.new(0, h / 2, 0),
			dark,
			Enum.Material.Slate
		)
		local barrier = part(
			"MurInvisible",
			Vector3.new(width, 14, 1),
			facing + Vector3.new(0, 7, 0),
			dark,
			Enum.Material.SmoothPlastic
		)
		barrier.Transparency = 1
	end
	-- Les lampadaires, decales d'un demi-cran : sur les angles ronds, l'un se
	-- plantait devant le panneau « Comment jouer » (vu en image).
	for i = 1, LB.lanterns do
		local a = (i - 0.5) / LB.lanterns * math.pi * 2
		local at = ORIGIN + Vector3.new(math.cos(a) * (r - 8), 0, math.sin(a) * (r - 8))
		part(
			"Poteau",
			Vector3.new(0.6, 9, 0.6),
			CFrame.new(at + Vector3.new(0, 4.5, 0)),
			dark,
			Enum.Material.Metal
		)
		local lamp = part(
			"Lanterne",
			Vector3.new(1.4, 1.6, 1.4),
			CFrame.new(at + Vector3.new(0, 9.5, 0)),
			lantern,
			Enum.Material.Neon
		)
		lamp.CanCollide = false
		local light = Instance.new("PointLight")
		light.Color = lantern
		light.Range = 26
		light.Brightness = 1.6
		light.Parent = lamp
	end
	altar()
	-- Des colonnes brisees en cercle, de hauteurs differentes (la silhouette
	-- d'une ruine, pas un disque nu). Les deux panneaux sont sur l'axe Z (90 et
	-- 270 degres) : avec un decalage d'un demi-cran, une colonne se dressait
	-- pile devant chacun (vu en image le 14 novembre 2026).
	local T = LB.tutorial
	local arcFrom = T.panelArcStart - T.panelArcStep
	local arcTo = T.panelArcStart + #T.panels * T.panelArcStep
	for i = 1, LB.columns do
		local degrees = i / LB.columns * 360
		-- Pas de colonne devant les panneaux « Comment jouer », ni dans
		-- l'echoppe de la boutique (une colonne la traversait, vu en image).
		if degrees > arcFrom and degrees < arcTo then
			continue
		end
		if math.abs(degrees - LB.shopStall.angle) < LB.shopStall.clearance then
			continue
		end
		local a = math.rad(degrees)
		local at = ORIGIN + Vector3.new(math.cos(a) * (r - 18), 0, math.sin(a) * (r - 18))
		-- Une colonne antique (choisi avec Josh : « plus belles ») : un socle
		-- a deux marches, un tore, un fut cannele ; entiere, un chapiteau ;
		-- brisee, une cassure de biais et son tambour tombe a cote. Du lierre
		-- grimpe sur certaines.
		local C = LB.columnStyle
		local whole = random:NextNumber() < C.wholeChance
		local h = if whole
			then C.wholeHeight
			else random:NextNumber(C.brokenHeight[1], C.brokenHeight[2])
		local yaw = CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
		local base = CFrame.new(at) * yaw
		part(
			"Socle",
			Vector3.new(5.2, 0.8, 5.2),
			base * CFrame.new(0, 0.4, 0),
			dark,
			Enum.Material.Slate
		)
		part(
			"Socle",
			Vector3.new(4.4, 0.6, 4.4),
			base * CFrame.new(0, 1.1, 0),
			stone,
			Enum.Material.Limestone
		)
		local foot = 1.4
		local torus = part(
			"Tore",
			Vector3.new(0.6, 4, 4),
			base * CFrame.new(0, foot + 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2),
			stone,
			Enum.Material.Limestone
		)
		torus.Shape = Enum.PartType.Cylinder
		local shaftFrom = foot + 0.6
		local column = part(
			"Colonne",
			Vector3.new(h, 3.2, 3.2),
			base * CFrame.new(0, shaftFrom + h / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
			stone,
			Enum.Material.Limestone
		)
		column.Shape = Enum.PartType.Cylinder
		-- Les cannelures : des filets sombres tout autour du fut.
		for k = 1, C.flutes do
			local around = k / C.flutes * math.pi * 2
			local flute = part(
				"Cannelure",
				Vector3.new(0.22, h - 0.4, 0.22),
				base * CFrame.Angles(0, around, 0) * CFrame.new(0, shaftFrom + h / 2, 1.55),
				rgb(C.fluteColor),
				Enum.Material.Limestone
			)
			flute.CanCollide = false
			flute.CanQuery = false
		end
		local top = shaftFrom + h
		if whole then
			local neck = part(
				"Chapiteau",
				Vector3.new(0.6, 4, 4),
				base * CFrame.new(0, top + 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2),
				stone,
				Enum.Material.Limestone
			)
			neck.Shape = Enum.PartType.Cylinder
			part(
				"Chapiteau",
				Vector3.new(4.8, 1, 4.8),
				base * CFrame.new(0, top + 1.1, 0),
				stone,
				Enum.Material.Limestone
			)
		else
			-- La cassure : deux eclats de biais au sommet.
			for k = 0, 1 do
				local shard = part(
					"Eclat",
					Vector3.new(3.2, random:NextNumber(0.8, 1.6), 1.6),
					base
						* CFrame.new(0, top + 0.3, (k - 0.5) * 1.6)
						* CFrame.Angles(
							random:NextNumber(-0.25, 0.25),
							0,
							random:NextNumber(-0.4, 0.4)
						),
					stone,
					Enum.Material.Limestone
				)
				shard.CanCollide = false
			end
			-- Le tambour tombe, a cote.
			local piece = part(
				"Debris",
				Vector3.new(random:NextNumber(3, 5), 3.2, 3.2),
				CFrame.new(
					at + Vector3.new(random:NextNumber(-5, 5), 1.6, random:NextNumber(-5, 5))
				) * CFrame.Angles(0, random:NextNumber(0, 6.3), math.pi / 2),
				stone,
				Enum.Material.Limestone
			)
			piece.Shape = Enum.PartType.Cylinder
			piece.CanCollide = false
		end
		if random:NextNumber() < C.ivyChance then
			-- Le lierre : des feuilles plaquees sur une face, du pied vers le haut.
			local side = random:NextNumber(0, math.pi * 2)
			for k = 1, C.ivyLeaves do
				local up = shaftFrom + (k / C.ivyLeaves) * h * random:NextNumber(0.5, 0.95)
				local leaf = part(
					"Lierre",
					Vector3.new(random:NextNumber(0.5, 0.9), random:NextNumber(0.4, 0.8), 0.2),
					base
						* CFrame.Angles(0, side + random:NextNumber(-0.7, 0.7), 0)
						* CFrame.new(0, up, 1.65)
						* CFrame.Angles(0, 0, random:NextNumber(0, math.pi)),
					rgb(C.ivyColor),
					Enum.Material.LeafyGrass
				)
				leaf.CanCollide = false
				leaf.CanQuery = false
			end
		end
	end
	for _ = 1, 24 do
		local a = random:NextNumber(0, math.pi * 2)
		local d = random:NextNumber(LB.altar.steps[1] / 2 + 1, r - 6)
		local s = random:NextNumber(0.8, 2.4)
		local rubble = part(
			"Gravat",
			Vector3.new(s, s * 0.6, s * 1.2),
			-- A moitie enfonce : pose dessus, on aurait dit des caisses (vu a
			-- l'image du salon).
			CFrame.new(ORIGIN + Vector3.new(math.cos(a) * d, s * 0.05, math.sin(a) * d))
				* CFrame.Angles(
					random:NextNumber(-0.3, 0.3),
					random:NextNumber(0, 6.3),
					random:NextNumber(-0.3, 0.3)
				),
			dark,
			Enum.Material.Rock
		)
		rubble.CanCollide = false
	end
end

-- Le petit tutoriel (CONCEPT.md : les cachettes ne s'affichent pas, « un
-- petit tutoriel les presente au debut ») : un exemplaire de chaque
-- cachette sur un arc du salon, avec son nom et ses places, et les panneaux
-- illustres « Comment jouer » en face.
local function tutorial()
	local library = World.prefabs
	local T = LB.tutorial
	local shown = 0
	if library then
		local seen: { [string]: boolean } = {}
		local models: { Model } = {}
		for _, m in library:GetChildren() do
			local kind = string.gsub(m.Name, "%d+$", "")
			if m:IsA("Model") and not seen[kind] and m.PrimaryPart then
				seen[kind] = true
				table.insert(models, m)
			end
		end
		table.sort(models, function(a, b)
			return a.Name < b.Name
		end)
		local degrees = T.arcStart - T.arcStep
		for i, source in models do
			if i > T.maxSpots then
				break
			end
			-- Un arc au nord du salon, face au centre, avec un trou devant le
			-- classement.
			degrees += T.arcStep
			if math.abs(degrees - Config.leaderboard.angle) < T.boardClearance then
				degrees += T.arcStep
			end
			local a = math.rad(degrees)
			local at = ORIGIN + Vector3.new(math.cos(a) * T.radius, 0, math.sin(a) * T.radius)
			local model = source:Clone()
			local socle = model.PrimaryPart :: BasePart
			local facing = CFrame.lookAt(at, Vector3.new(ORIGIN.X, at.Y, ORIGIN.Z))
			model:PivotTo(facing * socle.CFrame:ToObjectSpace(model:GetPivot()))
			-- Une vitrine : rien n'y entre, mais elle est aussi solide que la
			-- vraie (traverser une voiture surprenait, vu par Josh) ; ce qui
			-- ne bloque pas en partie (feuillage) ne bloque pas ici non plus.
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanQuery = false
					-- Une zone invisible du modele (entree, volume) ferait un mur
					-- qu'on ne voit pas.
					if d.Transparency >= 1 then
						d.CanCollide = false
					end
				elseif d:IsA("ProximityPrompt") or d:IsA("Script") then
					d:Destroy()
				end
			end
			model.Parent = folder
			local kind = string.gsub(source.Name, "%d+$", "")
			local places = Config.hiding.capacity[kind] or Config.hiding.defaultCapacity
			local tag = Instance.new("BillboardGui")
			-- En studs : l'etiquette rapetisse avec la distance (en pixels,
			-- elles se chevauchaient de loin, vu en image).
			tag.Size = UDim2.fromScale(T.tagWidth, T.tagHeight)
			-- Au-dessus du haut de la cachette, mesure sur le modele pose.
			local box, extent = model:GetBoundingBox()
			local top = box.Position.Y + extent.Y / 2
			tag.StudsOffsetWorldSpace =
				Vector3.new(0, top - socle.Position.Y + T.tagGap + T.tagHeight / 2, 0)
			tag.AlwaysOnTop = true
			tag.LightInfluence = 0
			tag.MaxDistance = T.tagDistance
			tag.Adornee = socle
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Font = (Enum.Font :: any)[Config.view.bodyFont]
			label.TextScaled = true
			label.TextColor3 = rgb(LB.colors.lantern)
			label.TextStrokeTransparency = 0.3
			label.Text = string.format(
				"%s\n%s",
				Config.hiding.displayNames[kind] or kind,
				if places > 1 then places .. " places" else "1 place"
			)
			label.Parent = tag
			tag.Parent = model
			shown += 1
		end
	end
	-- Les panneaux illustres, sur l'arc d'en face (LobbyView les dessine :
	-- les icones de manette ne se lisent que chez le client).
	local w, h = T.panelWidth, T.panelHeight
	for i in T.panels do
		local a = math.rad(T.panelArcStart + (i - 1) * T.panelArcStep)
		local foot = ORIGIN
			+ Vector3.new(math.cos(a) * T.panelRadius, 0, math.sin(a) * T.panelRadius)
		local facing = CFrame.lookAt(foot, Vector3.new(ORIGIN.X, foot.Y, ORIGIN.Z))
		local board = part(
			"Panneau",
			Vector3.new(w, h, 0.6),
			facing + Vector3.new(0, T.panelLift + h / 2, 0),
			rgb(LB.colors.dark),
			Enum.Material.Wood
		)
		board:SetAttribute("Panneau", i)
		for side = -1, 1, 2 do
			part(
				"Pied",
				Vector3.new(0.5, T.panelLift + h, 0.5),
				facing * CFrame.new(side * (w / 2 - 0.6), (T.panelLift + h) / 2, 0.5),
				rgb(LB.colors.dark),
				Enum.Material.Wood
			)
		end
	end
	return shown
end

-- L'echoppe de la boutique : comptoir, auvent, enseigne, lanterne, et le
-- socle de la vitrine (LobbyScene y montre l'objet choisi, chez chacun).
-- X devant le comptoir ouvre la boutique (ShopView ecoute l'invite).
local function shopStall()
	local S = LB.shopStall
	local a = math.rad(S.angle)
	local at = ORIGIN + Vector3.new(math.cos(a) * S.radius, 0, math.sin(a) * S.radius)
	local facing = CFrame.lookAt(at, Vector3.new(ORIGIN.X, at.Y, ORIGIN.Z))
	local wood = Color3.fromRGB(96, 66, 42)
	local dark = rgb(LB.colors.dark)
	local c = S.counter
	local counter = part(
		"Comptoir",
		Vector3.new(c[1], c[2], c[3]),
		facing * CFrame.new(0, c[2] / 2, 0),
		wood,
		Enum.Material.Wood
	)
	part(
		"Plateau",
		Vector3.new(c[1] + 0.6, 0.3, c[3] + 0.6),
		facing * CFrame.new(0, c[2] + 0.15, 0),
		dark,
		Enum.Material.Slate
	)
	-- Les poteaux et l'auvent rayé, penche vers la place.
	for side = -1, 1, 2 do
		part(
			"Poteau",
			Vector3.new(0.5, S.awningHeight, 0.5),
			facing * CFrame.new(side * (c[1] / 2 + 0.2), S.awningHeight / 2, c[3] / 2 + 0.5),
			wood,
			Enum.Material.Wood
		)
	end
	local stripes = 6
	for i = 1, stripes do
		local stripe = part(
			"Auvent",
			Vector3.new((c[1] + 2) / stripes, 0.2, c[3] + 3.4),
			facing
				* CFrame.new(
					-(c[1] + 2) / 2 + (i - 0.5) * (c[1] + 2) / stripes,
					S.awningHeight,
					-0.2
				)
				* CFrame.Angles(math.rad(-14), 0, 0),
			if i % 2 == 0 then Color3.fromRGB(230, 215, 190) else rgb(S.awningColor),
			Enum.Material.Fabric
		)
		stripe.CanCollide = false
	end
	-- L'enseigne : le mot, en machine a ecrire, couleur lanterne.
	local sign = part(
		"Enseigne",
		Vector3.new(c[1] * 0.8, 1.8, 0.3),
		facing * CFrame.new(0, S.awningHeight + 1.4, -1.2),
		dark,
		Enum.Material.Wood
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.Parent = sign
	local word = Instance.new("TextLabel")
	word.BackgroundTransparency = 1
	word.Size = UDim2.fromScale(1, 1)
	word.Font = (Enum.Font :: any)[Config.view.font]
	word.TextScaled = true
	word.TextColor3 = rgb(LB.colors.lantern)
	word.Text = "BOUTIQUE"
	word.Parent = gui
	local lamp = part(
		"Lanterne",
		Vector3.new(1, 1.2, 1),
		facing * CFrame.new(c[1] / 2 - 0.6, S.awningHeight - 1.2, -1.6),
		rgb(LB.colors.lantern),
		Enum.Material.Neon
	)
	lamp.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = rgb(LB.colors.lantern)
	light.Range = 18
	light.Brightness = 1.8
	light.Parent = lamp
	-- Le socle de la vitrine, devant le comptoir.
	local p = S.pedestal
	local pedestal = part(
		"SocleVitrine",
		Vector3.new(p[2], p[1], p[1]),
		facing * CFrame.new(0, p[2] / 2, -S.pedestalAhead) * CFrame.Angles(0, 0, math.pi / 2),
		dark,
		Enum.Material.Slate
	)
	pedestal.Shape = Enum.PartType.Cylinder
	local rim = part(
		"BordVitrine",
		Vector3.new(0.15, p[1] + 0.4, p[1] + 0.4),
		-- Juste sous le dessus du socle : seul le bord depasse et luit (au
		-- ras du dessus, tout le disque brillait, vu en image).
		facing * CFrame.new(0, p[2] - 0.15, -S.pedestalAhead) * CFrame.Angles(0, 0, math.pi / 2),
		rgb(LB.colors.lantern),
		Enum.Material.Neon
	)
	rim.Shape = Enum.PartType.Cylinder
	rim.CanCollide = false
	-- X devant le comptoir : la boutique s'ouvre (cote client).
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = Config.shop.stallPrompt
	prompt.ActionText = "Ouvrir la boutique"
	prompt.ObjectText = "Boutique"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = S.promptDistance
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode[Config.controls.contexts.lobby.invite.keyboard]
	prompt.GamepadKeyCode = Enum.KeyCode[Config.controls.contexts.lobby.invite.gamepad]
	prompt.Parent = counter
end

local function range(pair: { number }): number
	return random:NextNumber(pair[1], pair[2])
end

-- Le decor sous l'Oeil (Config.lobby.decor) : nuages, Oeil qui veille,
-- arbres morts, buissons, rochers flottants.
local function decor()
	local D = LB.decor
	local cloud = rgb(D.cloudColor)
	-- Une boule aplatie : une part « Ball » serait une sphere du plus petit
	-- cote, d'ou la maille.
	local function puff(at: Vector3, width: number, height: number, color: Color3)
		local p = part(
			"Nuage",
			Vector3.new(width, height, width * random:NextNumber(0.6, 1)),
			CFrame.new(at) * CFrame.Angles(0, random:NextNumber(0, math.pi), 0),
			color,
			Enum.Material.SmoothPlastic
		)
		p.Transparency = D.cloudTransparency
		p.CastShadow = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	local function cluster(center: Vector3, width: number, height: number)
		for k = 1, D.cloudPuffs do
			-- La premiere boule au milieu, les autres plus petites a cote et un
			-- peu plus bas : une silhouette de nuage, pas une sphere.
			local s = if k == 1 then 1 else random:NextNumber(0.5, 0.8)
			local offset = if k == 1
				then Vector3.zero
				else Vector3.new(
					random:NextNumber(-0.5, 0.5) * width,
					-height * random:NextNumber(0.1, 0.3),
					random:NextNumber(-0.5, 0.5) * width
				)
			local shade = random:NextNumber(0.94, 1.02)
			puff(
				center + offset,
				width * s,
				height * s,
				Color3.new(
					math.min(1, cloud.R * shade),
					math.min(1, cloud.G * shade),
					math.min(1, cloud.B * shade)
				)
			)
		end
	end
	for _ = 1, D.cloudCount do
		local a = random:NextNumber(0, math.pi * 2)
		local d = math.sqrt(random:NextNumber(D.cloudInner ^ 2, D.cloudOuter ^ 2))
		cluster(
			ORIGIN
				+ Vector3.new(
					math.cos(a) * d,
					-D.cloudBelow + random:NextNumber(-D.cloudSpread, D.cloudSpread),
					math.sin(a) * d
				),
			range(D.cloudWidth),
			range(D.cloudHeight)
		)
	end
	for i = 1, D.bankCount do
		local a = (i + random:NextNumber(-0.4, 0.4)) / D.bankCount * math.pi * 2
		local d = range(D.bankRadius)
		cluster(
			ORIGIN + Vector3.new(math.cos(a) * d, -D.bankBelow, math.sin(a) * d),
			range(D.bankWidth),
			range(D.bankHeight)
		)
	end
	local floor = part(
		"MerDeNuages",
		Vector3.new(1, D.cloudFloorSize, D.cloudFloorSize),
		CFrame.new(ORIGIN - Vector3.new(0, D.cloudFloorBelow, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		rgb(D.cloudFloorColor),
		Enum.Material.SmoothPlastic
	)
	floor.Shape = Enum.PartType.Cylinder
	floor.CastShadow = false
	floor.CanCollide = false
	floor.CanQuery = false
	-- Arbres morts et buissons, contre le muret.
	local library = game:GetService("ServerStorage"):FindFirstChild(D.models)
	if library == nil then
		warn("[Royale] Salon : ServerStorage." .. D.models .. " manque, pas d'arbres")
	else
		local function plant(name: string, angle: number, radius: number, scale: number)
			local model = library:FindFirstChild(name)
			if model == nil or not model:IsA("Model") then
				warn("[Royale] Salon : modele " .. name .. " manquant")
				return
			end
			local m = model:Clone()
			m:ScaleTo(scale)
			local cf, size = m:GetBoundingBox()
			local bottom = m:GetPivot().Position.Y - (cf.Position.Y - size.Y / 2)
			local a = math.rad(angle)
			m:PivotTo(
				CFrame.new(ORIGIN + Vector3.new(math.cos(a) * radius, bottom, math.sin(a) * radius))
					* CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0)
			)
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanQuery = false
				end
			end
			m.Parent = folder
		end
		for i, angle in D.treeAngles do
			plant(D.trees[(i - 1) % #D.trees + 1], angle, D.treeRadius, 1)
		end
		for _, angle in D.bushAngles do
			plant(D.bushes, angle, D.bushRadius, D.bushScale)
		end
	end
	-- Les rochers flottants (LobbyView les fait monter et descendre).
	local rocks = Instance.new("Folder")
	rocks.Name = "Flottants"
	rocks.Parent = folder
	for _ = 1, D.rocks do
		local a = random:NextNumber(0, math.pi * 2)
		local d = range(D.rockRadius)
		local s = range(D.rockSize)
		local center = ORIGIN + Vector3.new(math.cos(a) * d, -range(D.rockBelow), math.sin(a) * d)
		-- Les morceaux d'un meme rocher bougent ensemble (meme periode, meme
		-- phase).
		local period, phase = range(D.rockPeriod), random:NextNumber(0, math.pi * 2)
		for k = 1, D.rockPieces do
			local size = s * (if k == 1 then 1 else random:NextNumber(0.5, 0.8))
			local offset = if k == 1
				then Vector3.zero
				else Vector3.new(
					random:NextNumber(-0.4, 0.4),
					random:NextNumber(-0.4, 0.4),
					random:NextNumber(-0.4, 0.4)
				) * s
			local rock = part(
				"Rocher",
				Vector3.new(
					size,
					size * random:NextNumber(0.6, 1),
					size * random:NextNumber(0.7, 1.2)
				),
				CFrame.new(center + offset)
					* CFrame.Angles(
						random:NextNumber(0, math.pi),
						random:NextNumber(0, math.pi),
						random:NextNumber(0, math.pi)
					),
				rgb(LB.colors.dark),
				Enum.Material.Rock
			)
			rock.CanCollide = false
			rock.CanQuery = false
			rock:SetAttribute("Periode", period)
			rock:SetAttribute("Phase", phase)
			rock.Parent = rocks
		end
	end
	-- Le dessous s'effile en pointe : une ile arrachee, pas un palet.
	for _, layer in D.islandLayers do
		local radius = LB.radius * layer[1]
		local cone = part(
			"Ile",
			Vector3.new(14, radius * 2, radius * 2),
			CFrame.new(ORIGIN - Vector3.new(0, layer[2], 0)) * CFrame.Angles(0, 0, math.pi / 2),
			rgb(LB.colors.dark),
			Enum.Material.Rock
		)
		cone.Shape = Enum.PartType.Cylinder
		cone.CanCollide = false
		cone.CanQuery = false
	end
end

-- Un point ou se poser dans le salon.
function LobbyService.spot(): Vector3
	local a = random:NextNumber(0, math.pi * 2)
	local d = random:NextNumber(10, LB.radius - 12)
	return ORIGIN + Vector3.new(math.cos(a) * d, 4, math.sin(a) * d)
end

local function publish()
	for id, player in byId do
		local leader = state.groupOf[id]
		local g = leader and state.groups[leader]
		if g then
			local names: { string } = {}
			for _, m in g.members do
				local p = byId[m]
				table.insert(names, if p then p.DisplayName else "?")
			end
			player:SetAttribute(LB.groupAttribute, table.concat(names, ", "))
			player:SetAttribute(LB.modeAttribute, g.mode)
			player:SetAttribute(LB.readyAttribute, g.ready)
			player:SetAttribute(LB.privacyAttribute, g.privacy)
			local ends = privateEnds[g.leader]
			player:SetAttribute(
				LB.privateDepartAttribute,
				if ends then workspace:GetServerTimeNow() + (ends - os.clock()) else nil
			)
		end
	end
	workspace:SetAttribute(
		LB.countdownAttribute,
		if countdown
			then countdown.mode .. "|" .. tostring(
				workspace:GetServerTimeNow() + (countdown.ends - os.clock())
			)
			else nil
	)
end

local function addInvitePrompt(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or root:FindFirstChild("RoyaleInviter") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RoyaleInviter"
	prompt.ActionText = "Inviter dans mon groupe"
	prompt.ObjectText = player.DisplayName
	prompt.HoldDuration = LB.inviteHoldSeconds
	prompt.MaxActivationDistance = LB.inviteDistance
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode[Config.controls.contexts.lobby.invite.keyboard]
	prompt.GamepadKeyCode = Enum.KeyCode[Config.controls.contexts.lobby.invite.gamepad]
	prompt.Parent = root
	prompt.Triggered:Connect(function(from: Player)
		LobbyService.invite(from, player)
	end)
end

-- Pose un joueur dans le salon (personnage neuf).
function LobbyService.place(player: Player)
	if away[player] then
		return
	end
	Avatar.load(player)
	local character = player.Character
	if character then
		character:PivotTo(CFrame.new(LobbyService.spot()))
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = Config.movement.walkSpeed
			humanoid.Died:Connect(function()
				task.wait(2)
				if player.Parent and not away[player] then
					LobbyService.place(player)
				end
			end)
		end
		addInvitePrompt(player)
	end
end

-- `from` invite `to` dans son groupe.
function LobbyService.invite(from: Player, to: Player)
	if from == to or away[from] or away[to] then
		return
	end
	invites[to] = { from = from, at = os.clock() }
	to:SetAttribute(
		LB.inviteAttribute,
		from.DisplayName .. "|" .. tostring(workspace:GetServerTimeNow())
	)
end

local function accept(player: Player)
	local invite = invites[player]
	invites[player] = nil
	player:SetAttribute(LB.inviteAttribute, nil)
	if invite == nil or os.clock() - invite.at > LB.inviteSeconds or invite.from.Parent == nil then
		return
	end
	if Lobby.join(state, idOf(invite.from), idOf(player), LB.maxGroup) then
		print(
			string.format(
				"[Royale] %s rejoint le groupe de %s",
				player.DisplayName,
				invite.from.DisplayName
			)
		)
	end
	publish()
end

local function action(player: Player, name: any, arg: any)
	if away[player] or typeof(name) ~= "string" then
		return
	end
	local id = idOf(player)
	if name == "accept" then
		accept(player)
		return
	elseif name == "leave" then
		Lobby.leave(state, id, true)
	elseif name == "mode" and typeof(arg) == "string" then
		Lobby.setMode(state, id, LB.modes, arg)
	elseif name == "privacy" and typeof(arg) == "string" then
		Lobby.setPrivacy(state, id, LB.privacies, arg)
	elseif name == "ready" then
		local g = state.groups[state.groupOf[id] or ""]
		Lobby.setReady(state, id, not (g and g.ready))
	end
	publish()
end

-- Ces groupes partent ensemble dans une partie de ce mode.
local function launch(ready: { Lobby.Group }, mode: string, privacy: string)
	local groups: { { Player } } = {}
	local players: { Player } = {}
	for _, g in ready do
		local list: { Player } = {}
		for _, m in g.members do
			local p = byId[m]
			if p and p.Parent then
				table.insert(list, p)
				table.insert(players, p)
			end
		end
		if #list > 0 then
			table.insert(groups, list)
		end
		g.ready = false
	end
	publish()
	if #players == 0 or onLaunch == nil then
		return
	end
	print(
		string.format(
			"[Royale] Départ du salon : %d joueur(s), mode %s, partie %s",
			#players,
			mode,
			privacy
		)
	)
	launching = true
	local ok, err = pcall(onLaunch :: any, players, mode, groups, privacy)
	launching = false
	if not ok then
		warn("[Royale] Le départ a échoué : " .. tostring(err))
	end
end

local function step()
	if launching then
		return
	end
	-- Les groupes prives : chacun son court compte a rebours, puis il part
	-- seul.
	local changed = false
	local stillReady: { [string]: Lobby.Group } = {}
	for _, g in Lobby.readyPrivate(state, PUBLIC) do
		stillReady[g.leader] = g
		if privateEnds[g.leader] == nil then
			privateEnds[g.leader] = os.clock() + LB.privateCountdownSeconds
			changed = true
		end
	end
	for leader, ends in privateEnds do
		local g = stillReady[leader]
		if g == nil then
			privateEnds[leader] = nil
			changed = true
		elseif os.clock() >= ends then
			privateEnds[leader] = nil
			launch({ g }, g.mode, g.privacy)
			return
		end
	end
	if changed then
		publish()
	end
	if countdown == nil then
		-- Le premier groupe public pret lance le compte a rebours de son mode.
		for _, mode in LB.modes do
			if #Lobby.readyGroups(state, mode, PUBLIC) > 0 then
				countdown = { mode = mode, ends = os.clock() + LB.countdownSeconds }
				publish()
				break
			end
		end
	elseif #Lobby.readyGroups(state, countdown.mode, PUBLIC) == 0 then
		countdown = nil
		publish()
	elseif os.clock() >= countdown.ends then
		local mode = countdown.mode
		countdown = nil
		launch(Lobby.readyGroups(state, mode, PUBLIC), mode, PUBLIC)
	end
end

-- Ces joueurs partent jouer sur ce serveur (Studio) : hors du salon.
function LobbyService.setAway(players: { Player }, isAway: boolean)
	for _, p in players do
		away[p] = if isAway then true else nil
	end
end

function LobbyService.isAway(player: Player): boolean
	return away[player] == true
end

function LobbyService.start(remote: RemoteEvent, launcher: Launcher)
	onLaunch = launcher
	build()
	print(string.format("[Royale] Salon : %d cachettes en vitrine", tutorial()))
	shopStall()
	-- Le decor n'est que visuel : il se construit apres le reste du
	-- demarrage (differe ; task.spawn l'aurait execute tout de suite).
	task.defer(function()
		local started = os.clock()
		decor()
		print(string.format("[Royale] Salon : décor construit en %.1f s", os.clock() - started))
	end)
	workspace:SetAttribute(Config.match.phaseAttribute, "Salon")
	remote.OnServerEvent:Connect(RemoteGuard.wrap(Config.remotes.lobby, action))
	local function joined(player: Player)
		local id = idOf(player)
		byId[id] = player
		Lobby.add(state, id, Config.squads.mode, PUBLIC)
		publish()
		LobbyService.place(player)
	end
	for _, player in Players:GetPlayers() do
		joined(player)
	end
	Players.PlayerAdded:Connect(joined)
	Players.PlayerRemoving:Connect(function(player: Player)
		local id = idOf(player)
		Lobby.leave(state, id, false)
		byId[id] = nil
		away[player] = nil
		invites[player] = nil
		publish()
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			local ok, err = pcall(step)
			if not ok then
				warn("[Royale] Salon : " .. tostring(err))
			end
		end
	end)
end

return LobbyService
