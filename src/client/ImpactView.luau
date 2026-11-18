--!strict
--[[
	ImpactView — un coup qui porte se voit (Josh, le 16 novembre 2026 :
	« quand on tape quelqu'un il ne se passe rien »).

	Le serveur annonce chaque coup qui porte (cible, attaquant, K.O.) :
	- tous voient la cible clignoter et des eclats jaillir ;
	- l'attaquant voit une marque au centre de l'ecran ;
	- la cible voit un voile rouge ;
	- les deux sentent la camera trembler.
	Le recul de la cible est une animation jouee par le serveur
	(ActionAnim, « flinch »).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Royale = ReplicatedStorage:WaitForChild("Royale")
local Config = require(Royale:WaitForChild("Config"))

local ImpactView = {}

local IM = Config.impact

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

function ImpactView.start()
	local player = Players.LocalPlayer
	local remote =
		Royale:WaitForChild(Config.remotes.folder):WaitForChild(Config.remotes.impact) :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "RoyaleImpact"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = IM.displayOrder
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Le voile rouge de qui est frappe : un cadre degrade vers les bords.
	local vignette = Instance.new("Frame")
	vignette.Name = "Voile"
	vignette.BorderSizePixel = 0
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BackgroundColor3 = rgb(IM.flashColor)
	vignette.BackgroundTransparency = 1
	vignette.Parent = gui
	local edge = Instance.new("UIGradient")
	edge.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 1),
		NumberSequenceKeypoint.new(0.7, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	edge.Parent = vignette

	-- La marque de l'attaquant : une croix fine au centre.
	local marker = Instance.new("Frame")
	marker.Name = "Marque"
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Position = UDim2.fromScale(0.5, 0.5)
	marker.Size = UDim2.fromOffset(IM.markerSize, IM.markerSize)
	marker.BackgroundTransparency = 1
	marker.Visible = false
	marker.Parent = gui
	for _, angle in { 45, -45 } do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.new(1, 0, 0, 3)
		bar.Rotation = angle
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = Color3.new(1, 1, 1)
		bar.Parent = marker
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Transparency = 0.4
		stroke.Parent = bar
	end
	local markerScale = Instance.new("UIScale")
	markerScale.Parent = marker

	-- Le tremblement : un decalage de la camera qui s'eteint.
	local shakeUntil = 0
	RunService:BindToRenderStep(
		"RoyaleImpactSecousse",
		Enum.RenderPriority.Camera.Value + 3,
		function()
			local left = shakeUntil - os.clock()
			if left <= 0 then
				return
			end
			local camera = workspace.CurrentCamera
			if camera == nil then
				return
			end
			local k = left / IM.shakeSeconds * IM.shakeStuds
			camera.CFrame = camera.CFrame
				* CFrame.new((math.random() - 0.5) * 2 * k, (math.random() - 0.5) * 2 * k, 0)
		end
	)

	local function flash(target: Model)
		local h = Instance.new("Highlight")
		h.FillColor = rgb(IM.flashColor)
		h.OutlineColor = Color3.new(1, 1, 1)
		h.FillTransparency = 0.25
		h.OutlineTransparency = 0.2
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Adornee = target
		h.Parent = gui
		TweenService:Create(
			h,
			TweenInfo.new(IM.flashSeconds),
			{ FillTransparency = 1, OutlineTransparency = 1 }
		):Play()
		task.delay(IM.flashSeconds, function()
			h:Destroy()
		end)
		-- Des eclats, a hauteur de poitrine.
		local root = target:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local anchor = Instance.new("Attachment")
			anchor.WorldPosition = root.Position + Vector3.new(0, 0.8, 0)
			anchor.Parent = workspace.Terrain
			local sparks = Instance.new("ParticleEmitter")
			sparks.Color = ColorSequence.new(Color3.new(1, 1, 1), rgb(IM.flashColor))
			sparks.LightEmission = 1
			sparks.Size = NumberSequence.new(0.35, 0)
			sparks.Lifetime = NumberRange.new(0.15, 0.3)
			sparks.Speed = NumberRange.new(10, 18)
			sparks.SpreadAngle = Vector2.new(180, 180)
			sparks.Enabled = false
			sparks.Parent = anchor
			sparks:Emit(IM.sparks)
			task.delay(0.5, function()
				anchor:Destroy()
			end)
		end
	end

	remote.OnClientEvent:Connect(function(target: Model?, by: Model?, ko: boolean)
		if target == nil then
			return
		end
		flash(target)
		local me = player.Character
		if by ~= nil and by == me then
			marker.Visible = true
			markerScale.Scale = if ko then 1.6 else 1.25
			TweenService:Create(markerScale, TweenInfo.new(IM.markerSeconds), { Scale = 1 }):Play()
			task.delay(IM.markerSeconds, function()
				marker.Visible = false
			end)
			shakeUntil = os.clock() + IM.shakeSeconds * 0.5
		elseif target == me then
			vignette.BackgroundTransparency = 1 - IM.vignetteOpacity
			TweenService
				:Create(vignette, TweenInfo.new(IM.vignetteSeconds), { BackgroundTransparency = 1 })
				:Play()
			shakeUntil = os.clock() + IM.shakeSeconds
		end
	end)
end

return ImpactView
