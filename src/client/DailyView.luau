--!strict
--[[
	DailyView — l'ecran de la recompense du jour (Config.daily ; choisi avec
	Josh le 14 novembre 2026, embelli le 15 : « dans le style de la
	boutique, en plus beau »).

	En haut, la recompense du jour en grand, qui tourne sur un halo et des
	rayons a la couleur de sa rarete ; en bas, les 7 cases de la semaine sur
	une piste (les jours passes coches, la case du jour qui brille, le jour 7
	plus grand). A, B, le bouton « Super ! » ou un toucher ferme. Au
	telephone, la grande image laisse la place pour que le texte reste
	lisible.
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Royale = ReplicatedStorage:WaitForChild("Royale")
local Config = require(Royale:WaitForChild("Config"))

local ButtonIcons = require(script.Parent.ButtonIcons)
local ItemThumb = require(script.Parent.ItemThumb)
local UiKit = require(script.Parent.UiKit)

local DailyView = {}

local D = Config.daily
local H = Config.lobby.hud
local V = Config.view
local CO = Config.cosmetics
local UI = Config.shop.ui
local KP = Config.controls.contexts.shopPanel
local LANTERN = Config.lobby.colors.lantern

local rgb = UiKit.rgb
local round = UiKit.round
local label = UiKit.label

local function rarityOf(reward: any): any
	local def = reward.item and CO.items[reward.item]
	return def and Config.rarities[def.rarity]
end

local function describe(reward: any): (string, Color3)
	local rarity = rarityOf(reward)
	if reward.item then
		return CO.items[reward.item].name, if rarity then rgb(rarity.color) else rgb(H.text)
	elseif reward.credits then
		return string.format("%d crédits", reward.credits), rgb(UI.coin)
	end
	return string.format("%d fragments", reward.fragments), rgb(UI.fragment)
end

function DailyView.start()
	local player = Players.LocalPlayer
	local text = rgb(H.text)
	local dim = rgb(UI.dimText)

	-- Les mesures du panneau se deduisent de ce qu'il contient.
	local width = D.cardWidth * (D.days - 1 + D.lastWide)
		+ D.cardGap * (D.days - 1)
		+ 2 * (D.pad + D.sideRoom)
	local function contentHeight(withHero: boolean): number
		local parts = {
			D.titleSize + 6,
			D.textSize + 6,
			D.gotSize + 6,
			D.textSize + 4,
			D.cardHeight + 12,
			D.buttonHeight,
			D.textSize + 3,
		}
		if withHero then
			table.insert(parts, D.heroSize)
		end
		local total = 2 * D.pad + (#parts - 1) * D.gap
		for _, h in parts do
			total += h
		end
		return total
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "RoyaleQuotidien"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = Config.shop.displayOrder + 1
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Un voile sur le salon : la recompense est un moment.
	local veil = UiKit.button(gui, "Voile")
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.new(0, 0, 0)
	veil.BackgroundTransparency = 1

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(width, contentHeight(true))
	panel.BackgroundColor3 = Color3.new(1, 1, 1)
	panel.BackgroundTransparency = UI.panelTransparency
	panel.Parent = gui
	round(panel, UI.corner + 6)
	UiKit.gradient(panel, rgb(UI.panelTop), rgb(UI.panelBottom), 0.4)
	UiKit.stroke(panel, rgb(LANTERN), 2, 0.3)
	local inner = Instance.new("Frame")
	inner.BackgroundTransparency = 1
	inner.Position = UDim2.fromOffset(UI.innerFrame, UI.innerFrame)
	inner.Size = UDim2.new(1, -2 * UI.innerFrame, 1, -2 * UI.innerFrame)
	inner.Parent = panel
	round(inner, UI.corner + 2)
	UiKit.stroke(inner, rgb(LANTERN), 1, 0.82)
	local fit = Instance.new("UIScale")
	fit.Parent = panel

	-- Le contenu, en colonne, a part du cadre (sinon le filet interieur
	-- prenait la premiere place de la colonne, vu en image).
	local content = Instance.new("Frame")
	content.Name = "Contenu"
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(1, 1)
	content.Parent = panel
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, D.gap)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = content
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, D.pad)
	pad.PaddingBottom = UDim.new(0, D.pad)
	pad.Parent = content

	local function line(order: number, size: number, font: string, color: Color3): TextLabel
		local l = label(content, "", size, font, color)
		l.LayoutOrder = order
		l.Size = UDim2.new(1, -2 * D.pad, 0, size + 6)
		return l
	end
	local title = line(1, D.titleSize, V.font, rgb(LANTERN))
	title.Text = "RÉCOMPENSE DU JOUR"
	local sub = line(2, D.textSize, V.bodyFont, dim)

	-- La grande image : rayons, halo, l'objet qui tourne.
	local hero = Instance.new("Frame")
	hero.Name = "Grand"
	hero.LayoutOrder = 3
	hero.BackgroundTransparency = 1
	hero.Size = UDim2.fromOffset(D.heroSize * 2, D.heroSize)
	hero.Parent = content
	local rays = Instance.new("Frame")
	rays.Name = "Rayons"
	rays.BackgroundTransparency = 1
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.5)
	rays.Size = UDim2.fromOffset(D.heroSize * D.rayLength, D.heroSize * D.rayLength)
	rays.Parent = hero
	local rayList: { Frame } = {}
	for i = 1, D.rays do
		local ray = Instance.new("Frame")
		ray.BorderSizePixel = 0
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.new(0, D.rayWidth, 1, 0)
		ray.Rotation = (i - 1) * 180 / D.rays
		ray.Parent = rays
		local fade = Instance.new("UIGradient")
		fade.Rotation = 90
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, D.rayStrength),
			NumberSequenceKeypoint.new(1, 1),
		})
		fade.Parent = ray
		table.insert(rayList, ray)
	end
	local heroGlow: Frame? = nil
	local heroView = Instance.new("ViewportFrame")
	heroView.Name = "Image"
	heroView.BackgroundTransparency = 1
	heroView.AnchorPoint = Vector2.new(0.5, 0.5)
	heroView.Position = UDim2.fromScale(0.5, 0.5)
	heroView.Size = UDim2.fromOffset(D.heroSize, D.heroSize)
	heroView.ZIndex = 3
	heroView.Parent = hero

	local got = line(4, D.gotSize, V.font, text)
	local gotRarity = line(5, D.textSize - 2, V.bodyBoldFont, dim)
	gotRarity.Size = UDim2.new(1, -2 * D.pad, 0, D.textSize + 4)

	-- La piste des 7 jours.
	local track = Instance.new("Frame")
	track.Name = "Piste"
	track.LayoutOrder = 6
	track.BackgroundTransparency = 1
	track.Size = UDim2.fromOffset(width - 2 * D.pad, D.cardHeight + 12)
	track.Parent = content
	local rail = Instance.new("Frame")
	rail.BorderSizePixel = 0
	rail.AnchorPoint = Vector2.new(0.5, 0.5)
	rail.Position = UDim2.fromScale(0.5, 0.5)
	rail.Size = UDim2.new(0.86, 0, 0, 4)
	rail.BackgroundColor3 = Color3.new(0, 0, 0)
	rail.BackgroundTransparency = 0.3
	rail.Parent = track
	local railFill = Instance.new("Frame")
	railFill.BorderSizePixel = 0
	railFill.BackgroundColor3 = rgb(LANTERN)
	railFill.Parent = rail
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.ZIndex = 2
	row.Parent = track
	local rowList = Instance.new("UIListLayout")
	rowList.FillDirection = Enum.FillDirection.Horizontal
	rowList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowList.VerticalAlignment = Enum.VerticalAlignment.Center
	rowList.Padding = UDim.new(0, D.cardGap)
	rowList.SortOrder = Enum.SortOrder.LayoutOrder
	rowList.Parent = row

	-- Le bouton, puis la regle en une ligne.
	local ok = UiKit.button(content, "Super")
	ok.LayoutOrder = 7
	ok.Size = UDim2.fromOffset(D.buttonWidth, D.buttonHeight)
	ok.BackgroundColor3 = rgb(LANTERN)
	round(ok, D.buttonHeight)
	local okList = Instance.new("UIListLayout")
	okList.FillDirection = Enum.FillDirection.Horizontal
	okList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	okList.VerticalAlignment = Enum.VerticalAlignment.Center
	okList.Padding = UDim.new(0, 8)
	okList.SortOrder = Enum.SortOrder.LayoutOrder
	okList.Parent = ok
	local okIcon: Frame? = nil
	local okText = label(ok, "Super !", D.textSize + 2, V.bodyBoldFont, rgb(UI.buyText))
	okText.LayoutOrder = 2
	okText.AutomaticSize = Enum.AutomaticSize.X
	okText.Size = UDim2.fromOffset(0, D.buttonHeight)
	okText.TextWrapped = false
	local hint = line(8, D.textSize - 3, V.bodyFont, dim)
	hint.Size = UDim2.new(1, -2 * D.pad, 0, D.textSize + 3)
	hint.Text = "Reviens demain pour la suite — un jour raté fait reculer d'une case."

	-- Grand ecran : tout. Telephone : sans la grande image, sinon le texte
	-- deviendrait illisible.
	local function refit()
		local camera = workspace.CurrentCamera
		if camera == nil then
			return
		end
		local top = GuiService:GetGuiInset().Y
		local size = camera.ViewportSize
		local usable = Vector2.new(size.X, size.Y - top) * D.screenShare
		local full = math.min(usable.X / width, usable.Y / contentHeight(true), D.maxScale)
		local compact = full < UI.minScale
		hero.Visible = not compact
		local height = contentHeight(not compact)
		panel.Size = UDim2.fromOffset(width, height)
		panel.Position = UDim2.new(0.5, 0, 0.5, top / 2)
		fit.Scale = math.min(usable.X / width, usable.Y / height, D.maxScale)
	end

	local shownAt = 0
	local spinning: RBXScriptConnection? = nil
	local function close()
		gui.Enabled = false
		ContextActionService:UnbindAction("RoyaleQuotidienFermer")
		if spinning then
			spinning:Disconnect()
			spinning = nil
		end
	end
	ok.Activated:Connect(close)
	veil.Activated:Connect(close)

	local function card(day: number, reward: any, today: boolean, past: boolean)
		local name, color = describe(reward)
		local wide = if day == D.days then D.lastWide else 1
		local cell = Instance.new("Frame")
		cell.Name = "Jour" .. day
		cell.LayoutOrder = day
		cell.BackgroundTransparency = 1
		cell.Size = UDim2.fromOffset(D.cardWidth * wide, D.cardHeight)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Size = if today then UDim2.new(1, 8, 1, 8) else UDim2.fromScale(1, 1)
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		-- Opaque : la piste passe derriere (elle se voyait a travers, vu en
		-- image) ; un jour pris s'assombrit par un voile.
		f.BackgroundTransparency = 0
		f.ZIndex = 2
		round(f, UI.corner)
		UiKit.gradient(
			f,
			rgb(UI.card):Lerp(color, if today then 0.45 else UI.cardTint),
			rgb(UI.cardBottom),
			0.6
		)
		UiKit.stroke(
			f,
			if today then rgb(LANTERN) else color,
			if today then 3 else 1.5,
			if today then 0 else 0.5
		)
		f.Parent = cell
		local dayLabel = label(
			f,
			if today then "AUJOURD'HUI" else "JOUR " .. day,
			D.dayTextSize,
			V.bodyBoldFont,
			if today then rgb(LANTERN) else dim
		)
		dayLabel.Position = UDim2.fromOffset(0, 5)
		dayLabel.Size = UDim2.new(1, 0, 0, D.dayTextSize + 2)
		dayLabel.ZIndex = 3
		local imageTop = D.dayTextSize + 10
		UiKit.glow(
			f,
			UDim2.new(0.5, 0, 0, imageTop + D.cardImage / 2),
			D.cardImage * UI.glowSize,
			color,
			if past then UI.glowStrength * 0.4 else UI.glowStrength
		)
		local view = Instance.new("ViewportFrame")
		view.Name = "Image"
		view.BackgroundTransparency = 1
		view.AnchorPoint = Vector2.new(0.5, 0)
		view.Position = UDim2.new(0.5, 0, 0, imageTop)
		view.Size = UDim2.fromOffset(D.cardImage * wide, D.cardImage)
		view.ImageTransparency = if past then 0.55 else 0
		view.ZIndex = 3
		view.Parent = f
		if reward.item then
			ItemThumb.item(view, reward.item)
		else
			ItemThumb.currency(view, if reward.credits then "credits" else "fragments")
		end
		local n = label(f, name, D.dayTextSize, V.bodyBoldFont, color)
		n.AnchorPoint = Vector2.new(0, 1)
		n.Position = UDim2.new(0, 4, 1, -5)
		n.Size = UDim2.new(1, -8, 0, D.dayTextSize * 2 + 2)
		n.TextYAlignment = Enum.TextYAlignment.Bottom
		n.ZIndex = 3
		if past then
			local shade = Instance.new("Frame")
			shade.BorderSizePixel = 0
			shade.Size = UDim2.fromScale(1, 1)
			shade.BackgroundColor3 = Color3.new(0, 0, 0)
			shade.BackgroundTransparency = D.pastShade
			shade.ZIndex = 4
			round(shade, UI.corner)
			shade.Parent = f
			-- Le jour pris : une pastille verte cochee, par-dessus.
			local check = Instance.new("Frame")
			check.AnchorPoint = Vector2.new(0.5, 0.5)
			check.Position = UDim2.new(0.5, 0, 0, imageTop + D.cardImage / 2)
			check.Size = UDim2.fromOffset(D.checkSize, D.checkSize)
			check.BackgroundColor3 = rgb(UI.owned)
			check.ZIndex = 5
			round(check, D.checkSize)
			check.Parent = f
			local mark = label(check, "✓", D.checkSize * 0.7, V.bodyBoldFont, rgb(UI.buyText))
			mark.Size = UDim2.fromScale(1, 1)
			mark.ZIndex = 6
		end
		cell.Parent = row
	end

	local function show(value: any)
		if typeof(value) ~= "string" then
			return
		end
		local decoded, data = pcall(function()
			return HttpService:JSONDecode(value)
		end)
		if not decoded or typeof(data) ~= "table" then
			return
		end
		local week = D.weeks[data.week]
		local reward = week and week[data.day]
		if reward == nil then
			return
		end
		local name, color = describe(reward)
		sub.Text = string.format(
			"Semaine %d sur %d  ·  jour %d sur %d",
			data.week,
			#D.weeks,
			data.day,
			D.days
		)
		-- Ce que le serveur a vraiment donne (un objet deja a soi devient des
		-- credits) ; la couleur de la rarete seulement si c'est l'objet.
		got.Text = "Tu reçois : " .. tostring(data.got)
		got.TextColor3 = if tostring(data.got) == name then color else text
		local rarity = rarityOf(reward)
		gotRarity.Text = if rarity and tostring(data.got) == name
			then UiKit.upper(rarity.name) .. "  ·  " .. CO.slotNames[CO.items[reward.item].slot]
			else ""
		for _, ray in rayList do
			ray.BackgroundColor3 = color
		end
		if heroGlow then
			heroGlow:Destroy()
		end
		heroGlow =
			UiKit.glow(hero, UDim2.fromScale(0.5, 0.5), D.heroSize * 1.2, color, UI.glowStrength)
		if reward.item then
			ItemThumb.item(heroView, reward.item)
		else
			ItemThumb.currency(heroView, if reward.credits then "credits" else "fragments")
		end
		ItemThumb.spin(heroView)
		for _, c in row:GetChildren() do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		for day, r in week do
			card(day, r, day == data.day, day < data.day)
		end
		railFill.Size = UDim2.fromScale((data.day - 1) / math.max(1, D.days - 1), 1)
		if okIcon then
			okIcon:Destroy()
			okIcon = nil
		end
		if not ButtonIcons.touch() then
			okIcon = ButtonIcons.chip(ok, KP.confirm, "", D.buttonHeight - 14, D.textSize, 1)
		end
		gui.Enabled = true
		refit()
		-- L'entree : le voile tombe, le panneau rebondit.
		veil.BackgroundTransparency = 1
		UiKit.tween(veil, D.enterSeconds, { BackgroundTransparency = D.veil })
		local goal = fit.Scale
		fit.Scale = goal * UI.popFrom
		TweenService:Create(
			fit,
			TweenInfo.new(D.enterSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = goal }
		):Play()
		if spinning == nil then
			spinning = RunService.RenderStepped:Connect(function(dt: number)
				for _, ray in rayList do
					ray.Rotation += dt * D.raySpin
				end
			end)
		end
		shownAt = os.clock()
		ContextActionService:BindActionAtPriority(
			"RoyaleQuotidienFermer",
			function(_, state: Enum.UserInputState)
				if state == Enum.UserInputState.Begin then
					close()
				end
				return Enum.ContextActionResult.Sink
			end,
			false,
			Enum.ContextActionPriority.High.Value + 2,
			-- Les touches de la boutique (Config.controls) : valider ou fermer.
			Enum.KeyCode[KP.confirm.gamepad],
			Enum.KeyCode[KP.close.gamepad],
			Enum.KeyCode[KP.confirm.keyboard],
			Enum.KeyCode[KP.close.keyboard]
		)
		local mine = shownAt
		task.delay(D.showSeconds, function()
			if gui.Enabled and shownAt == mine then
				close()
			end
		end)
	end

	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if gui.Enabled then
				refit()
			end
		end)
	end
	player:GetAttributeChangedSignal(D.attribute):Connect(function()
		show(player:GetAttribute(D.attribute))
	end)
	show(player:GetAttribute(D.attribute))
end

return DailyView
