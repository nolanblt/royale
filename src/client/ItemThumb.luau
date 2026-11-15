--!strict
--[[
	ItemThumb — l'image d'un objet pour les cartes de la boutique et des
	recompenses quotidiennes (choisi avec Josh le 15 novembre 2026 : « une
	vraie boutique avec les photos d'item »).

	Une petite scene 3D (ViewportFrame) ou l'objet est construit avec de
	vraies pieces. Roblox n'y dessine pas les particules : chaque emplacement
	a donc une image faite de pieces lumineuses (le coeur et la queue d'une
	comete, le ruban d'une trainee, la vraie coque d'un cocon, la vraie
	batte...). Un titre est un texte ; des credits, une piece ; des fragments,
	un cristal.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Royale = ReplicatedStorage:WaitForChild("Royale")
local Config = require(Royale:WaitForChild("Config"))
local CosmeticFx = require(Royale:WaitForChild("Effets"):WaitForChild("CosmeticFx"))

local ItemThumb = {}

local CO = Config.cosmetics
local T = Config.shop.thumb

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function ball(
	parent: Instance,
	at: Vector3,
	size: number,
	color: Color3,
	neon: boolean,
	transparency: number?
): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * size
	p.CFrame = CFrame.new(at)
	p.Color = color
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.Anchored = true
	p.Parent = parent
	return p
end

local function block(
	parent: Instance,
	cf: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.Parent = parent
	return p
end

-- Une silhouette simple (aspiration, emote), dans une pose.
local function figure(parent: Instance, color: Color3, pose: number)
	local m = Enum.Material.SmoothPlastic
	block(parent, CFrame.new(0, 0, 0), Vector3.new(1.6, 1.8, 0.8), color, m)
	ball(parent, Vector3.new(0, 1.55, 0), 1.2, color, false)
	-- Les bras : levés, l'un leve, en croix... selon la pose.
	local arms = ({ { 150, 150 }, { 160, 20 }, { 90, 90 }, { 30, 150 } })[pose % 4 + 1]
	for i, side in { -1, 1 } do
		local angle = math.rad(arms[i]) * side
		block(
			parent,
			CFrame.new(side * 1, 0.6, 0) * CFrame.Angles(0, 0, angle) * CFrame.new(0, -0.8, 0),
			Vector3.new(0.5, 1.6, 0.5),
			color,
			m
		)
	end
	for _, side in { -1, 1 } do
		block(parent, CFrame.new(side * 0.4, -1.8, 0), Vector3.new(0.6, 1.8, 0.6), color, m)
	end
end

-- Le cadrage : la camera regarde l'objet de face, a la bonne distance.
local function frame(view: ViewportFrame, world: Instance, tilt: number?)
	local cf, size = (world :: any):GetBoundingBox()
	local radius = size.Magnitude / 2
	local camera = Instance.new("Camera")
	camera.FieldOfView = T.fov
	local distance = radius / math.tan(math.rad(T.fov / 2)) * T.margin
	local from = cf.Position + Vector3.new(0, distance * (tilt or 0.15), distance)
	camera.CFrame = CFrame.lookAt(from, cf.Position)
	camera.Parent = view
	view.CurrentCamera = camera
end

-- Une scene neuve dans `view`, avec un monde ou les soudures tiennent.
local function scene(view: ViewportFrame): WorldModel
	local world = Instance.new("WorldModel")
	world.Parent = view
	return world
end

local builders: { [string]: (world: WorldModel, def: any) -> number? } = {
	comet = function(world, def)
		-- Le coeur, puis une queue de boules de plus en plus petites, de a vers b.
		local root = ball(world, Vector3.zero, 2, rgb(def.a), true)
		root.Transparency = 1
		CosmeticFx.comet(root, def)
		for i = 1, 7 do
			local k = i / 7
			ball(
				world,
				Vector3.new(-i * 1.1, -i * 0.55, 0),
				2.6 * (1 - k * 0.8),
				rgb(def.a):Lerp(rgb(def.b), k),
				true,
				0.15 + k * 0.6
			)
		end
		return 0.1
	end,
	trail = function(world, def)
		-- Un ruban qui ondule, de a vers b.
		for i = 0, 11 do
			local k = i / 11
			local x = (k - 0.5) * 10
			block(
				world,
				CFrame.new(x, math.sin(k * math.pi * 1.5) * 1.6, 0)
					* CFrame.Angles(0, 0, math.cos(k * math.pi * 1.5) * 0.7),
				Vector3.new(1, 1.8 * (1 - k * 0.5), 0.2),
				rgb(def.a):Lerp(rgb(def.b), k),
				Enum.Material.Neon
			).Transparency = k
				* 0.5
		end
		return 0.05
	end,
	cocoon = function(world, def)
		local CC = Config.squads.cocoon
		local shell = ball(world, Vector3.zero, CC.size[1], rgb(def.a), false)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Scale = Vector3.new(1, CC.size[2] / CC.size[1], 1)
		mesh.Parent = shell
		local light = Instance.new("PointLight")
		light.Parent = shell
		CosmeticFx.cocoon(shell, def)
		-- Les particules ne s'affichent pas ici : une coque translucide, un
		-- coeur qui brille, et trois anneaux de veines lumineuses (de a vers b).
		shell.Transparency = 0.3
		local h = CC.size[2]
		ball(world, Vector3.zero, CC.size[1] * 0.55, rgb(def.b), true, 0.2).Size =
			Vector3.new(CC.size[1] * 0.5, h * 0.6, CC.size[1] * 0.5)
		for ring = 1, 3 do
			local tilt = CFrame.Angles(0, ring * 1.1, math.rad(-25 + ring * 20))
			local y = (ring - 2) * h * 0.25
			local r = CC.size[1] / 2 * math.sqrt(math.max(0.2, 1 - (2 * y / h) ^ 2)) * 1.02
			for k = 1, 16 do
				local a = k / 16 * math.pi * 2
				block(
					world,
					CFrame.new(0, y, 0)
						* tilt
						* CFrame.new(math.cos(a) * r, 0, math.sin(a) * r)
						* CFrame.Angles(0, -a, 0),
					Vector3.new(0.12, 0.12, r * math.pi / 8 * 1.1),
					rgb(def.a):Lerp(rgb(def.b), ring / 3),
					Enum.Material.Neon
				)
			end
		end
		return 0.15
	end,
	capture = function(world, def)
		-- Une silhouette dans une spirale qui monte, de a vers b.
		figure(world, Color3.fromRGB(70, 60, 58), 0)
		for i = 0, 13 do
			local k = i / 13
			local a = k * math.pi * 4
			ball(
				world,
				Vector3.new(math.cos(a) * 2.2, -2.5 + k * 6, math.sin(a) * 2.2),
				0.7 - k * 0.3,
				rgb(def.a):Lerp(rgb(def.b), k),
				true
			)
		end
		return 0.15
	end,
	bat = function(world, def)
		-- La vraie batte, en biais.
		local hand = block(
			world,
			CFrame.Angles(0, 0, math.rad(-40)),
			Vector3.one * 0.4,
			Color3.new(),
			Enum.Material.SmoothPlastic
		)
		hand.Transparency = 1
		local bat = CosmeticFx.bat(hand, def)
		bat.Parent = world
		return 0.1
	end,
	emote = function(world, def)
		-- Une silhouette dans une pose (differente d'une emote a l'autre).
		local pose = def.anim % 4
		figure(world, rgb(Config.lobby.colors.lantern), pose)
		return 0.1
	end,
}

-- Remplit `view` avec l'image de l'objet `id` (vide si l'objet n'existe pas).
function ItemThumb.item(view: ViewportFrame, id: string)
	view:ClearAllChildren()
	local def = CO.items[id]
	if def == nil then
		return
	end
	view.BackgroundTransparency = 1
	view.Ambient = rgb(T.ambient)
	view.LightColor = rgb(T.light)
	view.LightDirection = Vector3.new(-1, -1, -1)
	if def.slot == "title" then
		local rarity = Config.rarities[def.rarity]
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(0.9, 0.9)
		label.Position = UDim2.fromScale(0.05, 0.05)
		label.Font = (Enum.Font :: any)[Config.view.font]
		label.TextScaled = true
		label.TextWrapped = true
		label.TextColor3 = if rarity then rgb(rarity.color) else Color3.new(1, 1, 1)
		label.Text = "« " .. def.title .. " »"
		label.Parent = view
		return
	end
	local build = builders[def.slot]
	if build == nil then
		return
	end
	local world = scene(view)
	local tilt = build(world, def)
	frame(view, world, tilt)
end

-- Une piece (credits) ou un cristal (fragments), avec le nombre.
function ItemThumb.currency(view: ViewportFrame, kind: string)
	view:ClearAllChildren()
	view.BackgroundTransparency = 1
	view.Ambient = rgb(T.ambient)
	view.LightColor = rgb(T.light)
	local world = scene(view)
	if kind == "credits" then
		-- Une pile de pieces a plat, et une piece debout devant, de face (le
		-- cylindre de Roblox a son axe sur X).
		local gold = rgb(Config.shop.ui.coin)
		local edge = rgb(Config.shop.ui.coinEdge)
		local function coin(cf: CFrame, color: Color3)
			local c = block(world, cf, Vector3.new(0.45, 3, 3), color, Enum.Material.SmoothPlastic)
			c.Shape = Enum.PartType.Cylinder
			local face = block(world, cf, Vector3.new(0.5, 2, 2), edge, Enum.Material.SmoothPlastic)
			face.Shape = Enum.PartType.Cylinder
		end
		for i = 0, 3 do
			coin(
				CFrame.new(-1 + (i % 2) * 0.15, i * 0.47, 0) * CFrame.Angles(0, 0, math.pi / 2),
				gold
			)
		end
		coin(CFrame.new(1.4, 0.9, 1.2) * CFrame.Angles(0, math.rad(70), math.rad(-8)), gold)
	else
		-- Un bouquet de cristaux : un fut et une pointe en losange chacun.
		local color = rgb(Config.shop.ui.fragment)
		for i, shard in
			{ { 0, 3.2, 0 }, { -1.1, 2.2, 0.35 }, { 1.05, 2.5, -0.25 }, { 0.3, 1.6, 0.9 } }
		do
			local x, h, tilt = shard[1], shard[2], shard[3]
			local base = CFrame.new(x, 0, 0) * CFrame.Angles(0, math.rad(45 + i * 20), tilt)
			local body = block(
				world,
				base * CFrame.new(0, h / 2, 0),
				Vector3.new(0.8, h, 0.8),
				color,
				Enum.Material.Glass
			)
			body.Transparency = 0.1
			local tip = block(
				world,
				base * CFrame.new(0, h, 0) * CFrame.Angles(math.rad(45), 0, math.rad(35)),
				Vector3.one * 0.62,
				color:Lerp(Color3.new(1, 1, 1), 0.3),
				Enum.Material.Glass
			)
			tip.Transparency = 0.1
			local core = block(
				world,
				base * CFrame.new(0, h / 2, 0),
				Vector3.new(0.3, h * 0.8, 0.3),
				color:Lerp(Color3.new(1, 1, 1), 0.5),
				Enum.Material.Neon
			)
			core.Transparency = 0.3
		end
		block(
			world,
			CFrame.new(0, -0.2, 0),
			Vector3.new(3.4, 0.5, 2.2),
			Color3.fromRGB(60, 52, 50),
			Enum.Material.Slate
		)
	end
	-- Un peu d'en haut : la pile de pieces se voit (de cote, des barres).
	frame(view, world, 0.55)
end

-- Fait tourner doucement l'objet d'une image (une seule boucle pour toutes) ;
-- `on` a false l'arrete (la carte n'est plus choisie).
local spinning: { [ViewportFrame]: boolean } = {}
function ItemThumb.spin(view: ViewportFrame, on: boolean?)
	spinning[view] = if on == false then nil else true
end
RunService.RenderStepped:Connect(function(dt: number)
	for view in spinning do
		if view.Parent == nil then
			spinning[view] = nil
			continue
		end
		local camera = view.CurrentCamera
		if camera then
			local world = view:FindFirstChildOfClass("WorldModel")
			if world then
				local cf = (world :: any):GetBoundingBox()
				local offset = camera.CFrame.Position - cf.Position
				camera.CFrame = CFrame.lookAt(
					cf.Position + CFrame.Angles(0, dt * T.spin, 0) * offset,
					cf.Position
				)
			end
		end
	end
end)

return ItemThumb
