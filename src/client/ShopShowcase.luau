--!strict
--[[
	ShopShowcase — la vitrine de la boutique (choisi avec Josh le 14 novembre
	2026). Boutique ouverte au salon, la camera se tourne vers le socle de
	l'echoppe, et l'objet choisi s'y montre en vrai : la comete qui file en
	rond, la trainee qui court, le cocon, l'aspiration qui monte, la batte,
	l'emote jouee par ton personnage, le titre.

	Tout est construit ici, chez toi seul (CosmeticFx, partage) : personne
	d'autre ne voit ta vitrine.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Royale = ReplicatedStorage:WaitForChild("Royale")
local Config = require(Royale:WaitForChild("Config"))
local CosmeticFx = require(Royale:WaitForChild("Effets"):WaitForChild("CosmeticFx"))

local ShopView = require(script.Parent.ShopView)

local ShopShowcase = {}

local CO = Config.cosmetics
local S = Config.lobby.shopStall
local SC = Config.lobby.showcase

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function ghost(size: Vector3): Part
	local p = Instance.new("Part")
	p.Name = "RoyaleVitrine"
	p.Size = size
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

function ShopShowcase.start()
	local player = Players.LocalPlayer
	local salon = workspace:WaitForChild(Config.lobby.folder)
	local pedestal = salon:WaitForChild("SocleVitrine", 60)
	if pedestal == nil or not pedestal:IsA("BasePart") then
		warn("[Royale] Vitrine : pas de socle au salon")
		return
	end
	local top = pedestal.Position + Vector3.new(0, pedestal.Size.X / 2 + S.previewHeight, 0)
	-- La camera : du cote de la place, un peu au-dessus, et decalee pour que
	-- l'objet tombe dans la moitie droite (le panneau est a gauche).
	local origin = Vector3.new(Config.lobby.origin[1], top.Y, Config.lobby.origin[3])
	local toward = (origin - top).Unit
	local eye = top + toward * S.cameraDistance + Vector3.new(0, S.cameraHeight, 0)
	local right = toward:Cross(Vector3.yAxis).Unit
	local shot = CFrame.lookAt(eye, top + right * S.cameraDistance * SC.shift)

	local folder: Folder? = nil
	local stepper: RBXScriptConnection? = nil
	local shown: string? = nil
	local isOpen = false

	local function clear()
		if stepper then
			stepper:Disconnect()
			stepper = nil
		end
		if folder then
			folder:Destroy()
			folder = nil
		end
	end

	-- Ton personnage, en copie locale, pour l'emote et la batte.
	local function mannequin(f: Folder): Model?
		local character = player.Character
		if character == nil then
			return nil
		end
		character.Archivable = true
		local copy = character:Clone()
		character.Archivable = false
		if copy == nil then
			return nil
		end
		for _, d in copy:GetDescendants() do
			if d:IsA("Script") or d:IsA("LocalScript") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
			end
		end
		copy.Name = "RoyaleMannequin"
		copy.Parent = f
		local root = copy:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root.Anchored = true
		end
		local facing = CFrame.lookAt(pedestal.Position, pedestal.Position + toward)
		copy:PivotTo(facing + Vector3.new(0, pedestal.Size.X / 2 + SC.standHeight, 0))
		return copy
	end

	local function show(id: string?)
		clear()
		shown = id
		if id == nil then
			return
		end
		local def = CO.items[id]
		if def == nil then
			return
		end
		local f = Instance.new("Folder")
		f.Name = "RoyaleVitrine"
		f.Parent = workspace
		folder = f
		local t0 = os.clock()
		if def.slot == "comet" then
			-- Elle file en rond au-dessus du socle.
			local p = ghost(Vector3.one * 2)
			p.Parent = f
			CosmeticFx.comet(p, def)
			stepper = RunService.RenderStepped:Connect(function()
				local a = (os.clock() - t0) * SC.cometSpin
				local at = top
					+ Vector3.new(
						math.cos(a) * SC.cometRadius,
						math.sin(a * 2) * 0.8,
						math.sin(a) * SC.cometRadius
					)
				local ahead = top
					+ Vector3.new(
						math.cos(a + 0.1) * SC.cometRadius,
						0,
						math.sin(a + 0.1) * SC.cometRadius
					)
				p.CFrame = CFrame.lookAt(at, ahead)
			end)
		elseif def.slot == "trail" then
			-- Elle court en rond au ras du socle, et laisse ses traces.
			local p = ghost(Vector3.new(2, 2, 1))
			p.Parent = f
			local _, _, step = CosmeticFx.trail(p, def)
			local last = 0
			stepper = RunService.RenderStepped:Connect(function()
				local t = os.clock() - t0
				local a = t * SC.trailSpin
				local y = top.Y - S.previewHeight + 1.2
				local at = Vector3.new(
					top.X + math.cos(a) * SC.trailRadius,
					y,
					top.Z + math.sin(a) * SC.trailRadius
				)
				local ahead = Vector3.new(
					top.X + math.cos(a + 0.1) * SC.trailRadius,
					y,
					top.Z + math.sin(a + 0.1) * SC.trailRadius
				)
				p.CFrame = CFrame.lookAt(at, ahead)
				if step and t - last > CO.trail.checkSeconds then
					last = t
					step(true, p)
				end
			end)
		elseif def.slot == "cocoon" then
			local CC = Config.squads.cocoon
			local shell = Instance.new("Part")
			shell.Name = "RoyaleVitrine"
			shell.Shape = Enum.PartType.Ball
			shell.Size = Vector3.one * CC.size[1]
			shell.Anchored = true
			shell.CanCollide = false
			shell.CanQuery = false
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Scale = Vector3.new(1, CC.size[2] / CC.size[1], 1)
			mesh.Parent = shell
			shell.CFrame =
				CFrame.new(top.X, pedestal.Position.Y + pedestal.Size.X / 2 + CC.size[2] / 2, top.Z)
			local light = Instance.new("PointLight")
			light.Range = CC.lightRange
			light.Brightness = CC.lightBrightness
			light.Parent = shell
			CosmeticFx.cocoon(shell, def)
			shell.Parent = f
		elseif def.slot == "capture" then
			-- Elle monte du socle vers le ciel, en boucle.
			local p = ghost(Vector3.one * 2)
			p.Parent = f
			local stop: (() -> ())? = nil
			local cycle = -1
			stepper = RunService.RenderStepped:Connect(function()
				local t = os.clock() - t0
				local k = (t % SC.captureSeconds) / SC.captureSeconds
				local n = math.floor(t / SC.captureSeconds)
				if n ~= cycle then
					cycle = n
					if stop then
						stop()
					end
					stop = CosmeticFx.capture(p, def)
				end
				p.CFrame =
					CFrame.new(top + Vector3.new(0, -S.previewHeight + 1 + k * SC.captureRise, 0))
			end)
		elseif def.slot == "bat" then
			-- Ton personnage la tient.
			local copy = mannequin(f)
			local hand = copy and copy:FindFirstChild("RightHand")
			if hand and hand:IsA("BasePart") then
				CosmeticFx.bat(hand, def).Parent = copy
			end
		elseif def.slot == "emote" then
			-- Ton personnage la joue, en boucle.
			local copy = mannequin(f)
			local humanoid = copy and copy:FindFirstChildOfClass("Humanoid")
			local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
			if animator then
				local animation = Instance.new("Animation")
				animation.AnimationId = "rbxassetid://" .. def.anim
				local ok, track = pcall(function()
					return animator:LoadAnimation(animation)
				end)
				if ok then
					(track :: AnimationTrack).Looped = true
					(track :: AnimationTrack):Play()
				end
			end
		elseif def.slot == "title" then
			-- Le titre, en grand, a la couleur de sa rarete.
			local anchor = ghost(Vector3.one)
			anchor.CFrame = CFrame.new(top)
			anchor.Parent = f
			local board = Instance.new("BillboardGui")
			board.Size = UDim2.fromScale(SC.titleWidth, SC.titleHeight)
			board.LightInfluence = 0
			board.AlwaysOnTop = true
			board.Adornee = anchor
			board.Parent = anchor
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Font = (Enum.Font :: any)[Config.view.font]
			label.TextScaled = true
			local rarity = Config.rarities[def.rarity]
			label.TextColor3 = if rarity then rgb(rarity.color) else Color3.new(1, 1, 1)
			label.TextStrokeTransparency = 0.3
			label.Text = "« " .. def.title .. " »"
			label.Parent = board
		end
	end

	local camera = workspace.CurrentCamera
	ShopView.onPreview(function(id: string?, open: boolean)
		if open ~= isOpen then
			isOpen = open
			if open then
				camera.CameraType = Enum.CameraType.Scriptable
				camera.CFrame = shot
			else
				camera.CameraType = Enum.CameraType.Custom
				show(nil)
				return
			end
		end
		if open and id ~= shown then
			show(id)
		end
	end)
	-- Tant que la vitrine est ouverte, la camera n'en bouge pas.
	RunService.RenderStepped:Connect(function()
		if isOpen then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = shot
		end
	end)
end

return ShopShowcase
