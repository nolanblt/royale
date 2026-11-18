--!strict
--[[
	DrawReveal — l'ouverture d'un tirage (Josh, le 18 novembre 2026 : « une
	vraie animation quand on ouvre des boites »).

	Le serveur publie l'objet tire (attribut `DernierTirage` : « id|doublon|
	heure »). L'ecran s'assombrit, une caisse tremble de plus en plus fort
	en s'eclairant a la couleur de la rarete, s'ouvre dans un eclair ; des
	rayons tournent derriere l'objet, montre en 3D et qui tourne, avec son
	nom et sa rarete (et ce que rend un doublon). A, B ou un toucher ferme.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Royale = ReplicatedStorage:WaitForChild("Royale")
local Config = require(Royale:WaitForChild("Config"))

local ItemThumb = require(script.Parent.ItemThumb)
local UiKit = require(script.Parent.UiKit)

local DrawReveal = {}

local DR = Config.shop.reveal
local CO = Config.cosmetics
local K = Config.controls.contexts.shopPanel
local rgb = UiKit.rgb

function DrawReveal.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "RoyaleOuverture"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = DR.displayOrder
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local veil = UiKit.button(gui, "Voile")
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.new(0, 0, 0)

	-- Les rayons : de longues bandes qui tournent derriere l'objet.
	local rays = Instance.new("Frame")
	rays.Name = "Rayons"
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.45)
	rays.Size = UDim2.fromOffset(DR.raysSize, DR.raysSize)
	rays.BackgroundTransparency = 1
	rays.Parent = gui
	local rayBars: { Frame } = {}
	for k = 1, DR.rays do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.new(1, 0, 0, DR.rayWidth)
		bar.Rotation = (k - 1) * 180 / DR.rays
		bar.BorderSizePixel = 0
		local fade = Instance.new("UIGradient")
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		fade.Parent = bar
		bar.Parent = rays
		table.insert(rayBars, bar)
	end

	-- La caisse : du bois sombre cercle de fer, qui s'eclaire par les fentes.
	local crate = Instance.new("Frame")
	crate.Name = "Caisse"
	crate.AnchorPoint = Vector2.new(0.5, 0.5)
	crate.Position = UDim2.fromScale(0.5, 0.45)
	crate.Size = UDim2.fromOffset(DR.crateSize, DR.crateSize)
	crate.BackgroundColor3 = rgb({ 92, 60, 38 })
	crate.Parent = gui
	UiKit.round(crate, 10)
	local crateStroke = UiKit.stroke(crate, rgb({ 40, 30, 26 }), 6, 0)
	UiKit.gradient(crate, rgb({ 120, 82, 52 }), rgb({ 60, 38, 24 }), 0.5)
	for _, y in { 0.33, 0.66 } do
		local band = Instance.new("Frame")
		band.BorderSizePixel = 0
		band.AnchorPoint = Vector2.new(0, 0.5)
		band.Position = UDim2.fromScale(0, y)
		band.Size = UDim2.new(1, 0, 0, 10)
		band.BackgroundColor3 = rgb({ 46, 40, 40 })
		band.Parent = crate
	end
	local seam = Instance.new("Frame")
	seam.Name = "Fente"
	seam.BorderSizePixel = 0
	seam.AnchorPoint = Vector2.new(0.5, 0.5)
	seam.Position = UDim2.fromScale(0.5, 0.5)
	seam.Size = UDim2.new(1, -24, 0, 4)
	seam.Parent = crate
	local crateScale = Instance.new("UIScale")
	crateScale.Parent = crate

	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = gui

	local view = Instance.new("ViewportFrame")
	view.AnchorPoint = Vector2.new(0.5, 0.5)
	view.Position = UDim2.fromScale(0.5, 0.42)
	view.Size = UDim2.fromOffset(DR.itemSize, DR.itemSize)
	view.BackgroundTransparency = 1
	view.Parent = gui
	local viewScale = Instance.new("UIScale")
	viewScale.Parent = view

	local rarityText =
		UiKit.label(gui, "", DR.raritySize, Config.view.bodyBoldFont, Color3.new(1, 1, 1))
	rarityText.AnchorPoint = Vector2.new(0.5, 0)
	rarityText.Position = UDim2.new(0.5, 0, 0.42, DR.itemSize / 2 + 8)
	rarityText.Size = UDim2.new(0.9, 0, 0, DR.raritySize + 6)
	local nameText = UiKit.label(gui, "", DR.nameSize, Config.view.font, Color3.new(1, 1, 1))
	nameText.AnchorPoint = Vector2.new(0.5, 0)
	nameText.Position = UDim2.new(0.5, 0, 0.42, DR.itemSize / 2 + DR.raritySize + 18)
	nameText.Size = UDim2.new(0.9, 0, 0, DR.nameSize + 8)
	nameText.TextStrokeTransparency = 0.3
	local noteText =
		UiKit.label(gui, "", DR.noteSize, Config.view.bodyFont, rgb(Config.lobby.hud.text))
	noteText.AnchorPoint = Vector2.new(0.5, 0)
	noteText.Position = UDim2.new(0.5, 0, 0.42, DR.itemSize / 2 + DR.raritySize + DR.nameSize + 34)
	noteText.Size = UDim2.new(0.9, 0, 0, DR.noteSize * 2 + 6)

	local token = 0
	local closable = false
	local spinning: RBXScriptConnection? = nil

	local function close()
		if not closable then
			return
		end
		closable = false
		token += 1
		gui.Enabled = false
		ItemThumb.spin(view, false)
		if spinning then
			spinning:Disconnect()
			spinning = nil
		end
		ContextActionService:UnbindAction("RoyaleOuvertureFermer")
	end

	local function play(id: string, duplicate: boolean)
		local def = CO.items[id]
		if def == nil then
			return
		end
		token += 1
		local mine = token
		local rarity = Config.rarities[def.rarity]
		local color = if rarity then rgb(rarity.color) else rgb(Config.lobby.colors.lantern)
		gui.Enabled = true
		closable = false
		veil.BackgroundTransparency = 1
		TweenService:Create(veil, TweenInfo.new(0.25), { BackgroundTransparency = DR.veil }):Play()
		crate.Visible = true
		crate.Rotation = 0
		crateScale.Scale = 0.6
		UiKit.pop(crateScale, 0.6, 1, 0.25)
		seam.BackgroundColor3 = color
		seam.BackgroundTransparency = 0.6
		crateStroke.Color = rgb({ 40, 30, 26 })
		rays.Visible = false
		view.Visible = false
		rarityText.Text = ""
		nameText.Text = ""
		noteText.Text = ""
		-- La caisse tremble de plus en plus fort, la fente s'eclaire.
		local started = os.clock()
		while os.clock() - started < DR.shakeSeconds do
			if token ~= mine then
				return
			end
			local k = (os.clock() - started) / DR.shakeSeconds
			crate.Rotation = math.sin(os.clock() * 40) * DR.shakeDegrees * k
			crate.Position = UDim2.new(0.5, math.sin(os.clock() * 55) * 6 * k, 0.45, 0)
			seam.BackgroundTransparency = 0.6 - 0.6 * k
			seam.Size = UDim2.new(1, -24, 0, 4 + 10 * k)
			crateStroke.Color = rgb({ 40, 30, 26 }):Lerp(color, k)
			task.wait()
		end
		if token ~= mine then
			return
		end
		-- L'eclair, puis l'objet.
		flash.BackgroundTransparency = 0
		TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		crate.Visible = false
		rays.Visible = true
		for _, bar in rayBars do
			bar.BackgroundColor3 = color
		end
		view.Visible = true
		ItemThumb.item(view, id)
		ItemThumb.spin(view, true)
		viewScale.Scale = 0.3
		UiKit.pop(viewScale, 0.3, 1, 0.35)
		rarityText.Text = UiKit.upper(if rarity then rarity.name else "")
		rarityText.TextColor3 = color
		nameText.Text = def.name
		nameText.TextColor3 = color
		noteText.Text = if duplicate
			then "Déjà à toi : une part de son prix te revient en crédits."
			else "Il est à toi : retrouve-le dans « Mes cosmétiques »."
		spinning = game:GetService("RunService").RenderStepped:Connect(function(dt: number)
			rays.Rotation += dt * DR.raysSpeed
		end)
		task.wait(DR.closeAfter)
		if token ~= mine then
			return
		end
		closable = true
		ContextActionService:BindActionAtPriority(
			"RoyaleOuvertureFermer",
			function(_, state)
				if state == Enum.UserInputState.Begin then
					close()
				end
				return Enum.ContextActionResult.Sink
			end,
			false,
			Enum.ContextActionPriority.High.Value + DR.priorityAbove,
			Enum.KeyCode[K.confirm.gamepad],
			Enum.KeyCode[K.close.gamepad],
			Enum.KeyCode[K.confirm.keyboard],
			Enum.KeyCode[K.close.keyboard]
		)
	end

	veil.Activated:Connect(close)
	local last = ""
	player:GetAttributeChangedSignal(Config.shop.drawAttribute):Connect(function()
		local value = player:GetAttribute(Config.shop.drawAttribute)
		if typeof(value) ~= "string" or value == last then
			return
		end
		last = value
		local id, dup, at = string.match(value, "^(.-)|(%d)|(.+)$")
		local t = tonumber(at)
		if id and t and workspace:GetServerTimeNow() - t < DR.freshSeconds then
			task.spawn(play, id, dup == "1")
		end
	end)
end

return DrawReveal
