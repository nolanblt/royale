--!strict
--[[
	ItemModels — construit le modele d'un objet de la partie (ItemShapes) :
	en main (le serveur le soude a la main droite, tous le voient), en vol
	(le client le fait tourner sur son arc), et pose (le mannequin).

	Chaque modele a une part invisible « Prise » a l'origine (le poing) ;
	tout y est soude.
]]

local ItemModels = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function vec(t: { number }?): Vector3
	return if t then Vector3.new(t[1], t[2], t[3]) else Vector3.zero
end

-- Le modele de `id` (nil si l'objet n'a pas de dessin), a l'echelle
-- `scale`, pose a `at` (sa prise).
function ItemModels.build(shapes: any, id: string, at: CFrame, scale: number?): Model?
	local pieces = shapes[id]
	if pieces == nil then
		return nil
	end
	local k = scale or 1
	local model = Instance.new("Model")
	model.Name = "Objet_" .. id
	local grip = Instance.new("Part")
	grip.Name = "Prise"
	grip.Size = Vector3.one * 0.2
	grip.Transparency = 1
	grip.CanCollide = false
	grip.CanQuery = false
	grip.CanTouch = false
	grip.Massless = true
	grip.CFrame = at
	grip.Parent = model
	model.PrimaryPart = grip
	for i, piece in pieces do
		local p = Instance.new("Part")
		p.Name = "Piece" .. i
		local size = vec(piece.z) * k
		local rot = vec(piece.r)
		local local_ = CFrame.new(vec(piece.p) * k)
			* CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
		if piece.s == "Cyl" then
			-- Couche le long de Y : la longueur de Roblox est sur X.
			p.Shape = Enum.PartType.Cylinder
			p.Size = Vector3.new(size.Y, size.X, size.Z)
			local_ *= CFrame.Angles(0, 0, math.pi / 2)
		elseif piece.s == "Ball" then
			p.Shape = Enum.PartType.Ball
			p.Size = size
		elseif piece.s == "Wedge" then
			p.Shape = Enum.PartType.Wedge
			p.Size = size
		elseif piece.s == "Egg" then
			p.Size = size
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
		else
			p.Size = size
		end
		p.CFrame = at * local_
		p.Color = rgb(piece.c)
		p.Material = (Enum.Material :: any)[piece.m or "SmoothPlastic"]
		p.Transparency = piece.t or 0
		p.Reflectance = piece.f or 0
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = false
		if piece.l then
			local light = Instance.new("PointLight")
			light.Color = p.Color
			light.Range = piece.l[1] * k
			light.Brightness = piece.l[2]
			light.Shadows = false
			light.Parent = p
		end
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = grip
		weld.Part1 = p
		weld.Parent = p
	end
	return model
end

-- En main : soude a la prise de la main droite, penche de `tilt` degres
-- vers l'avant (pret a servir).
function ItemModels.hold(shapes: any, id: string, hand: BasePart, tilt: number): Model?
	local attach = hand:FindFirstChild("RightGripAttachment")
	local at = hand.CFrame
		* CFrame.new(if attach and attach:IsA("Attachment") then attach.Position else Vector3.zero)
		* CFrame.Angles(math.rad(tilt), 0, 0)
	local model = ItemModels.build(shapes, id, at)
	if model == nil then
		return nil
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = model.PrimaryPart
	weld.Parent = model.PrimaryPart
	return model
end

return ItemModels
