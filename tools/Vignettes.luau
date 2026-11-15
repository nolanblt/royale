--!strict
--[[
	Les scenes des vignettes de la page du jeu (15 novembre 2026), en mode
	edition : un faisceau rouge, des personnages, des buissons, une voiture
	arrachee. Tout va dans Workspace.VignetteTemp, a detruire apres les photos
	(`Vignettes.clear()`), et l'etalonnage assombri se remet comme il etait.

	Utilisation depuis le pont (comme les autres recettes : copier dans
	src/server/RecetteJetable.luau, en `require` un clone) :
	    Vignettes.scene("A") puis screen_capture avec la camera de CAMERAS.A
	Les images brutes et finales sont dans docs/vignettes ; l'assemblage
	(recadrage 1920 x 1080 et texte) se fait par le script PowerShell decrit
	dans docs/vignettes/LISEZMOI.md (tools/vignettes.ps1).
]]

local Vignettes = {}

local EYE = Vector3.new(0, 571, 0) -- le bout de la pupille (mesure sur le modele)
local RED = Color3.fromRGB(255, 50, 30)
local CORE = Color3.fromRGB(255, 110, 70)

-- Camera et point vise de chaque scene (screen_capture).
Vignettes.CAMERAS = {
	A = { position = { 472, 15, 62 }, lookAt = { 371, 62, 47 } },
	B = { position = { 326, 14, 40 }, lookAt = { 280, 52, 8 } },
	C = { position = { 760, 150, 120 }, lookAt = { 250, 200, 0 } },
	D = { position = { 472, 15, 62 }, lookAt = { 371, 55, 52 } },
	Icone = { position = { 12, 400, 16 }, lookAt = { 0, 575, 0 } },
}

local function folder(): Folder
	local f = workspace:FindFirstChild("VignetteTemp") :: Folder?
	if f == nil then
		local made = Instance.new("Folder")
		made.Name = "VignetteTemp"
		made.Parent = workspace
		return made
	end
	return f
end

