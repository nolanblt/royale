--!strict
--[[
	SewerView — dans un egout, on choisit ou ressortir (choisi avec Josh le
	16 novembre 2026, avant : « on est juste sous la map, il se passe
	rien »).

	Cache dans un egout : chaque plaque a portee porte un repere vu a
	travers le sol (« Ici », ou sa distance) ; la croix gauche / droite
	change la plaque choisie, qui grossit et prend la couleur lanterne ; X
	(Controls) y mene. Le trajet se fait dans le noir, le temps que le
	serveur annonce (attribut `EgoutTrajet`). Le serveur verifie la plaque
	choisie : l'ecran ne decide rien.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Royale = ReplicatedStorage:WaitForChild("Royale")
local Config = require(Royale:WaitForChild("Config"))

local ButtonIcons = require(script.Parent.ButtonIcons)
local InputBus = require(script.Parent.InputBus)

local SewerView = {}

local H = Config.hiding
local S = H.sewer
local HC = Config.controls.contexts.hidden

local chosenModel: Model? = nil

-- La plaque choisie, si l'on est dans un egout (Controls l'envoie avec X).
function SewerView.chosen(): Model?
	return chosenModel
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function keys(binding: { gamepad: string, keyboard: string }): { Enum.KeyCode }
	return { (Enum.KeyCode :: any)[binding.gamepad], (Enum.KeyCode :: any)[binding.keyboard] }
end

function SewerView.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "RoyaleEgout"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	local hint = Instance.new("TextLabel")
	hint.Name = "Aide"
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.fromScale(0.5, 0.82)
	hint.Size = UDim2.new(0.8, 0, 0, 30)
	hint.BackgroundTransparency = 1
	hint.Font = (Enum.Font :: any)[Config.view.bodyBoldFont]
	hint.TextSize = S.hintTextSize
	hint.TextColor3 = rgb(S.chosenColor)
	hint.TextStrokeTransparency = 0.3
	hint.Visible = false
	hint.Parent = gui

	-- Le noir du trajet.
	local dark = Instance.new("Frame")
	dark.Name = "Noir"
	dark.Size = UDim2.fromScale(1, 1)
	dark.BackgroundColor3 = Color3.new(0, 0, 0)
	dark.BackgroundTransparency = 1
	dark.BorderSizePixel = 0
	dark.Parent = gui
	local crawl = Instance.new("TextLabel")
	crawl.BackgroundTransparency = 1
	crawl.Size = UDim2.fromScale(1, 1)
	crawl.Font = (Enum.Font :: any)[Config.view.font]
	crawl.TextSize = S.crawlTextSize
	crawl.TextColor3 = rgb(S.markerColor)
	crawl.TextTransparency = 1
	crawl.Text = "Tu rampes dans le noir…"
	crawl.Parent = dark

	local markers = Instance.new("Folder")
	markers.Name = "RoyaleReperesEgout"
	markers.Parent = gui

	type Option = { model: Model, exit: BasePart, distance: number }
	local options: { Option } = {}
	local index = 1

	local function inSewer(): boolean
		return player:GetAttribute(H.hiddenAttribute) == H.displayNames[S.name]
	end

	local function clearMarkers()
		markers:ClearAllChildren()
		table.clear(options)
		chosenModel = nil
	end

	-- Les plaques a portee : celle d'ici d'abord, puis les autres dans le
	-- sens des aiguilles d'une montre (droite, puis encore a droite...).
	local function gather()
		clearMarkers()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local placed = workspace:FindFirstChild(Config.world.folder)
		placed = placed and placed:FindFirstChild(Config.world.placedFolder)
		if root == nil or not root:IsA("BasePart") or placed == nil then
			return
		end
		local here: Option? = nil
		local others: { Option & { angle: number } } = {}
		for _, m in placed:GetChildren() do
			local exit = m:FindFirstChild(Config.world.exit)
			if m:IsA("Model") and m.Name == S.name and exit and exit:IsA("BasePart") then
				local delta = exit.Position - root.Position
				local d = Vector3.new(delta.X, 0, delta.Z).Magnitude
				if here == nil or d < here.distance then
					if here then
						local angle = math.atan2(
							here.exit.Position.X - root.Position.X,
							-(here.exit.Position.Z - root.Position.Z)
						)
						table.insert(others, {
							model = here.model,
							exit = here.exit,
							distance = here.distance,
							angle = angle,
						})
					end
					here = { model = m, exit = exit, distance = d }
				elseif d <= S.range then
					table.insert(others, {
						model = m,
						exit = exit,
						distance = d,
						angle = math.atan2(delta.X, -delta.Z),
					})
				end
			end
		end
		if here == nil then
			return
		end
		table.insert(options, here)
		table.sort(others, function(a, b)
			return a.angle < b.angle
		end)
		for _, o in others do
			if o.distance <= S.range then
				table.insert(options, { model = o.model, exit = o.exit, distance = o.distance })
			end
		end
		index = 1
		for i, o in options do
			local tag = Instance.new("BillboardGui")
			tag.Name = "Repere" .. i
			tag.Adornee = o.exit
			tag.AlwaysOnTop = true
			tag.LightInfluence = 0
			tag.Size = UDim2.fromOffset(S.markerSize, S.markerSize / 2)
			tag.StudsOffset = Vector3.new(0, 2, 0)
			local label = Instance.new("TextLabel")
			label.Name = "Texte"
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Font = (Enum.Font :: any)[Config.view.bodyBoldFont]
			label.TextScaled = true
			label.TextStrokeTransparency = 0.2
			label.Text = if i == 1 then "Ici" else string.format("%d m", math.floor(o.distance))
			label.Parent = tag
			tag.Parent = markers
		end
	end

	local function paint()
		for i in options do
			local tag = markers:FindFirstChild("Repere" .. i) :: BillboardGui?
			if tag then
				local on = i == index
				local label = tag:FindFirstChild("Texte") :: TextLabel
				label.TextColor3 = if on then rgb(S.chosenColor) else rgb(S.markerColor)
				tag.Size = if on
					then UDim2.fromOffset(S.markerSize * 1.5, S.markerSize * 0.75)
					else UDim2.fromOffset(S.markerSize, S.markerSize / 2)
				label.TextTransparency = if on then 0 else 0.35
			end
		end
		local o = options[index]
		chosenModel = if o then o.model else nil
	end

	InputBus.bind("RoyaleEgoutChoix", function(_, state: Enum.UserInputState, input: InputObject)
		if state ~= Enum.UserInputState.Begin or not inSewer() or #options == 0 then
			return Enum.ContextActionResult.Pass
		end
		local back = input.KeyCode == Enum.KeyCode[HC.previousExit.gamepad]
			or input.KeyCode == Enum.KeyCode[HC.previousExit.keyboard]
		index = (index - 1 + (if back then -1 else 1)) % #options + 1
		paint()
		return Enum.ContextActionResult.Sink
	end, false, table.unpack(keys(HC.previousExit)), table.unpack(keys(HC.nextExit)))

	local wasInside = false
	local traveling = false
	RunService.Heartbeat:Connect(function()
		local inside = inSewer()
		if inside and not wasInside then
			-- Le personnage vient d'etre pose dans la salle : on attend une image.
			task.defer(function()
				gather()
				paint()
			end)
		elseif not inside and wasInside then
			clearMarkers()
		end
		wasInside = inside
		hint.Visible = inside and not traveling and #options > 0
		if hint.Visible then
			hint.Text = if ButtonIcons.touch()
				then "Touche ‹ › pour choisir la sortie, puis Sortir"
				elseif ButtonIcons.gamepad() then "◀ ▶ choisir la sortie · X ressortir"
				else "← → choisir la sortie · E ressortir"
		end
		-- Le trajet, dans le noir.
		local arrival = player:GetAttribute(S.travelAttribute)
		local now = typeof(arrival) == "number" and workspace:GetServerTimeNow() < arrival
		if now and not traveling then
			traveling = true
			markers.Parent = nil
			TweenService:Create(dark, TweenInfo.new(S.fadeSeconds), { BackgroundTransparency = 0 })
				:Play()
			TweenService:Create(crawl, TweenInfo.new(S.fadeSeconds), { TextTransparency = 0 })
				:Play()
		elseif not now and traveling then
			traveling = false
			markers.Parent = gui
			TweenService:Create(dark, TweenInfo.new(S.fadeSeconds), { BackgroundTransparency = 1 })
				:Play()
			TweenService:Create(crawl, TweenInfo.new(S.fadeSeconds), { TextTransparency = 1 })
				:Play()
		end
	end)
end

return SewerView
