--!strict
--[[
	HidingService — les cachettes (CONCEPT.md, Cachettes).

	A chaque partie, des modeles de ServerStorage.RoyaleCachettes se posent sur
	une partie des emplacements de la recette (jamais les memes d'une partie a
	l'autre). Les cachettes solides de la carte (tunnels, chambre froide) sont
	toujours la et ne s'arrachent jamais.

	Entrer (maintenir X) : on se tient dans le modele, invisible a l'Oeil, et
	la cachette se MARQUE. L'Oeil ne vient pas la chercher pendant l'ouverture
	ou l'on y entre, seulement aux suivantes (`markBursts` au plus) : il
	l'arrache alors a la vue de tous, apres un tremblement qui laisse le temps
	de sortir. Ejecte, on a `graceSeconds` de repit pour courir.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Royale = ReplicatedStorage:WaitForChild("Royale")
local Config = require(Royale:WaitForChild("Config"))

local Roster = require(script.Parent.Roster)
local Sfx = require(script.Parent.Sfx)
local World = require(script.Parent.World)

local HidingService = {}

local W = Config.world
local H = Config.hiding

export type Spot = {
	model: Model,
	inside: BasePart,
	exits: { BasePart },
	solid: boolean,
	-- Ceux qui y sont : un abri ferme n'en prend qu'un, un volume (buisson,
	-- roseaux, abri, dessous de pont...) plusieurs (CONCEPT.md).
	occupants: { Roster.Actor },
	capacity: number,
	-- Sa sorte (le nom du modele sans son numero) : ses mecaniques en
	-- dependent (CONCEPT.md, les cachettes a mecanique).
	kind: string,
	-- Le numero de l'ouverture pendant laquelle (ou apres laquelle) on y est
	-- entre pour la derniere fois ; nil : pas marquee.
	mark: number?,
	ripping: boolean,
	prompt: ProximityPrompt,
	-- Les objets poses dessus (ItemService) : clochette, piege, barricade
	-- (heure de fin, os.clock), fausse cachette (le Carton piege).
	bell: boolean,
	trap: boolean,
	barricadedUntil: number,
	fake: boolean,
	-- Depuis quand l'occupant y est (os.clock), pour le flair de l'Oeil.
	since: number,
}

local spots: { Spot } = {}
local byPlayer: { [Roster.Actor]: Spot } = {}
local placed: Folder? = nil
-- Les emplacements deja occupes cette partie (on n'y pose pas deux fois).
local usedAnchors: { [BasePart]: boolean } = {}
local random = Random.new()
-- Les egouts en route (on rampe vers une autre plaque) : on ne repart pas.
local traveling: { [Roster.Actor]: boolean } = {}
-- Les salles deja construites sous les plaques (une fois par serveur).
local rooms: { [BasePart]: boolean } = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function roomPart(
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
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.CanTouch = false
	p.Parent = parent
	return p
end

-- La salle sous une plaque d'egout (CONCEPT.md : « etroit ») : murs de
-- briques, sol et rigole d'eau, echelle, tuyaux, gouttes, la lumiere froide
-- qui tombe de la grille et une lampe de chantier. Le terrain y est creuse.
-- Rend le point ou l'on se tient.
local function buildSewerRoom(cover: BasePart, folder: Instance): CFrame
	local S = H.sewer
	local R = S.room
	local top = cover.Position
	local ceilingY = top.Y - R.ceilingBelow
	local floorY = ceilingY - R.height
	local center = Vector3.new(top.X, floorY + R.height / 2, top.Z)
	local stand = CFrame.new(top.X, floorY + S.standHeight, top.Z)
	if rooms[cover] then
		return stand
	end
	rooms[cover] = true
	local w, l, h = R.width, R.length, R.height
	-- Le terrain se range par cases de 4 studs : creuse au plus juste, ses
	-- bords recouvraient les murs de briques (vu a l'image, de l'herbe aux
	-- murs). On creuse plus large que la salle, murs compris ; la salle est
	-- assez bas pour que ce creusement n'entame pas la couche du dessus (a 1
	-- stud sous la route, il ouvrait des trous au bord : mesure au rayon).
	workspace.Terrain:FillBlock(
		CFrame.new(center),
		Vector3.new(w + S.carveMargin, h, l + S.carveMargin),
		Enum.Material.Air
	)
	-- Le puits, de la plaque au plafond : etroit, sous la route seulement.
	local shaftTop = top.Y - S.shaftTopBelow
	local shaftHeight = shaftTop - ceilingY
	workspace.Terrain:FillBlock(
		CFrame.new(top.X, ceilingY + shaftHeight / 2, top.Z),
		Vector3.new(S.hole, shaftHeight, S.hole),
		Enum.Material.Air
	)
	local room = Instance.new("Model")
	room.Name = "SalleEgout"
	local brick, floorColor = rgb(S.brick), rgb(S.floor)
	local rust = Color3.fromRGB(90, 70, 50)
	for _, side in { -1, 1 } do
		roomPart(
			room,
			"Puits",
			Vector3.new(0.4, shaftHeight, S.hole + 0.8),
			CFrame.new(top.X + side * (S.hole / 2 + 0.2), ceilingY + shaftHeight / 2, top.Z),
			brick,
			Enum.Material.Brick
		)
		roomPart(
			room,
			"Puits",
			Vector3.new(S.hole, shaftHeight, 0.4),
			CFrame.new(top.X, ceilingY + shaftHeight / 2, top.Z + side * (S.hole / 2 + 0.2)),
			brick,
			Enum.Material.Brick
		)
	end
	roomPart(
		room,
		"Sol",
		Vector3.new(w, 1, l),
		CFrame.new(top.X, floorY - 0.5, top.Z),
		floorColor,
		Enum.Material.Slate
	)
	local water = roomPart(
		room,
		"Eau",
		Vector3.new(2.4, 0.2, l),
		CFrame.new(top.X, floorY + 0.05, top.Z),
		rgb(S.water),
		Enum.Material.Glass
	)
	water.Transparency = 0.25
	water.Reflectance = 0.3
	water.CanCollide = false
	for _, side in { -1, 1 } do
		roomPart(
			room,
			"Mur",
			Vector3.new(1, h, l + 2),
			CFrame.new(top.X + side * (w / 2 + 0.5), center.Y, top.Z),
			brick,
			Enum.Material.Brick
		)
		roomPart(
			room,
			"Mur",
			Vector3.new(w, h, 1),
			CFrame.new(top.X, center.Y, top.Z + side * (l / 2 + 0.5)),
			brick,
			Enum.Material.Brick
		)
	end
	-- Le plafond, perce sous la plaque : quatre dalles autour du trou.
	local hole = S.hole
	local band = (w - hole) / 2
	for _, side in { -1, 1 } do
		roomPart(
			room,
			"Plafond",
			Vector3.new(band, 1, l),
			CFrame.new(top.X + side * (hole / 2 + band / 2), ceilingY + 0.5, top.Z),
			floorColor,
			Enum.Material.Concrete
		)
		roomPart(
			room,
			"Plafond",
			Vector3.new(hole, 1, (l - hole) / 2),
			CFrame.new(top.X, ceilingY + 0.5, top.Z + side * (hole / 2 + (l - hole) / 4)),
			floorColor,
			Enum.Material.Concrete
		)
	end
	-- La grille, et la lumiere froide du dehors qui tombe par elle.
	local grate = roomPart(
		room,
		"Grille",
		Vector3.new(hole, 0.2, hole),
		CFrame.new(top.X, shaftTop - 0.1, top.Z),
		Color3.fromRGB(40, 40, 42),
		Enum.Material.DiamondPlate
	)
	grate.Transparency = 0.35
	grate.CanCollide = false
	local daylight = Instance.new("SpotLight")
	daylight.Face = Enum.NormalId.Bottom
	daylight.Color = rgb(S.grateLight)
	daylight.Brightness = S.grateBrightness
	daylight.Range = h + shaftHeight + 4
	daylight.Angle = S.grateAngle
	daylight.Parent = grate
	-- L'echelle, du sol jusqu'en haut du puits, contre sa paroi.
	local ladderX = top.X + hole / 2 - 0.35
	local ladderHeight = shaftTop - floorY
	for _, side in { -0.6, 0.6 } do
		roomPart(
			room,
			"Montant",
			Vector3.new(0.2, ladderHeight, 0.2),
			CFrame.new(ladderX, floorY + ladderHeight / 2, top.Z + side),
			rust,
			Enum.Material.CorrodedMetal
		).CanCollide =
			false
	end
	for i = 1, math.floor(ladderHeight) - 1 do
		roomPart(
			room,
			"Barreau",
			Vector3.new(0.15, 0.15, 1.2),
			CFrame.new(ladderX, floorY + i, top.Z),
			rust,
			Enum.Material.CorrodedMetal
		).CanCollide =
			false
	end
	-- Deux tuyaux le long des murs, sous le plafond.
	for _, side in { -1, 1 } do
		local pipe = roomPart(
			room,
			"Tuyau",
			Vector3.new(l, 0.7, 0.7),
			CFrame.new(top.X + side * (w / 2 - 0.6), ceilingY - 0.8, top.Z)
				* CFrame.Angles(0, math.pi / 2, 0),
			Color3.fromRGB(70, 74, 70),
			Enum.Material.Metal
		)
		pipe.Shape = Enum.PartType.Cylinder
		pipe.CanCollide = false
	end
	-- La lampe de chantier, au mur du fond.
	local lamp = roomPart(
		room,
		"Lampe",
		Vector3.new(0.5, 0.7, 0.5),
		CFrame.new(top.X, floorY + h * 0.7, top.Z - l / 2 + 0.3),
		rgb(S.lamp),
		Enum.Material.Neon
	)
	lamp.CanCollide = false
	local glow = Instance.new("PointLight")
	glow.Color = rgb(S.lamp)
	glow.Range = S.lampRange
	glow.Brightness = S.lampBrightness
	glow.Shadows = true
	glow.Parent = lamp
	-- Des gouttes qui tombent du plafond dans l'eau.
	local drips = Instance.new("ParticleEmitter")
	drips.Color = ColorSequence.new(rgb(S.water))
	drips.Size = NumberSequence.new(0.08)
	drips.Lifetime = NumberRange.new(1, 1.4)
	drips.Rate = 3
	drips.Speed = NumberRange.new(0)
	drips.Acceleration = Vector3.new(0, -workspace.Gravity / 6, 0)
	drips.EmissionDirection = Enum.NormalId.Bottom
	drips.Parent = grate
	room.Parent = folder
	return stand
end
-- Le numero de la derniere ouverture de l'Oeil (tenu par EyeService).
local burstSerial = 0
local enterCallbacks: { (Roster.Actor, Spot) -> () } = {}
local releaseCallbacks: { (Roster.Actor, Spot) -> () } = {}

local function markersOf(model: Instance): (BasePart?, { BasePart })
	local inside: BasePart? = nil
	local exits: { BasePart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == W.inside then
				inside = d
			elseif d.Name == W.exit then
				table.insert(exits, d)
			end
		end
	end
	return inside, exits
end

local function nearestExit(spot: Spot, from: Vector3): BasePart
	local best = spot.exits[1]
	local bestD = math.huge
	for _, e in spot.exits do
		local d = (e.Position - from).Magnitude
		if d < bestD then
			best, bestD = e, d
		end
	end
	return best
end

-- La place d'un occupant dans la cachette : le premier au centre, les
-- suivants a cote (on se tient serres dans un buisson).
local function seat(spot: Spot, index: number): CFrame
	if index <= 1 then
		return spot.inside.CFrame
	end
	local side = if index % 2 == 0 then 1 else -1
	local step = math.floor(index / 2) * H.seatSpacing
	return spot.inside.CFrame * CFrame.new(side * step, 0, 0)
end

local function farthestExit(spot: Spot, from: Vector3): BasePart
	local best = spot.exits[1]
	local bestD = -math.huge
	for _, e in spot.exits do
		local d = (e.Position - from).Magnitude
		if d > bestD then
			best, bestD = e, d
		end
	end
	return best
end

local function release(player: Roster.Actor, spot: Spot, grace: boolean, awayFrom: Vector3?)
	byPlayer[player] = nil
	local i = table.find(spot.occupants, player)
	if i then
		table.remove(spot.occupants, i)
	end
	spot.prompt.Enabled = not spot.ripping and #spot.occupants < spot.capacity
	player:SetAttribute(H.hiddenAttribute, nil)
	player:SetAttribute(H.closedAttribute, nil)
	local root = Roster.rootOf(player)
	if root then
		-- Delogee, on sort par le cote oppose a celui qui pousse (la voiture
		-- a deux portieres, CONCEPT.md) ; sinon par la sortie la plus proche.
		local exit = if #spot.exits == 0
			then spot.inside
			elseif awayFrom then farthestExit(spot, awayFrom)
			else nearestExit(spot, root.Position)
		root.Anchored = false
		root.CFrame = CFrame.new(exit.Position + Vector3.new(0, 1, 0))
			* (exit.CFrame - exit.CFrame.Position)
	end
	if grace then
		player:SetAttribute(
			Config.eye.graceAttribute,
			workspace:GetServerTimeNow() + Config.eye.graceSeconds
		)
	end
	for _, callback in releaseCallbacks do
		callback(player, spot)
	end
end

-- Au sol, en portant quelqu'un ou porte : on n'entre nulle part.
local function busy(player: Roster.Actor): boolean
	local C = Config.combat
	local down = player:GetAttribute(C.downAttribute)
	return (typeof(down) == "number" and workspace:GetServerTimeNow() < down)
		or player:GetAttribute(C.carryingAttribute) ~= nil
		or player:GetAttribute(C.carriedAttribute) ~= nil
		-- Dans un cocon, on attend qu'on nous ouvre (vu au banc d'equilibrage :
		-- un bot en cocon entrait dans un egout voisin, puis tombait sous la
		-- carte a l'ouverture du cocon).
		or player:GetAttribute(Config.squads.cocoonAttribute) == true
end

-- Le nom que voit le joueur : sans numero, en mots (Config.hiding.displayNames).
local function displayName(model: Model): string
	local base = string.gsub(model.Name, "%d+$", "")
	return H.displayNames[base] or base
end

local function enter(player: Roster.Actor, spot: Spot)
	if
		not Roster.isAlive(player)
		or #spot.occupants >= spot.capacity
		or spot.ripping
		or byPlayer[player]
		or busy(player)
	then
		return
	end
	local root = Roster.rootOf(player)
	if root == nil then
		return
	end
	table.insert(spot.occupants, player)
	if #spot.occupants == 1 then
		spot.since = os.clock()
	end
	spot.mark = burstSerial
	spot.prompt.Enabled = #spot.occupants < spot.capacity
	byPlayer[player] = spot
	player:SetAttribute(H.hiddenAttribute, displayName(spot.model))
	player:SetAttribute(
		H.closedAttribute,
		if spot.capacity <= 1 and spot.kind ~= H.sewer.name then true else nil
	)
	root.Anchored = true
	root.CFrame = seat(spot, #spot.occupants)
	for _, callback in enterCallbacks do
		callback(player, spot)
	end
end

local function makeSpot(model: Model, solid: boolean): Spot?
	local inside, exits = markersOf(model)
	if inside == nil then
		warn("[Royale] Cachette sans « " .. W.inside .. " » : " .. model:GetFullName())
		return nil
	end
	local holder = if #exits > 0 then exits[1] else inside
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = H.actionText[(string.gsub(model.Name, "%d+$", ""))] or H.defaultAction
	prompt.ObjectText = displayName(model)
	prompt.HoldDuration = H.enterHoldSeconds
	prompt.MaxActivationDistance = H.promptDistance
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode[Config.controls.contexts.onFoot.interact.keyboard]
	prompt.GamepadKeyCode = Enum.KeyCode[Config.controls.contexts.onFoot.interact.gamepad]
	prompt.Parent = holder
	local spot: Spot = {
		model = model,
		inside = inside,
		exits = exits,
		solid = solid,
		occupants = {},
		capacity = H.capacity[(string.gsub(model.Name, "%d+$", ""))] or H.defaultCapacity,
		kind = (string.gsub(model.Name, "%d+$", "")),
		bell = false,
		trap = false,
		barricadedUntil = 0,
		fake = false,
		since = 0,
		mark = nil,
		ripping = false,
		prompt = prompt,
	}
	prompt.Triggered:Connect(function(player: Player)
		HidingService.tryEnter(player, model)
	end)
	table.insert(spots, spot)
	return spot
end

-- Les modeles qui peuvent aller sur un emplacement `Prefab` : le nom exact,
-- ou ses variantes numerotees (Voiture, Voiture2...).
local function variantsOf(prefab: string): { Model }
	local out: { Model } = {}
	local library = World.prefabs
	if library == nil then
		return out
	end
	for _, m in library:GetChildren() do
		if m:IsA("Model") and string.match(m.Name, "^" .. prefab .. "%d*$") then
			table.insert(out, m)
		end
	end
	return out
end

-- Tout enlever : sortir chacun, detruire les cachettes posees, retirer les
-- invites des cachettes solides.
function HidingService.clear()
	for player, spot in byPlayer do
		release(player, spot, false)
	end
	for _, spot in spots do
		spot.prompt:Destroy()
	end
	table.clear(spots)
	table.clear(byPlayer)
	table.clear(usedAnchors)
	if placed then
		placed:Destroy()
		placed = nil
	end
	burstSerial = 0
end

-- Pose une cachette sur cet emplacement de la carte (son prefab, une
-- variante au hasard). Vrai si elle est posee.
local function placeAt(anchor: Instance, folder: Folder): boolean
	if not anchor:IsA("BasePart") or usedAnchors[anchor] then
		return false
	end
	local prefab = anchor:GetAttribute("Prefab")
	if typeof(prefab) ~= "string" then
		return false
	end
	local variants = variantsOf(prefab)
	if #variants == 0 then
		return false
	end
	local template = variants[random:NextInteger(1, #variants)]
	local model = template:Clone()
	local socle = model.PrimaryPart
	if socle == nil then
		model:Destroy()
		return false
	end
	local offset = socle.CFrame:ToObjectSpace(model:GetPivot())
	model:PivotTo(anchor.CFrame * offset)
	model.Name = prefab
	model.Parent = folder
	if makeSpot(model, false) then
		usedAnchors[anchor] = true
		return true
	end
	return false
end

-- Une nouvelle partie : pose les cachettes pour `players` joueurs.
function HidingService.setup(players: number)
	HidingService.clear()
	local root = World.root
	local anchors = World.anchors
	if root == nil or anchors == nil then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = W.placedFolder
	folder.Parent = root
	placed = folder

	local pool = anchors:GetChildren()
	-- Melange (Fisher-Yates) : jamais les memes places d'une partie a l'autre.
	for i = #pool, 2, -1 do
		local j = random:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local wanted = math.min(#pool, math.max(H.minSpots, H.spotsPerPlayer * players))
	local count = 0
	for _, anchor in pool do
		if count >= wanted then
			break
		end
		if placeAt(anchor, folder) then
			count += 1
		end
	end
	local solid = World.solidSpots
	if solid then
		for _, model in solid:GetChildren() do
			if model:IsA("Model") then
				makeSpot(model, true)
			end
		end
	end
	-- Les plaques d'egout de la carte (CONCEPT.md : « ressort plus loin :
	-- traverser une rue sans etre vu ») : sous chacune, une cachette etroite.
	local sewers = 0
	for _, part in root:GetDescendants() do
		if part:IsA("BasePart") and part.Name == H.sewer.coverName then
			local model = Instance.new("Model")
			model.Name = H.sewer.name
			local top = part.Position
			local roomsFolder = root:FindFirstChild(H.sewer.roomsFolder)
			if roomsFolder == nil then
				local f = Instance.new("Folder")
				f.Name = H.sewer.roomsFolder
				f.Parent = root
				roomsFolder = f
			end
			local inside = Instance.new("Part")
			inside.Name = W.inside
			inside.Size = Vector3.one * 2
			inside.Anchored = true
			inside.CanCollide = false
			inside.CanQuery = false
			inside.Transparency = 1
			inside.CFrame = buildSewerRoom(part, roomsFolder :: Instance)
			inside.Parent = model
			local exit = Instance.new("Part")
			exit.Name = W.exit
			exit.Size = Vector3.one * 2
			exit.Anchored = true
			exit.CanCollide = false
			exit.CanQuery = false
			exit.Transparency = 1
			exit.CFrame = CFrame.new(top + Vector3.new(0, 1, 0))
			exit.Parent = model
			model.Parent = folder
			-- Solide : elle fait partie de la carte, on ne l'arrache pas.
			if makeSpot(model, true) then
				sewers += 1
			end
		end
	end
	print(
		string.format(
			"[Royale] %d cachettes posées, %d égouts, plus les cachettes solides",
			count,
			sewers
		)
	)
end

-- Un cercle s'annonce (x, z, rayon) : on complete les cachettes a
-- l'interieur jusqu'a `wanted` (toutes sortes comptees, solides et egouts
-- compris). Mesure au banc d'equilibrage du 13 novembre 2026 : posees au
-- hasard sur toute la carte, il en restait 4 dans le cercle du Regard 3
-- pour 12 joueurs, et la partie finissait en chaises musicales. Jamais a
-- moins de `fillAwayFrom` studs d'un joueur : personne ne la voit apparaitre.
function HidingService.fillCircle(x: number, z: number, radius: number, wanted: number): number
	local folder = placed
	local anchors = World.anchors
	if folder == nil or anchors == nil then
		return 0
	end
	local function inside(p: Vector3): boolean
		local dx, dz = p.X - x, p.Z - z
		return dx * dx + dz * dz <= radius * radius
	end
	local have = 0
	for _, spot in spots do
		if not spot.ripping and inside(spot.inside.Position) then
			have += 1
		end
	end
	local watchers: { Vector3 } = {}
	for _, actor in Roster.alive() do
		local root = Roster.rootOf(actor)
		if root then
			table.insert(watchers, root.Position)
		end
	end
	local pool = anchors:GetChildren()
	for i = #pool, 2, -1 do
		local j = random:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local added = 0
	for _, anchor in pool do
		if have + added >= wanted then
			break
		end
		if not anchor:IsA("BasePart") or usedAnchors[anchor] or not inside(anchor.Position) then
			continue
		end
		local seen = false
		for _, at in watchers do
			if (at - anchor.Position).Magnitude < H.fillAwayFrom then
				seen = true
				break
			end
		end
		if not seen and placeAt(anchor, folder) then
			added += 1
		end
	end
	if added > 0 then
		print(
			string.format(
				"[Royale] %d cachettes ajoutées dans le prochain cercle (%d en tout)",
				added,
				have + added
			)
		)
	end
	return added
end

-- Entrer dans la cachette `model` : le chemin de l'invite, et celui des
-- sondes (les touches simulees n'atteignent pas les invites depuis le pont).
function HidingService.tryEnter(player: Roster.Actor, model: Instance): boolean
	for _, spot in spots do
		if spot.model == model then
			enter(player, spot)
			return byPlayer[player] == spot
		end
	end
	return false
end

function HidingService.isHidden(player: Roster.Actor): boolean
	return byPlayer[player] ~= nil
end

-- La plaque choisie pour ressortir d'un egout (le modele envoye par le
-- client) : un autre egout, debout, a portee. Sinon rien (on ressort ici).
local function sewerExit(from: Spot, chosen: Instance?): Spot?
	if chosen == nil or chosen == from.model then
		return nil
	end
	for _, spot in spots do
		if spot.model == chosen and spot.kind == H.sewer.name and not spot.ripping then
			local delta = spot.inside.Position - from.inside.Position
			local d = Vector3.new(delta.X, 0, delta.Z).Magnitude
			return if d <= H.sewer.range then spot else nil
		end
	end
	return nil
end

-- Sortir de sa cachette. D'un egout, par la plaque choisie (`chosen`) : on
-- y rampe dans le noir, toujours cache, puis on ressort. Sans choix (un
-- bot, sortir en force), par la meme plaque. Vu en partie : des bots
-- teleportes d'une plaque a l'autre sans cesse (82 fois en 4 minutes).
function HidingService.leave(player: Roster.Actor, _look: Vector3?, chosen: Instance?)
	local spot = byPlayer[player]
	if spot == nil or traveling[player] then
		return
	end
	local target = if spot.kind == H.sewer.name and player:IsA("Player")
		then sewerExit(spot, chosen)
		else nil
	if target == nil then
		release(player, spot, false)
		return
	end
	local S = H.sewer
	local delta = target.inside.Position - spot.inside.Position
	local seconds = math.clamp(
		Vector3.new(delta.X, 0, delta.Z).Magnitude / S.travelSpeed,
		S.travelMin,
		S.travelMax
	)
	traveling[player] = true
	player:SetAttribute(S.travelAttribute, workspace:GetServerTimeNow() + seconds)
	task.delay(seconds, function()
		traveling[player] = nil
		player:SetAttribute(S.travelAttribute, nil)
		-- Aspire, deloge ou parti entre-temps : le trajet ne mene plus a rien.
		if byPlayer[player] ~= spot then
			return
		end
		release(player, spot, false)
		local root = Roster.rootOf(player)
		if root and not target.ripping then
			root.CFrame = CFrame.new(target.exits[1].Position + Vector3.new(0, 2, 0))
			print(string.format("[Royale] %s ressort d'un égout plus loin", Roster.nameOf(player)))
		end
	end)
end

-- Une nouvelle ouverture de l'Oeil commence.
function HidingService.setBurst(serial: number)
	burstSerial = serial
end

-- Les cachettes que l'Oeil peut arracher maintenant : marquees AVANT cette
-- ouverture, il y a au plus `markBursts` ouvertures. Les occupees d'abord,
-- celles dont l'occupant est flaire (`flagged`) avant tout.
-- `forgetAfter` : le nombre d'ouvertures qu'il garde une marque (la rancune :
-- toujours). `byAge` : le flair, les occupees depuis le plus longtemps d'abord.
function HidingService.ripCandidates(
	flagged: { [Roster.Actor]: boolean },
	solidFalls: boolean,
	forgetAfter: number,
	byAge: boolean
): { Spot }
	local out: { Spot } = {}
	for _, spot in spots do
		local mark = spot.mark
		if
			(solidFalls or not spot.solid)
			and not spot.ripping
			and mark ~= nil
			and mark < burstSerial
			and burstSerial - mark <= forgetAfter
		then
			table.insert(out, spot)
		end
	end
	local function rank(spot: Spot): number
		for _, occupant in spot.occupants do
			if flagged[occupant] then
				return 0
			end
		end
		return if #spot.occupants > 0 then 1 else 2
	end
	table.sort(out, function(a, b)
		local ra, rb = rank(a), rank(b)
		if ra ~= rb then
			return ra < rb
		end
		if byAge and ra < 2 and a.since ~= b.since then
			return a.since < b.since
		end
		return (a.mark :: number) > (b.mark :: number)
	end)
	return out
end

-- Les cachettes libres, pour les bots : le modele et l'endroit d'ou l'on y
-- entre (sa sortie).
function HidingService.freeSpots(): { { model: Model, at: Vector3 } }
	local out = {}
	for _, spot in spots do
		if #spot.occupants < spot.capacity and not spot.ripping and spot.model.Parent then
			local at = if #spot.exits > 0 then spot.exits[1].Position else spot.inside.Position
			table.insert(out, { model = spot.model, at = at })
		end
	end
	return out
end

-- La cachette la plus proche de `at` a moins de `range` (toquer, deloger).
-- Rend aussi le point ou elle se touche.
function HidingService.spotNear(at: Vector3, range: number): (Spot?, Vector3?)
	local best: Spot? = nil
	local bestAt: Vector3? = nil
	local bestD = range
	for _, spot in spots do
		if spot.ripping or spot.model.Parent == nil then
			continue
		end
		for _, part in { spot.inside, table.unpack(spot.exits) } do
			local d = (part.Position - at).Magnitude
			if d <= bestD then
				best, bestAt, bestD = spot, part.Position, d
			end
		end
	end
	return best, bestAt
end

-- Deloge un occupant (la poussee sur un abri, le Rampant) : le premier
-- entre sort, sans le repit de l'arrachage (c'est un joueur qui l'a trouve,
-- pas l'Oeil). Rend qui est sorti.
-- `from` : la ou se tient celui qui pousse (nil : un objet, un Repris). Un
-- conteneur se ferme de l'interieur : on ne le force pas en poussant.
function HidingService.evict(spot: Spot, from: Vector3?): Roster.Actor?
	local occupant = spot.occupants[1]
	if occupant and os.clock() < spot.barricadedUntil then
		return nil
	end
	if occupant and from and H.sealed[spot.kind] then
		return nil
	end
	if occupant then
		release(occupant, spot, false, from)
	end
	return occupant
end

-- Ce que l'Oeil voit de quelqu'un dans cette cachette : rien d'un abri
-- ferme, une partie dans un buisson (« un faisceau qui reste dessus finit
-- par voir », CONCEPT.md).
function HidingService.coverOf(player: Roster.Actor): number
	local spot = byPlayer[player]
	return if spot then H.seenInside[spot.kind] or 0 else 0
end

-- Le bruit d'une cachette quand on y entre ou en sort (le conteneur fait un
-- vacarme), en secondes d'ecoute pour l'Oeil ; 0 sinon.
function HidingService.noiseOf(spot: Spot): number
	return H.noisy[spot.kind] or 0
end

-- Appele quand un participant entre dans une cachette, ou en sort (de
-- quelque facon que ce soit) : les objets poses dessus reagissent.
function HidingService.onEnter(callback: (Roster.Actor, Spot) -> ())
	table.insert(enterCallbacks, callback)
end

function HidingService.onRelease(callback: (Roster.Actor, Spot) -> ())
	table.insert(releaseCallbacks, callback)
end

-- La Craie : l'Oeil vient l'arracher a sa prochaine ouverture.
function HidingService.mark(spot: Spot)
	spot.mark = burstSerial
end

-- Planches, Cadenas : personne ne deloge l'occupant pendant `seconds`.
function HidingService.barricade(spot: Spot, seconds: number)
	spot.barricadedUntil = os.clock() + seconds
end

-- Le Carton piege : une fausse cachette dont le socle se pose a `at`.
-- Elle se comporte comme une vraie (invite, entree) ; ItemService ejecte.
function HidingService.placeFake(prefab: string, at: CFrame): Spot?
	local variants = variantsOf(prefab)
	if #variants == 0 or placed == nil then
		return nil
	end
	local model = variants[random:NextInteger(1, #variants)]:Clone()
	local socle = model.PrimaryPart
	if socle == nil then
		model:Destroy()
		return nil
	end
	-- Comme une vraie : le socle pose sur le sol, a `at`.
	model:PivotTo(at * socle.CFrame:ToObjectSpace(model:GetPivot()))
	model.Name = prefab
	model.Parent = placed
	local spot = makeSpot(model, false)
	if spot then
		spot.fake = true
	else
		model:Destroy()
	end
	return spot
end

-- La cachette ou ce joueur se tient (pour l'arracher quand il est flaire).
function HidingService.spotOf(player: Roster.Actor): Spot?
	return byPlayer[player]
end

-- L'Oeil arrache cette cachette : elle tremble, puis s'envole.
function HidingService.rip(spot: Spot, solidFalls: boolean)
	if spot.ripping or (spot.solid and not solidFalls) then
		return
	end
	Sfx.at("aspiration", spot.inside.Position)
	if spot.solid then
		-- Une cachette solide fait partie de la carte : elle ne s'envole pas,
		-- elle s'effondre (on en est chasse, et on n'y rentre plus).
		spot.ripping = true
		spot.prompt.Enabled = false
		for _, occupant in table.clone(spot.occupants) do
			release(occupant, spot, true)
		end
		print("[Royale] Une cachette solide s'effondre : " .. spot.model.Name)
		return
	end
	spot.ripping = true
	spot.prompt.Enabled = false
	local model = spot.model
	local base = model:GetPivot()
	local shakeUntil = os.clock() + H.ripWarningSeconds
	task.spawn(function()
		while os.clock() < shakeUntil and model.Parent do
			model:PivotTo(
				base
					* CFrame.new(
						random:NextNumber(-H.shakeOffset, H.shakeOffset),
						0,
						random:NextNumber(-H.shakeOffset, H.shakeOffset)
					)
					* CFrame.Angles(0, random:NextNumber(-H.shakeTurn, H.shakeTurn), 0)
			)
			task.wait()
		end
		if model.Parent == nil then
			return
		end
		model:PivotTo(base)
		for _, occupant in table.clone(spot.occupants) do
			release(occupant, spot, true)
		end
		local toward = World.eyeOrigin
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = false
				part.CanCollide = false
				part.CanQuery = false
				local up = (toward - part.Position).Unit
				part.AssemblyLinearVelocity = up * random:NextNumber(H.liftMin, H.liftMax)
					+ Vector3.new(
						random:NextNumber(-H.scatter, H.scatter),
						0,
						random:NextNumber(-H.scatter, H.scatter)
					)
				part.AssemblyAngularVelocity = Vector3.new(
					random:NextNumber(-H.spin, H.spin),
					random:NextNumber(-H.spin, H.spin),
					random:NextNumber(-H.spin, H.spin)
				)
				TweenService:Create(part, TweenInfo.new(H.ripSeconds), { Transparency = 1 }):Play()
			end
		end
		Debris:AddItem(model, H.ripSeconds)
		print("[Royale] L'Œil arrache une cachette : " .. model.Name)
	end)
end

Roster.onBeforeTake(function(player: Roster.Actor)
	local spot = byPlayer[player]
	if spot then
		release(player, spot, false)
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	local spot = byPlayer[player]
	if spot then
		local i = table.find(spot.occupants, player)
		if i then
			table.remove(spot.occupants, i)
		end
		spot.prompt.Enabled = not spot.ripping and #spot.occupants < spot.capacity
		byPlayer[player] = nil
	end
end)

return HidingService
