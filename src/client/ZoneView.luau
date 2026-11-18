--!strict
--[[
	ZoneView — le cercle : un rideau d'energie rouge la ou il est, une ligne
	blanche au sol la ou il va (attributs `Cercle` et `CercleSuivant` de
	Workspace, des Vector3 x, rayon, z).

	Des panneaux plutot qu'un cylindre : un cylindre ne se voit pas de
	l'interieur, et on est presque toujours a l'interieur. Tous les panneaux
	montent au meme sommet (avant, chacun partait du sol sous lui : le haut
	faisait des marches, des « piquets ») ; les lignes au sol sont couchees
	d'un point du sol au suivant, elles suivent les collines sans marches.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Royale = ReplicatedStorage:WaitForChild("Royale")
local Config = require(Royale:WaitForChild("Config"))

local ZoneView = {}

local V = Config.view

-- Les couleurs de Config sont des { r, v, b } (Config se charge sans Roblox).
local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end
local Z = Config.zone

local function ring(
	parent: Instance,
	color: Color3,
	transparency: number,
	material: Enum.Material
): { Part }
	local parts: { Part } = {}
	for _ = 1, V.wallSegments do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = material
		p.Color = color
		p.Transparency = transparency
		p.Parent = parent
		table.insert(parts, p)
	end
	return parts
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- Le sol sous un point, pour que les lignes suivent les collines.
local function groundAt(x: number, z: number): number
	local hit = workspace:Raycast(Vector3.new(x, 500, z), Vector3.new(0, -800, 0), rayParams)
	return if hit then hit.Position.Y else 0
end

-- Les points du cercle et le sol sous chacun (un de plus que de panneaux :
-- le dernier rejoint le premier).
local function samples(circle: Vector3, count: number): ({ Vector3 }, number)
	local points: { Vector3 } = {}
	local highest = -math.huge
	for i = 0, count do
		local a = i / count * math.pi * 2
		local x = circle.X + math.cos(a) * circle.Y
		local z = circle.Z + math.sin(a) * circle.Y
		local y = groundAt(x, z)
		highest = math.max(highest, y)
		table.insert(points, Vector3.new(x, y, z))
	end
	return points, highest
end

local function hide(parts: { Part })
	for _, p in parts do
		p.Transparency = 1
	end
end

-- Le rideau : du sous-sol au meme sommet pour tous.
local function placeWall(parts: { Part }, points: { Vector3 }, top: number)
	for i, p in parts do
		local p0, p1 = points[i], points[i + 1]
		local base = math.min(p0.Y, p1.Y) - V.wallSink
		local mid = Vector3.new((p0.X + p1.X) / 2, (base + top) / 2, (p0.Z + p1.Z) / 2)
		local along = Vector3.new(p1.X - p0.X, 0, p1.Z - p0.Z)
		p.Size = Vector3.new(0.4, top - base, along.Magnitude + 0.2)
		p.CFrame = CFrame.lookAt(mid, mid + along) * CFrame.Angles(0, math.pi / 2, 0)
		p.Transparency = V.wallTransparency
	end
end

-- Une ligne couchee au sol, d'un point du sol au suivant.
local function placeLine(parts: { Part }, points: { Vector3 }, width: number, transparency: number)
	local lift = Vector3.new(0, V.lineLift, 0)
	for i, p in parts do
		local p0, p1 = points[i] + lift, points[i + 1] + lift
		local mid = (p0 + p1) / 2
		p.Size = Vector3.new(width, 0.2, (p1 - p0).Magnitude + 0.3)
		p.CFrame = CFrame.lookAt(mid, p1)
		p.Transparency = transparency
	end
end

function ZoneView.start()
	local folder = Instance.new("Folder")
	folder.Name = "RoyaleCercleVu"
	folder.Parent = workspace
	local wall =
		ring(folder, rgb(V.wallColor), V.wallTransparency, (Enum.Material :: any)[V.wallMaterial])
	local wallBase = ring(folder, rgb(V.wallBaseColor), V.wallBaseTransparency, Enum.Material.Neon)
	local nextRing = ring(folder, rgb(V.nextColor), V.nextTransparency, Enum.Material.Neon)
	rayParams.FilterDescendantsInstances = { folder }

	local function refresh()
		local current = workspace:GetAttribute(Z.attribute)
		local nextCircle = workspace:GetAttribute(Z.nextAttribute)
		local c = if typeof(current) == "Vector3" then current else nil
		local n = if typeof(nextCircle) == "Vector3" then nextCircle else nil
		-- Avant le premier cercle (toute la carte), pas de mur : il serait en mer.
		if c and c.Y >= Z.startRadius then
			c = nil
		end
		if c then
			local points, highest = samples(c, V.wallSegments)
			placeWall(wall, points, highest + V.wallHeight)
			placeLine(wallBase, points, V.wallBaseWidth, V.wallBaseTransparency)
		else
			hide(wall)
			hide(wallBase)
		end
		if n then
			local points = samples(n, V.wallSegments)
			placeLine(nextRing, points, V.nextWidth, V.nextTransparency)
		else
			hide(nextRing)
		end
	end
	workspace:GetAttributeChangedSignal(Z.attribute):Connect(refresh)
	workspace:GetAttributeChangedSignal(Z.nextAttribute):Connect(refresh)
	refresh()
end

return ZoneView
