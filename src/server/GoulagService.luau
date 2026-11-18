--!strict
--[[
	GoulagService — le Ventre de l'Oeil (CONCEPT.md, Capture).

	Aspire avant les deux derniers cercles, et pour la premiere fois de la
	partie, on n'est pas elimine : on arrive dans une cage du Ventre. Toutes
	les 45 s au plus, une manche : tous ceux qui attendent sont repartis en
	duels un contre un, chacun sur sa plateforme dans le vide. La batte pour
	tous : 3 coups mettent K.O., un coup a terre envoie voler. Celui qui jette
	l'autre est sauve et retombe dans la partie, le sac vide ; celui qui tombe
	est elimine. Tomber tout seul ne sauve personne. La plateforme s'effrite,
	puis tout s'ecroule en mort subite : un duel a toujours un gagnant.
	Nombre impair : le dernier affronte un bot a la batte.

	Le Ventre se construit au demarrage du serveur, loin de la carte.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Royale = ReplicatedStorage:WaitForChild("Royale")
local Config = require(Royale:WaitForChild("Config"))
local Duels = require(Royale:WaitForChild("Duels"))

local CombatService = require(script.Parent.CombatService)
local HidingService = require(script.Parent.HidingService)
local ReprisService = require(script.Parent.ReprisService)
local ChallengeService = require(script.Parent.ChallengeService)
local Roster = require(script.Parent.Roster)
local SquadService = require(script.Parent.SquadService)
local World = require(script.Parent.World)
local ZoneService = require(script.Parent.ZoneService)

local GoulagService = {}

local G = Config.goulag
local ORIGIN = Vector3.new(G.origin[1], G.origin[2], G.origin[3])

type Duel = {
	a: Roster.Actor,
	b: Roster.Actor,
	-- Le bot de la manche impaire (b), a detruire a la fin.
	bot: Model?,
	platform: BasePart,
	rim: BasePart,
	spot: SpotLight?,
	center: Vector3,
	started: number,
	over: boolean,
}

local folder: Instance? = nil
local platforms: { { top: BasePart, rim: BasePart, center: Vector3, spot: SpotLight } } = {}
-- Ceux qui sont au Ventre (en cage ou en duel), dans l'ordre d'arrivee.
local queue: { Roster.Actor } = {}
local fighting: { [Roster.Actor]: Duel } = {}
local duels: { Duel } = {}
local used: { [Roster.Actor]: boolean } = {}
local nextRound = math.huge
local roundRunning = false
local closed = false
local random = Random.new()

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
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

-- Le Ventre (refait le 16 novembre 2026 : Josh ne comprenait pas ou il
-- arrivait, « un truc sombre, on peut a peine bouger, des murs
-- invisibles », et ne voyait pas son adversaire). Au centre, la Fosse : une
-- grande plateforme ronde ou l'on attend libre de ses mouvements, fermee
-- par un rideau d'energie qu'on VOIT (plus de cage etroite aux murs
-- invisibles), eclairee de braseros. Autour, les plateformes de duel,
-- toujours visibles, qui s'embrasent quand on s'y bat. Tout le Ventre est
-- envoye d'un coup a chaque joueur (Persistent) : avant, le streaming de
-- Roblox le livrait par morceaux, on arrivait dans le noir.
-- Public pour le regarder en mode edition (puis l'effacer).
function GoulagService.build()
	local old = workspace:FindFirstChild(G.folder)
	if old then
		old:Destroy()
	end
	local f = Instance.new("Model")
	f.Name = G.folder
	f.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	f.Parent = workspace
	World.ignore(f)
	folder = f
	local V = G.look
	local stone, rim, ember = rgb(G.colors.stone), rgb(G.colors.rim), rgb(G.colors.ember)
	local flat = CFrame.Angles(0, 0, math.pi / 2)

	local function light(
		parent: Instance,
		kind: string,
		color: Color3,
		range: number,
		brightness: number
	): Light
		local l = Instance.new(kind) :: Light
		l.Color = color
		l.Brightness = brightness;
		(l :: any).Range = range
		l.Shadows = false
		l.Parent = parent
		return l
	end

	local function brazier(at: Vector3, scale: number)
		local bowl = part(
			"Brasero",
			Vector3.new(1.2, 3, 3) * scale,
			CFrame.new(at + Vector3.new(0, 3.4 * scale, 0)) * flat,
			rgb(G.colors.iron),
			Enum.Material.Metal
		)
		bowl.Shape = Enum.PartType.Cylinder
		local foot = part(
			"Pied",
			Vector3.new(0.6, 3.4, 0.6) * scale,
			CFrame.new(at + Vector3.new(0, 1.7 * scale, 0)),
			rgb(G.colors.iron),
			Enum.Material.Metal
		)
		foot.CanCollide = true
		local coals = part(
			"Braises",
			Vector3.new(0.4, 2.6, 2.6) * scale,
			CFrame.new(at + Vector3.new(0, 4 * scale, 0)) * flat,
			ember,
			Enum.Material.Neon
		)
		coals.Shape = Enum.PartType.Cylinder
		coals.CanCollide = false
		local fire = Instance.new("Fire")
		fire.Color = ember
		fire.SecondaryColor = rim
		fire.Size = 5 * scale
		fire.Heat = 9
		fire.Parent = coals
		light(coals, "PointLight", ember, V.brazierRange * scale, V.brazierBrightness)
	end

	-- Les plateformes de duel, en cercle autour de la Fosse.
	for i = 1, G.platforms do
		local a = (i - 1) / G.platforms * math.pi * 2
		local center = ORIGIN
			+ Vector3.new(math.cos(a) * G.ringRadius, 0, math.sin(a) * G.ringRadius)
		local d = G.platformRadius * 2
		local top = part(
			"Plateforme" .. i,
			Vector3.new(G.platformThickness, d, d),
			CFrame.new(center) * flat,
			stone,
			Enum.Material.Basalt
		)
		top.Shape = Enum.PartType.Cylinder
		local edge = part(
			"Bord" .. i,
			Vector3.new(G.platformThickness * 0.6, d + 1, d + 1),
			CFrame.new(center - Vector3.new(0, G.platformThickness * 0.3, 0)) * flat,
			rim,
			Enum.Material.Neon
		)
		edge.Shape = Enum.PartType.Cylinder
		edge.CanCollide = false
		local glow = light(edge, "PointLight", rim, V.rimRange, V.rimBrightness)
		local embers = Instance.new("ParticleEmitter")
		embers.Color = ColorSequence.new(ember)
		embers.LightEmission = 1
		embers.Rate = 10
		embers.Lifetime = NumberRange.new(2, 4)
		embers.Speed = NumberRange.new(2, 6)
		embers.SpreadAngle = Vector2.new(180, 180)
		embers.Size = NumberSequence.new(0.35, 0)
		embers.Parent = edge
		-- Un projecteur au-dessus : le duel se voit de la Fosse, et les deux
		-- combattants se voient l'un l'autre (avant : le noir).
		local lamp = part(
			"Projecteur" .. i,
			Vector3.one,
			CFrame.new(center + Vector3.new(0, V.spotHeight, 0)),
			rim,
			Enum.Material.Neon
		)
		lamp.Transparency = 1
		lamp.CanCollide = false
		lamp.CanQuery = false
		local spot =
			light(lamp, "SpotLight", rgb(G.colors.spot), V.spotHeight + 20, V.spotBrightness) :: any
		spot.Face = Enum.NormalId.Bottom
		spot.Angle = V.spotAngle
		-- Au repos : une pierre sombre a la braise eteinte, qu'on ne foule pas.
		top.Transparency = V.idleTransparency
		top.CanCollide = false
		edge.Transparency = V.idleTransparency
		glow.Brightness = V.idleRimBrightness
		embers.Enabled = false
		spot.Enabled = false
		table.insert(platforms, { top = top, rim = edge, center = center, spot = spot })
	end

	-- La salle : six parois de chair sombre, veinees de braise. On ne doit
	-- voir ni la carte ni le ciel (vu en image : la carte flottait au loin).
	local wall = rgb(G.colors.wall)
	local h, below, above = G.room.half, G.room.below, G.room.above
	local height = below + above
	for _, spec in
		{
			{ Vector3.new(h * 2, 4, h * 2), Vector3.new(0, above, 0) },
			{ Vector3.new(h * 2, 4, h * 2), Vector3.new(0, -below, 0) },
			{ Vector3.new(4, height, h * 2), Vector3.new(h, (above - below) / 2, 0) },
			{ Vector3.new(4, height, h * 2), Vector3.new(-h, (above - below) / 2, 0) },
			{ Vector3.new(h * 2, height, 4), Vector3.new(0, (above - below) / 2, h) },
			{ Vector3.new(h * 2, height, 4), Vector3.new(0, (above - below) / 2, -h) },
		}
	do
		local p = part("Paroi", spec[1], CFrame.new(ORIGIN + spec[2]), wall, Enum.Material.Slate)
		p.CanCollide = false
		p.CanQuery = false
	end
	-- Le fond rougeoie loin sous les plateformes : on voit ou l'on tombe.
	local pit = part(
		"Fond",
		Vector3.new(h * 2 - 8, 1, h * 2 - 8),
		CFrame.new(ORIGIN - Vector3.new(0, below - 3, 0)),
		rgb(G.colors.pit),
		Enum.Material.Neon
	)
	pit.CanCollide = false
	pit.CanQuery = false
	-- (Opaque, il faisait un aplat rouge vif de dessin anime, vu en image.)
	pit.Transparency = 0.55
	for _ = 1, G.room.veins do
		local face = random:NextInteger(1, 4)
		local along = random:NextNumber(-h * 0.9, h * 0.9)
		local y = random:NextNumber(-below * 0.8, above * 0.8)
		local pos = if face == 1
			then Vector3.new(h - 2.2, y, along)
			elseif face == 2 then Vector3.new(-h + 2.2, y, along)
			elseif face == 3 then Vector3.new(along, y, h - 2.2)
			else Vector3.new(along, y, -h + 2.2)
		local vein = part(
			"Veine",
			Vector3.new(0.6, random:NextNumber(30, 90), 0.6),
			CFrame.new(ORIGIN + pos) * CFrame.Angles(0, 0, random:NextNumber(-0.6, 0.6)),
			rgb(G.colors.vein),
			Enum.Material.Neon
		)
		vein.CanCollide = false
		vein.CanQuery = false
	end
	-- Une lueur rouge qui baigne toute la salle, de haut : on y voit.
	for k = 1, V.fillLights do
		local a = (k - 1) / V.fillLights * math.pi * 2
		local holder = part(
			"Lueur",
			Vector3.one,
			CFrame.new(
				ORIGIN + Vector3.new(math.cos(a) * h * 0.5, above * 0.6, math.sin(a) * h * 0.5)
			),
			rim,
			Enum.Material.Neon
		)
		holder.Transparency = 1
		holder.CanCollide = false
		holder.CanQuery = false
		light(holder, "PointLight", rgb(G.colors.fill), V.fillRange, V.fillBrightness)
	end

	-- La Fosse, au centre : on y arrive, on y marche, on regarde les duels.
	local S = G.stand
	local floor = part(
		"Fosse",
		Vector3.new(4, S.radius * 2, S.radius * 2),
		CFrame.new(ORIGIN - Vector3.new(0, 2, 0)) * flat,
		stone,
		Enum.Material.Basalt
	)
	floor.Shape = Enum.PartType.Cylinder
	-- Un cercle de braise au bord du sol, et le rideau d'energie qu'on voit.
	local trim = part(
		"Liseré",
		Vector3.new(0.3, S.radius * 2 - 1, S.radius * 2 - 1),
		CFrame.new(ORIGIN + Vector3.new(0, 0.05, 0)) * flat,
		rim,
		Enum.Material.Neon
	)
	trim.Shape = Enum.PartType.Cylinder
	trim.CanCollide = false
	local inner = part(
		"Sol",
		Vector3.new(0.4, S.radius * 2 - 3, S.radius * 2 - 3),
		CFrame.new(ORIGIN + Vector3.new(0, 0.1, 0)) * flat,
		stone,
		Enum.Material.Basalt
	)
	inner.Shape = Enum.PartType.Cylinder
	for k = 1, S.segments do
		local a0 = (k - 1) / S.segments * math.pi * 2
		local a1 = k / S.segments * math.pi * 2
		local p0 = ORIGIN + Vector3.new(math.cos(a0) * S.radius, 0, math.sin(a0) * S.radius)
		local p1 = ORIGIN + Vector3.new(math.cos(a1) * S.radius, 0, math.sin(a1) * S.radius)
		local mid = (p0 + p1) / 2 + Vector3.new(0, S.curtainHeight / 2, 0)
		local panel = part(
			"Rideau",
			Vector3.new(0.4, S.curtainHeight, (p1 - p0).Magnitude + 0.1),
			-- La longueur suit le cercle (un quart de tour de trop les mettait
			-- en travers, des colonnes separees au lieu d'un rideau).
			CFrame.lookAt(mid, mid + (p1 - p0)),
			rim,
			Enum.Material.ForceField
		)
		panel.Transparency = S.curtainTransparency
		panel.CanQuery = false
		panel.CastShadow = false
		-- Un barreau de fer tous les quelques panneaux, la pointe en braise.
		if k % S.barEvery == 0 then
			part(
				"Barreau",
				Vector3.new(0.5, S.curtainHeight, 0.5),
				CFrame.new(p0 + Vector3.new(0, S.curtainHeight / 2, 0)),
				rgb(G.colors.iron),
				Enum.Material.Metal
			)
			local tip = part(
				"Pointe",
				Vector3.new(0.7, 0.7, 0.7),
				CFrame.new(p0 + Vector3.new(0, S.curtainHeight + 0.3, 0)),
				ember,
				Enum.Material.Neon
			)
			tip.CanCollide = false
		end
	end
	for k = 1, S.braziers do
		local a = (k - 0.5) / S.braziers * math.pi * 2
		brazier(
			ORIGIN + Vector3.new(math.cos(a) * (S.radius - 4), 0, math.sin(a) * (S.radius - 4)),
			1
		)
	end
	-- L'Oeil vous regarde d'en haut : son iris de braise au plafond.
	local iris = part(
		"IrisDuVentre",
		Vector3.new(0.6, S.radius, S.radius),
		CFrame.new(ORIGIN + Vector3.new(0, above - 3, 0)) * flat,
		ember,
		Enum.Material.Neon
	)
	iris.Shape = Enum.PartType.Cylinder
	iris.CanCollide = false
	iris.CanQuery = false
	local pupil = part(
		"PupilleDuVentre",
		Vector3.new(0.8, S.radius * 0.4, S.radius * 0.4),
		CFrame.new(ORIGIN + Vector3.new(0, above - 3.2, 0)) * flat,
		Color3.new(0, 0, 0),
		Enum.Material.SmoothPlastic
	)
	pupil.Shape = Enum.PartType.Cylinder
	pupil.CanCollide = false
	pupil.CanQuery = false
	(light(iris, "SpotLight", ember, above + 10, V.irisBrightness) :: any).Face = Enum.NormalId.Left
end

local function setState(actor: Roster.Actor, state: string?)
	actor:SetAttribute(G.stateAttribute, state)
end

local function place(actor: Roster.Actor, at: Vector3, facing: Vector3?)
	local root = Roster.rootOf(actor)
	if root == nil then
		return
	end
	root.Anchored = false
	root.AssemblyLinearVelocity = Vector3.zero
	local cf = if facing
		then CFrame.lookAt(at, Vector3.new(facing.X, at.Y, facing.Z))
		else CFrame.new(at)
	local character = Roster.characterOf(actor)
	if character then
		character:PivotTo(cf + Vector3.new(0, 3, 0))
	end
end

-- En attente : une place dans la Fosse, sur un cercle (chacun la sienne),
-- tourne vers les plateformes de duel.
local function toCage(actor: Roster.Actor)
	local S = G.stand
	local index = table.find(queue, actor) or (#queue + 1)
	local a = (index - 1) * S.spreadAngle
	local r = S.radius * (if index % 2 == 0 then S.spreadInner else S.spreadOuter)
	local at = ORIGIN + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	place(actor, at, at + (at - ORIGIN))
	setState(actor, "Cage")
end

local function destroyCharacter(actor: Roster.Actor)
	local character = Roster.characterOf(actor)
	if character then
		character:Destroy()
	end
end

local function remove(actor: Roster.Actor)
	local i = table.find(queue, actor)
	if i then
		table.remove(queue, i)
	end
	fighting[actor] = nil
	setState(actor, nil)
end

-- Elimine pour de bon : il rejoint les spectateurs.
local function eliminate(actor: Roster.Actor)
	remove(actor)
	print(string.format("[Royale] %s tombe du Ventre : elimine", Roster.nameOf(actor)))
	destroyCharacter(actor)
end

-- Sauve : il retombe dans le cercle, le sac vide.
local function save(actor: Roster.Actor)
	remove(actor)
	CombatService.reset(actor)
	ChallengeService.record(actor, "belly")
	-- En escouade : dans un cocon, pres d'un coequipier en vie.
	if SquadService.cocoon(actor) then
		return
	end
	local zone = ZoneService.current()
	local at = nil
	for _ = 1, 20 do
		local a = random:NextNumber(0, math.pi * 2)
		local r = random:NextNumber(0, zone.radius * 0.7)
		local ground = World.ground(zone.x + math.cos(a) * r, zone.z + math.sin(a) * r)
		if ground then
			at = ground
			break
		end
	end
	if at == nil then
		at = World.eyeOrigin
	end
	Roster.revive(actor)
	place(actor, (at :: Vector3) + Vector3.new(0, G.returnHeight, 0), nil)
	print(
		string.format("[Royale] %s sort du Ventre et retombe dans la partie", Roster.nameOf(actor))
	)
end

local function announce(text: string)
	workspace:SetAttribute(G.resultAttribute, text .. "|" .. tostring(workspace:GetServerTimeNow()))
end

local function endDuel(duel: Duel)
	if duel.over then
		return
	end
	duel.over = true
	-- La plateforme retourne au repos : entiere, sombre, qu'on ne foule pas.
	local V = G.look
	local d = G.platformRadius * 2
	duel.platform.Size = Vector3.new(G.platformThickness, d, d)
	duel.rim.Size = Vector3.new(G.platformThickness * 0.6, d + 1, d + 1)
	duel.platform.Transparency = V.idleTransparency
	duel.platform.CanCollide = false
	duel.rim.Transparency = V.idleTransparency
	local light = duel.rim:FindFirstChildOfClass("PointLight")
	if light then
		light.Brightness = V.idleRimBrightness
	end
	local embers = duel.rim:FindFirstChildOfClass("ParticleEmitter")
	if embers then
		embers.Enabled = false
	end
	if duel.spot then
		duel.spot.Enabled = false
	end
	if duel.bot then
		fighting[duel.bot] = nil
		duel.bot:Destroy()
	end
end

-- `fallen` est tombe : ce que devient l'autre.
local function resolve(duel: Duel, fallen: Roster.Actor, sudden: boolean)
	local other = if fallen == duel.a then duel.b else duel.a
	local hitBy = CombatService.attackerOf(fallen, G.lastHitSeconds) == other
	local outcome = Duels.outcome(hitBy, sudden)
	if fallen ~= duel.bot then
		eliminate(fallen)
	end
	if other == duel.bot then
		announce(Roster.nameOf(fallen) .. " est dévoré par le Repris du Ventre")
	elseif outcome == "saved" then
		announce(Roster.nameOf(other) .. " jette " .. Roster.nameOf(fallen) .. " dans le vide")
		save(other)
	else
		-- Tombe tout seul : l'autre retourne en cage pour la manche suivante.
		toCage(other)
		fighting[other] = nil
	end
	endDuel(duel)
end

-- Le bot de la manche impaire, ou un bot de la partie qui se bat : il va sur
-- son adversaire, frappe, et ne s'approche pas du bord.
local function botThink(self: Roster.Actor, duel: Duel)
	local root = Roster.rootOf(self)
	local foe = if self == duel.a then duel.b else duel.a
	local foeRoot = Roster.rootOf(foe)
	local humanoid = (Roster.characterOf(self) :: Model):FindFirstChildOfClass("Humanoid")
	if root == nil or foeRoot == nil or humanoid == nil or CombatService.isDown(self) then
		return
	end
	local radius = Duels.radius(os.clock() - duel.started - G.introSeconds, G)
	local fromCenter =
		Vector3.new(root.Position.X - duel.center.X, 0, root.Position.Z - duel.center.Z)
	if fromCenter.Magnitude > radius - 2 then
		humanoid:MoveTo(duel.center)
		return
	end
	local d = (foeRoot.Position - root.Position).Magnitude
	if d <= Config.combat.hitRange then
		root.CFrame = CFrame.lookAt(
			root.Position,
			Vector3.new(foeRoot.Position.X, root.Position.Y, foeRoot.Position.Z)
		)
		humanoid:MoveTo(root.Position)
		CombatService.gesture(self, "hit")
	else
		humanoid:MoveTo(foeRoot.Position)
	end
end

local function makeBot(): Model
	local model = ReprisService.body("wanderer")
	model.Name = G.botName
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.WalkSpeed = Config.movement.walkSpeed
	humanoid.DisplayName = G.botName
	model.Parent = folder
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	root:SetNetworkOwner(nil)
	return model
end

local function startDuel(a: Roster.Actor, b: Roster.Actor?, slot: number)
	local p = platforms[slot]
	local d = G.platformRadius * 2
	p.top.Size = Vector3.new(G.platformThickness, d, d)
	p.rim.Size = Vector3.new(G.platformThickness * 0.6, d + 1, d + 1)
	p.top.Transparency = 0
	p.top.CanCollide = true
	p.rim.Transparency = 0
	p.spot.Enabled = true
	local light = p.rim:FindFirstChildOfClass("PointLight")
	if light then
		light.Brightness = G.look.rimBrightness
	end
	local embers = p.rim:FindFirstChildOfClass("ParticleEmitter")
	if embers then
		embers.Enabled = true
	end
	local bot: Model? = nil
	local foe: Roster.Actor
	if b then
		foe = b
	else
		bot = makeBot()
		foe = bot :: Model
	end
	local duel: Duel = {
		a = a,
		b = foe,
		bot = bot,
		platform = p.top,
		rim = p.rim,
		spot = p.spot,
		center = p.center,
		started = os.clock(),
		over = false,
	}
	table.insert(duels, duel)
	local top = p.center + Vector3.new(0, G.platformThickness / 2, 0)
	for k, actor in { a, foe } do
		fighting[actor] = duel
		CombatService.reset(actor)
		local side = if k == 1 then 1 else -1
		place(actor, top + Vector3.new(side * G.startOffset, 0, 0), p.center)
		setState(actor, "Duel")
		-- Le decompte : immobiles, face a face.
		local root = Roster.rootOf(actor)
		if root then
			root.Anchored = true
			task.delay(G.introSeconds, function()
				if root.Parent then
					root.Anchored = false
				end
			end)
		end
	end
end

local function startRound()
	roundRunning = true
	table.clear(duels)
	local order: { string } = {}
	local byId: { [string]: Roster.Actor } = {}
	for _, actor in queue do
		local id = Roster.idOf(actor)
		table.insert(order, id)
		byId[id] = actor
	end
	for i = #order, 2, -1 do
		local j = random:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	-- Jamais deux coequipiers dans le meme duel (CONCEPT.md).
	local team: { [string]: string } = {}
	for id, actor in byId do
		local t = SquadService.teamOf(actor)
		if t and SquadService.size() > 1 then
			team[id] = tostring(t)
		end
	end
	local pairs, alone = Duels.pair(order, team)
	local slot = 0
	for _, p in pairs do
		slot += 1
		if slot > #platforms then
			break
		end
		startDuel(byId[p[1]], byId[p[2]], slot)
	end
	if alone and slot < #platforms then
		slot += 1
		startDuel(byId[alone], nil, slot)
	end
	workspace:SetAttribute(G.roundAttribute, nil)
	print(string.format("[Royale] Manche du Ventre : %d duel(s)", #duels))
end

local function step()
	local now = os.clock()
	if not roundRunning and #queue > 0 and now >= nextRound then
		startRound()
	end
	if not roundRunning then
		return
	end
	local anyLeft = false
	for _, duel in duels do
		if duel.over then
			continue
		end
		anyLeft = true
		local t = now - duel.started - G.introSeconds
		local radius, sudden = Duels.radius(t, G)
		local d = math.max(radius * 2, 0.05)
		duel.platform.Size = Vector3.new(G.platformThickness, d, d)
		duel.rim.Size = Vector3.new(G.platformThickness * 0.6, d + 1, d + 1)
		for _, actor in { duel.a, duel.b } do
			fighting[actor] = duel
			if actor:IsA("Player") then
				actor:SetAttribute(G.suddenAttribute, sudden)
			end
		end
		-- Qui est tombe ? (un participant parti du serveur aussi.)
		for _, actor in { duel.a, duel.b } do
			local root = Roster.rootOf(actor)
			if root == nil or root.Position.Y < duel.center.Y - G.fallBelow then
				resolve(duel, actor, sudden)
				break
			end
		end
	end
	if not anyLeft then
		roundRunning = false
		table.clear(duels)
		if #queue > 0 then
			nextRound = now + G.roundSeconds - (G.introSeconds + G.duelSeconds + G.suddenSeconds)
			workspace:SetAttribute(
				G.roundAttribute,
				workspace:GetServerTimeNow() + (nextRound - now)
			)
			for _, actor in queue do
				toCage(actor)
			end
		end
	end
end

-- Le goulag prend-il cet aspire ? (Roster.setKeeper)
local function keep(actor: Roster.Actor, _character: Model): boolean
	local regard = workspace:GetAttribute(Config.match.regardAttribute)
	if
		closed
		or typeof(regard) ~= "number"
		or not Duels.open(regard, G.closesAtRegard, used[actor] == true)
		or Roster.count() <= 1
	then
		return false
	end
	used[actor] = true
	table.insert(queue, actor)
	fighting[actor] = nil
	HidingService.leave(actor)
	toCage(actor)
	if #queue == 1 and not roundRunning then
		nextRound = os.clock() + G.firstWaitSeconds
	elseif not roundRunning then
		nextRound = math.max(nextRound, os.clock() + 3)
	end
	if not roundRunning then
		workspace:SetAttribute(
			G.roundAttribute,
			workspace:GetServerTimeNow() + (nextRound - os.clock())
		)
	end
	print(string.format("[Royale] %s arrive dans le Ventre de l'Oeil", Roster.nameOf(actor)))
	return true
end

-- Un nouveau Regard : au premier des deux derniers cercles, il ferme. Ceux
-- qui attendent jouent une derniere manche tout de suite.
function GoulagService.onRegard(regard: number)
	if regard >= G.closesAtRegard and not closed then
		closed = true
		if #queue > 0 and not roundRunning then
			nextRound = os.clock()
		end
		print("[Royale] Le Ventre se ferme : etre aspire est definitif")
	end
end

function GoulagService.isInside(actor: Roster.Actor): boolean
	return table.find(queue, actor) ~= nil
end

function GoulagService.reset()
	for _, duel in duels do
		endDuel(duel)
	end
	for _, actor in table.clone(queue) do
		remove(actor)
		destroyCharacter(actor)
	end
	table.clear(queue)
	table.clear(fighting)
	table.clear(duels)
	table.clear(used)
	nextRound = math.huge
	roundRunning = false
	closed = false
	workspace:SetAttribute(G.roundAttribute, nil)
	workspace:SetAttribute(G.resultAttribute, nil)
end

function GoulagService.start()
	GoulagService.build()
	Roster.setKeeper(keep)
	CombatService.setArena(function()
		local out = table.clone(queue)
		for actor in fighting do
			if not table.find(out, actor) then
				table.insert(out, actor)
			end
		end
		return out
	end, G.rules)
	task.spawn(function()
		while true do
			task.wait(0.1)
			local ok, err = pcall(step)
			if not ok then
				warn("[Royale] Ventre : " .. tostring(err))
			end
		end
	end)
	-- Les bots qui se battent au Ventre (ceux de la partie, et celui des
	-- manches impaires) : le meme petit cerveau.
	task.spawn(function()
		while true do
			task.wait(G.botThinkSeconds)
			for actor, duel in table.clone(fighting) do
				if not actor:IsA("Player") and not duel.over then
					local ok, err = pcall(botThink, actor, duel)
					if not ok then
						warn("[Royale] Bot du Ventre : " .. tostring(err))
					end
				end
			end
		end
	end)
	-- Un joueur du Ventre parti du serveur.
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		remove(player)
	end)
end

return GoulagService