local function beam(f: Folder, target: Vector3, width: number)
	for _, layer in { { width, 0.72, RED }, { width * 0.4, 0.4, CORE } } do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Shape = Enum.PartType.Cylinder
		p.Material = Enum.Material.Neon
		p.Color = layer[3] :: Color3
		p.Transparency = layer[2] :: number
		local w = layer[1] :: number
		p.Size = Vector3.new((target - EYE).Magnitude, w, w)
		p.CFrame = CFrame.lookAt((EYE + target) / 2, target) * CFrame.Angles(0, math.rad(90), 0)
		p.Parent = f
	end
	local disc = Instance.new("Part")
	disc.Anchored = true
	disc.CanCollide = false
	disc.Shape = Enum.PartType.Cylinder
	disc.Material = Enum.Material.Neon
	disc.Color = RED
	disc.Transparency = 0.45
	disc.Size = Vector3.new(0.2, width * 1.6, width * 1.6)
	disc.CFrame = CFrame.new(target + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	disc.Parent = f
end

local function rig(f: Folder, name: string, torso: Color3, at: Vector3, lookAt: Vector3): Model
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = Color3.fromRGB(234, 184, 146)
	desc.TorsoColor = torso
	desc.LeftArmColor = desc.HeadColor
	desc.RightArmColor = desc.HeadColor
	desc.LeftLegColor = Color3.fromRGB(30, 30, 40)
	desc.RightLegColor = desc.LeftLegColor
	local r = game:GetService("Players")
		:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	r.Name = name
	r.Parent = f
	r:PivotTo(CFrame.lookAt(at, Vector3.new(lookAt.X, at.Y, lookAt.Z)))
	for _, d in r:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	return r
end

-- Un buisson, et quelqu'un dedans dont la tete depasse (`sink` : de combien
-- il s'enfonce sous le haut du buisson).
local function hider(
	f: Folder,
	name: string,
	torso: Color3,
	at: Vector3,
	face: Vector3,
	sink: number
)
	local models = game:GetService("ServerStorage"):WaitForChild("RoyaleModeles")
	local bush = (models:WaitForChild("BuissonReel") :: Model):Clone()
	bush.Name = "Buisson" .. name
	bush.Parent = f
	bush:PivotTo(CFrame.new(at))
	local _, size = bush:GetBoundingBox()
	local y = at.Y + size.Y - sink
	rig(f, name, torso, Vector3.new(at.X + 1, y, at.Z), Vector3.new(face.X, y, face.Z))
end

local function darken(f: Folder)
	local cc =
		game:GetService("Lighting"):FindFirstChild("RoyaleEtalonnage") :: ColorCorrectionEffect?
	if cc == nil or f:GetAttribute("ccB") ~= nil then
		return
	end
	f:SetAttribute("ccB", cc.Brightness)
	f:SetAttribute("ccC", cc.Contrast)
	f:SetAttribute("ccS", cc.Saturation)
	cc.Brightness -= 0.08
	cc.Contrast += 0.15
	cc.Saturation += 0.1
end

function Vignettes.clear()
	local f = workspace:FindFirstChild("VignetteTemp")
	if f == nil then
		return
	end
	local cc =
		game:GetService("Lighting"):FindFirstChild("RoyaleEtalonnage") :: ColorCorrectionEffect?
	if cc and f:GetAttribute("ccB") ~= nil then
		cc.Brightness = f:GetAttribute("ccB") :: number
		cc.Contrast = f:GetAttribute("ccC") :: number
		cc.Saturation = f:GetAttribute("ccS") :: number
	end
	f:Destroy()
end

function Vignettes.scene(name: string)
	local f = folder()
	for _, c in f:GetChildren() do
		c:Destroy()
	end
	darken(f)
	local blue, pink, yellow, green =
		Color3.fromRGB(40, 90, 200),
		Color3.fromRGB(200, 60, 160),
		Color3.fromRGB(230, 170, 30),
		Color3.fromRGB(40, 160, 90)
	if name == "A" then
		-- « Hide from the Eye » : un joueur aspire dans le faisceau, un autre
		-- cache dans un buisson au premier plan.
		local T = Vector3.new(432, 12, 55)
		beam(f, T, 12)
		local pris = rig(f, "Pris", blue, T + Vector3.new(0, 2.6, 0), Vector3.new(470, 0, 60))
		pris:PivotTo(
			pris:GetPivot() * CFrame.new(0, 14, 0) * CFrame.Angles(math.rad(-25), 0, math.rad(15))
		)
		hider(f, "Cache", pink, Vector3.new(458, 12, 69), Vector3.new(472, 0, 62), 9.4)
	elseif name == "B" then
		-- « It rips away your hiding spot » : une voiture arrachee vers l'Oeil.
		local G = Vector3.new(300, 12, 20)
		local caches = game:GetService("ServerStorage"):WaitForChild("RoyaleCachettes")
		local car = (caches:WaitForChild("Voiture") :: Model):Clone()
		car.Parent = f
		for _, d in car:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			elseif d:IsA("ProximityPrompt") or d:IsA("Script") then
				d:Destroy()
			end
		end
		car:PivotTo(
			CFrame.new(G + Vector3.new(-2, 16, 0))
				* CFrame.Angles(math.rad(30), math.rad(60), math.rad(-20))
		)
		local rnd = Random.new(7)
		for _ = 1, 40 do
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.CastShadow = false
			p.Material = Enum.Material.Metal
			p.Size = Vector3.new(
				rnd:NextNumber(0.4, 2.2),
				rnd:NextNumber(0.2, 0.8),
				rnd:NextNumber(0.4, 2.2)
			)
			p.Color = Color3.fromRGB(60, 60, 70):Lerp(Color3.fromRGB(120, 40, 30), rnd:NextNumber())
			local h = rnd:NextNumber(3, 60)
			p.CFrame = CFrame.new(
				G + Vector3.new(rnd:NextNumber(-10, 10) - h * 0.15, h, rnd:NextNumber(-10, 10))
			) * CFrame.Angles(rnd:NextNumber(0, 6), rnd:NextNumber(0, 6), rnd:NextNumber(0, 6))
			p.Parent = f
		end
		beam(f, G, 22)
		rig(f, "Decouvert", yellow, Vector3.new(298, 14.6, 22), Vector3.new(326, 0, 38))
		rig(f, "Fuit", green, Vector3.new(313, 14.6, 31), Vector3.new(296, 0, 18))
	elseif name == "C" then
		-- « Don't get seen » : quatre faisceaux sur la Banlieue, vue d'en haut.
		for _, T in
			{
				Vector3.new(420, 12, 60),
				Vector3.new(300, 12, -100),
				Vector3.new(520, 12, -140),
				Vector3.new(380, 12, 200),
			}
		do
			beam(f, T, 16)
		end
	elseif name == "D" then
		-- « Hide with your friends » : trois joueurs dans trois buissons.
		local cam = Vector3.new(472, 15, 62)
		hider(f, "Equipe1", blue, Vector3.new(452, 12, 72), cam, 9.4)
		hider(f, "Equipe2", pink, Vector3.new(449, 12, 60), cam, 9.4)
		hider(f, "Equipe3", yellow, Vector3.new(452, 12, 49), cam, 9.4)
		beam(f, Vector3.new(418, 12, 48), 12)
	end
	-- « Icone » : rien a poser, l'Oeil seul.
end

return Vignettes
