--!strict
--[[
	ShopView — la boutique au salon (croix gauche, le bouton Boutique, ou X
	devant l'echoppe). A la manette : la croix choisit une carte, L1 / R1
	changent d'onglet, A achete, tire, equipe ou paie, B ferme. Au doigt et a
	la souris : on touche une carte pour la choisir, le bouton du bas pour
	l'acheter, la croix en haut pour fermer (choisi avec Josh le 15 novembre
	2026 : le jeu doit se jouer au telephone).

	Une vraie boutique : des cartes avec l'image de l'objet (ItemThumb), un
	halo et un degrade a la couleur de sa rarete, son nom et son prix ; une
	barre du bas qui detaille l'objet choisi et son bouton d'achat ; la
	vitrine 3D le montre en grand (ShopShowcase). Onglets : la boutique du
	jour et les permanents, le tirage (avec TOUTES les chances affichees
	avant d'acheter), le passe, les defis, ses cosmetiques, les credits en
	Robux. Le serveur verifie tout (ShopService).
]]

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Royale = ReplicatedStorage:WaitForChild("Royale")
local Config = require(Royale:WaitForChild("Config"))

local ButtonIcons = require(script.Parent.ButtonIcons)
local ItemThumb = require(script.Parent.ItemThumb)
local UiKit = require(script.Parent.UiKit)

local ShopView = {}

-- Ceux qui veulent savoir quel objet est choisi (la vitrine) : (id, ouvert).
local watchers: { (id: string?, open: boolean) -> () } = {}
function ShopView.onPreview(fn: (id: string?, open: boolean) -> ())
	table.insert(watchers, fn)
end
local function announce(id: string?, open: boolean)
	for _, fn in watchers do
		task.spawn(fn, id, open)
	end
end

-- Ouvre ou ferme la boutique (le bouton tactile du salon) ; branche par start.
local toggler: (() -> ())? = nil
function ShopView.toggle()
	if toggler then
		toggler()
	end
end

local CO = Config.cosmetics
local SH = Config.shop
local UI = SH.ui
local PA = Config.pass
local V = Config.view
local K = Config.controls.contexts.shopPanel
local LANTERN = Config.lobby.colors.lantern
local TABS = { "Boutique", "Tirage", "Passe", "Défis", "Mes cosmétiques", "Crédits" }
-- Ce que dit le bouton d'achat pour chaque action.
local VERBS = {
	buy = "Acheter",
	drawFragments = "Tirer",
	drawCredits = "Tirer",
	equip = "Porter",
	pass = "Débloquer",
	pack = "Acheter",
}

-- Une carte (un objet, une monnaie) ou une ligne (une action, un defi).
type Entry = {
	key: string,
	id: string?,
	currency: string?,
	title: string,
	sub: string?,
	badge: string?,
	-- Le prix montre avec son icone (credits, fragments) ou en Robux.
	price: number?,
	priceKind: string?,
	owned: boolean?,
	action: string?,
	arg: any?,
	progress: number?,
}
type Section = { title: string?, kind: string, entries: { Entry } }

local rgb = UiKit.rgb
local round = UiKit.round
local label = UiKit.label

local function decode(value: any): any
	if typeof(value) ~= "string" then
		return nil
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(value)
	end)
	return if ok then data else nil
end

local function percent(x: number, decimals: number): string
	return (string.gsub(string.format("%." .. decimals .. "f", x * 100), "%.", ",")) .. " %"
end

local function rarityOf(id: string?): any
	local def = id and CO.items[id]
	return def and Config.rarities[def.rarity]
end

local function rarityColor(id: string?): Color3
	local r = rarityOf(id)
	return if r then rgb(r.color) else rgb(LANTERN)
end

function ShopView.start()
	local player = Players.LocalPlayer
	local remote =
		Royale:WaitForChild(Config.remotes.folder):WaitForChild(Config.remotes.shop) :: RemoteEvent
	local text = rgb(Config.lobby.hud.text)
	local dim = rgb(UI.dimText)

	local gui = Instance.new("ScreenGui")
	gui.Name = "RoyaleBoutique"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = SH.displayOrder
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Le panneau, a gauche : la vitrine se montre a droite. Une taille fixe,
	-- puis une echelle qui la fait tenir dans l'ecran (en part de l'ecran,
	-- une petite fenetre donnait des cartes geantes, vu en image).
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.Position = UDim2.fromScale(UI.left, 0.5)
	panel.Size = UDim2.fromOffset(UI.designWidth, UI.designHeight)
	panel.BackgroundColor3 = Color3.new(1, 1, 1)
	panel.BackgroundTransparency = UI.panelTransparency
	panel.Parent = gui
	round(panel, UI.corner + 6)
	UiKit.gradient(panel, rgb(UI.panelTop), rgb(UI.panelBottom), 0.35)
	UiKit.stroke(panel, rgb(LANTERN), 2, 0.35)
	-- Un second filet, a l'interieur : le cadre d'une vitrine.
	local inner = Instance.new("Frame")
	inner.BackgroundTransparency = 1
	inner.Position = UDim2.fromOffset(UI.innerFrame, UI.innerFrame)
	inner.Size = UDim2.new(1, -2 * UI.innerFrame, 1, -2 * UI.innerFrame)
	inner.Parent = panel
	round(inner, UI.corner + 2)
	UiKit.stroke(inner, rgb(LANTERN), 1, 0.82)

	-- L'en-tete : le titre, le porte-monnaie, la croix ; puis les onglets.
	local titleY = UI.pad
	local title = label(panel, "BOUTIQUE", UI.titleSize, V.font, rgb(LANTERN))
	title.Position = UDim2.fromOffset(UI.pad, titleY)
	title.Size = UDim2.fromOffset(UI.designWidth / 2, UI.titleSize + 6)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local closeButton = UiKit.button(panel, "Fermer")
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -UI.pad, 0, titleY + (UI.titleSize + 6 - UI.closeSize) / 2)
	closeButton.Size = UDim2.fromOffset(UI.closeSize, UI.closeSize)
	closeButton.BackgroundColor3 = rgb(UI.card)
	round(closeButton, UI.closeSize)
	UiKit.stroke(closeButton, rgb(LANTERN), 1.5, 0.4)
	-- La croix, en deux traits (la police n'a pas le signe, vu en image).
	for _, angle in { 45, -45 } do
		local bar = Instance.new("Frame")
		bar.BorderSizePixel = 0
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.new(0.5, 0, 0, 3)
		bar.Rotation = angle
		bar.BackgroundColor3 = text
		round(bar, 2)
		bar.Parent = closeButton
	end
	local wallet = Instance.new("Frame")
	wallet.BackgroundTransparency = 1
	wallet.AnchorPoint = Vector2.new(1, 0)
	wallet.Position = UDim2.new(1, -(UI.pad + UI.closeSize + 12), 0, titleY + 3)
	wallet.Size = UDim2.fromOffset(UI.designWidth / 2, UI.titleSize)
	wallet.Parent = panel
	local walletList = Instance.new("UIListLayout")
	walletList.FillDirection = Enum.FillDirection.Horizontal
	walletList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	walletList.VerticalAlignment = Enum.VerticalAlignment.Center
	walletList.Padding = UDim.new(0, 10)
	walletList.Parent = wallet
	local function purse(order: number): Frame
		local pill = Instance.new("Frame")
		pill.LayoutOrder = order
		pill.AutomaticSize = Enum.AutomaticSize.X
		pill.Size = UDim2.fromOffset(0, UI.titleSize - 4)
		pill.BackgroundColor3 = rgb(UI.card)
		round(pill, UI.titleSize)
		UiKit.stroke(pill, rgb(LANTERN), 1, 0.7)
		local p = Instance.new("UIPadding")
		p.PaddingLeft = UDim.new(0, 8)
		p.PaddingRight = UDim.new(0, 12)
		p.Parent = pill
		pill.Parent = wallet
		return pill
	end
	local creditPurse, fragmentPurse = purse(1), purse(2)

	-- Un trait qui s'efface aux deux bouts, sous le titre.
	local divider = Instance.new("Frame")
	divider.BorderSizePixel = 0
	divider.Position = UDim2.fromOffset(UI.pad, titleY + UI.titleSize + 12)
	divider.Size = UDim2.new(1, -2 * UI.pad, 0, 1)
	divider.BackgroundColor3 = rgb(LANTERN)
	divider.Parent = panel
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.4),
		NumberSequenceKeypoint.new(0.8, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = divider

	local tabsY = titleY + UI.titleSize + 20
	local tabsRow = Instance.new("Frame")
	tabsRow.BackgroundTransparency = 1
	tabsRow.Position = UDim2.fromOffset(UI.pad, tabsY)
	tabsRow.Size = UDim2.new(1, -2 * UI.pad, 0, UI.tabHeight)
	tabsRow.Parent = panel
	local tabsList = Instance.new("UIListLayout")
	tabsList.FillDirection = Enum.FillDirection.Horizontal
	tabsList.Padding = UDim.new(0, 6)
	tabsList.VerticalAlignment = Enum.VerticalAlignment.Center
	tabsList.SortOrder = Enum.SortOrder.LayoutOrder
	tabsList.Parent = tabsRow
	local tabButtons: { TextButton } = {}
	local tabChips: { Frame } = {}
	table.insert(tabChips, ButtonIcons.chip(tabsRow, K.previousTab, "", 26, UI.smallSize, 0))
	for i, name in TABS do
		local b = UiKit.button(tabsRow, "Onglet" .. i)
		b.LayoutOrder = i
		b.AutomaticSize = Enum.AutomaticSize.X
		b.Size = UDim2.fromOffset(0, UI.tabHeight)
		b.BackgroundColor3 = rgb(UI.card)
		b.BackgroundTransparency = 1
		round(b, UI.tabHeight)
		local t = label(b, name, UI.tabTextSize, V.bodyBoldFont, dim)
		t.Name = "Texte"
		t.TextWrapped = false
		t.AutomaticSize = Enum.AutomaticSize.X
		t.Size = UDim2.fromScale(0, 1)
		local p = Instance.new("UIPadding")
		p.PaddingLeft = UDim.new(0, 14)
		p.PaddingRight = UDim.new(0, 14)
		p.Parent = b
		tabButtons[i] = b
	end
	table.insert(tabChips, ButtonIcons.chip(tabsRow, K.nextTab, "", 26, UI.smallSize, #TABS + 1))

	-- Le contenu, qui defile (au doigt aussi).
	local bodyY = tabsY + UI.tabHeight + 10
	local bottomY = UI.detailHeight + UI.footHeight + UI.pad
	local body = Instance.new("ScrollingFrame")
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.fromOffset(UI.pad - 4, bodyY)
	body.Size = UDim2.new(1, -2 * UI.pad + 8, 1, -(bodyY + bottomY))
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.ScrollBarThickness = 5
	body.ScrollBarImageColor3 = rgb(LANTERN)
	body.ScrollingDirection = Enum.ScrollingDirection.Y
	body.Parent = panel
	local bodyList = Instance.new("UIListLayout")
	bodyList.Padding = UDim.new(0, 10)
	bodyList.SortOrder = Enum.SortOrder.LayoutOrder
	bodyList.Parent = body
	local bodyPad = Instance.new("UIPadding")
	bodyPad.PaddingTop = UDim.new(0, 6)
	bodyPad.PaddingBottom = UDim.new(0, 10)
	bodyPad.PaddingLeft = UDim.new(0, 4)
	bodyPad.PaddingRight = UDim.new(0, 10)
	bodyPad.Parent = body

	-- La barre du detail : l'objet choisi, sa rarete, son bouton d'achat.
	local detail = Instance.new("Frame")
	detail.AnchorPoint = Vector2.new(0, 1)
	detail.Position = UDim2.new(0, UI.pad, 1, -(UI.footHeight + UI.pad / 2))
	detail.Size = UDim2.new(1, -2 * UI.pad, 0, UI.detailHeight)
	detail.BackgroundColor3 = rgb(UI.card)
	detail.Parent = panel
	round(detail, UI.corner)
	local detailStroke = UiKit.stroke(detail, rgb(LANTERN), 1.5, 0.5)
	local detailGradient = UiKit.gradient(detail, rgb(UI.card), rgb(UI.panelBottom), 0.5)
	detailGradient.Rotation = 0
	local detailName = label(detail, "", UI.detailTitleSize, V.font, text)
	detailName.Position = UDim2.fromOffset(16, 10)
	detailName.Size = UDim2.new(0.6, -16, 0, UI.detailTitleSize + 4)
	detailName.TextXAlignment = Enum.TextXAlignment.Left
	detailName.TextTruncate = Enum.TextTruncate.AtEnd
	detailName.TextWrapped = false
	local detailSub = label(detail, "", UI.smallSize, V.bodyFont, dim)
	detailSub.Position = UDim2.fromOffset(16, UI.detailTitleSize + 16)
	detailSub.Size = UDim2.new(0.6, -16, 0, UI.smallSize + 4)
	detailSub.TextXAlignment = Enum.TextXAlignment.Left
	detailSub.TextTruncate = Enum.TextTruncate.AtEnd
	detailSub.TextWrapped = false
	local buy = UiKit.button(detail, "Acheter")
	buy.AnchorPoint = Vector2.new(1, 0.5)
	buy.Position = UDim2.new(1, -12, 0.5, 0)
	buy.AutomaticSize = Enum.AutomaticSize.X
	buy.Size = UDim2.fromOffset(UI.buyMinWidth, UI.detailHeight - 22)
	buy.BackgroundColor3 = rgb(LANTERN)
	round(buy, UI.corner)
	local buyPad = Instance.new("UIPadding")
	buyPad.PaddingLeft = UDim.new(0, 14)
	buyPad.PaddingRight = UDim.new(0, 18)
	buyPad.Parent = buy
	local buyList = Instance.new("UIListLayout")
	buyList.FillDirection = Enum.FillDirection.Horizontal
	buyList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	buyList.VerticalAlignment = Enum.VerticalAlignment.Center
	buyList.Padding = UDim.new(0, 8)
	buyList.SortOrder = Enum.SortOrder.LayoutOrder
	buyList.Parent = buy
	local buyIcon: Frame? = nil
	local buyText = label(buy, "", UI.textSize, V.bodyBoldFont, rgb(UI.buyText))
	buyText.LayoutOrder = 2
	buyText.TextWrapped = false
	buyText.AutomaticSize = Enum.AutomaticSize.X
	buyText.Size = UDim2.fromOffset(0, UI.detailHeight - 22)
	local buyScale = Instance.new("UIScale")
	buyScale.Parent = buy

	-- Le pied : les boutons de la manette (ou, au doigt, ce qu'on peut toucher).
	local foot = Instance.new("Frame")
	foot.BackgroundTransparency = 1
	foot.AnchorPoint = Vector2.new(0, 1)
	foot.Position = UDim2.new(0, UI.pad, 1, -UI.pad / 2)
	foot.Size = UDim2.new(1, -2 * UI.pad, 0, UI.footHeight - 4)
	foot.Parent = panel
	local footList = Instance.new("UIListLayout")
	footList.FillDirection = Enum.FillDirection.Horizontal
	footList.Padding = UDim.new(0, 18)
	footList.VerticalAlignment = Enum.VerticalAlignment.Center
	footList.SortOrder = Enum.SortOrder.LayoutOrder
	footList.Parent = foot

	-- Sur un petit ecran, le panneau rapetisse.
	local fit = Instance.new("UIScale")
	fit.Parent = panel

	local tab, open = 1, false
	local selectedKey: string? = nil
	type Pick =
		{ key: string, frame: GuiObject, button: TextButton, entry: Entry, stroke: UIStroke }
	local picks: { Pick } = {}
	local act: (key: string) -> () = function() end
	local selectKey: (key: string) -> () = function() end
	local switchTab: (to: number) -> () = function() end

	-- Ce que montre chaque onglet, d'apres ce que le serveur publie.
	local function sections(): { Section }
		local world = decode(workspace:GetAttribute(SH.worldAttribute)) or {}
		local me = decode(player:GetAttribute(SH.playerAttribute)) or {}
		local owned = me.owned or {}
		local equipped = me.equipped or {}
		local credits = player:GetAttribute(Config.progression.attributes.credits) or 0
		local fragments = player:GetAttribute(Config.progression.attributes.fragments) or 0
		local name = TABS[tab]
		local out: { Section } = {}
		local function itemCard(id: string, prefix: string, action: string?): Entry
			local def = CO.items[id]
			local price = CO.prices[def.rarity]
			return {
				key = prefix .. id,
				id = id,
				title = def.name,
				sub = CO.slotNames[def.slot],
				badge = if owned[id] then "À toi" else string.format("%d crédits", price),
				price = if owned[id] then nil else price,
				priceKind = "credits",
				owned = owned[id] == true,
				action = if owned[id] then nil else action,
				arg = id,
			}
		end
		if name == "Boutique" then
			local today: { Entry } = {}
			for _, id in world.daily or {} do
				table.insert(today, itemCard(id, "jour:", "buy"))
			end
			-- Elle change a minuit (UTC) : le temps qui reste.
			local left = SH.dayLength - os.time() % SH.dayLength
			table.insert(out, {
				title = string.format(
					"Aujourd'hui — nouveaux objets dans %d h %02d",
					left // 3600,
					left % 3600 // 60
				),
				kind = "cards",
				entries = today,
			})
			local always: { Entry } = {}
			for _, id in SH.permanent do
				table.insert(always, itemCard(id, "toujours:", "buy"))
			end
			table.insert(out, { title = "Toujours là", kind = "cards", entries = always })
		elseif name == "Tirage" then
			local draws: { Entry } = {
				{
					key = "tirage:fragments",
					currency = "fragments",
					title = "Tirage gratuit",
					sub = string.format(
						"%d fragments (tu en as %d)",
						Config.progression.fragments.perDraw,
						fragments
					),
					price = Config.progression.fragments.perDraw,
					priceKind = "fragments",
					action = "drawFragments",
				},
			}
			if me.restricted then
				table.insert(draws, {
					key = "tirage:credits",
					currency = "credits",
					title = "Tirage en crédits",
					sub = "Pas disponible pour toi",
				})
			else
				table.insert(draws, {
					key = "tirage:credits",
					currency = "credits",
					title = "Tirage",
					sub = string.format("%d crédits (tu en as %d)", world.drawPrice or 0, credits),
					price = world.drawPrice or 0,
					priceKind = "credits",
					action = "drawCredits",
				})
			end
			table.insert(
				out,
				{ title = "Un objet à chaque tirage", kind = "cards", entries = draws }
			)
			-- TOUTES les chances, avant d'acheter, par rarete (deux decimales :
			-- avec plus de cent objets, « 1 % » arrondissait 0,71 %).
			local chances = world.chances or {}
			for _, rarity in { "legendary", "epic", "rare", "common" } do
				local ids: { string } = {}
				local part = 0
				for id, chance in chances do
					if CO.items[id] and CO.items[id].rarity == rarity then
						table.insert(ids, id)
						part += chance
					end
				end
				if #ids > 0 then
					table.sort(ids, function(x, y)
						return CO.items[x].name < CO.items[y].name
					end)
					local chips: { Entry } = {}
					for _, id in ids do
						table.insert(chips, {
							key = "chance:" .. id,
							id = id,
							title = CO.items[id].name,
							badge = percent(chances[id], 2)
								.. (if owned[id] then " · à toi" else ""),
						})
					end
					local info = Config.rarities[rarity]
					table.insert(out, {
						title = string.format(
							"%s — %s en tout",
							info and info.name or rarity,
							percent(part, 0)
						),
						kind = "chips",
						entries = chips,
					})
				end
			end
		elseif name == "Passe" then
			local tier = me.tier or 0
			local rows: { Entry } = {
				{
					key = "passe:etat",
					title = string.format(
						"Saison %d — palier %d / %d",
						PA.season,
						tier,
						PA.tiers
					),
					sub = string.format("%d XP de passe", me.passXp or 0),
					progress = tier / PA.tiers,
				},
			}
			if me.premium then
				table.insert(rows, {
					key = "passe:premium",
					title = "Passe premium débloqué",
					sub = "Un objet unique à chaque palier",
				})
			elseif PA.premiumProductId ~= 0 then
				table.insert(rows, {
					key = "passe:premium",
					title = "Débloquer le passe premium",
					sub = string.format(
						"%d Robux — un objet unique à chaque palier",
						PA.premiumRobux
					),
					action = "pass",
				})
			end
			table.insert(out, { kind = "rows", entries = rows })
			for _, track in
				{
					{ PA.free, "Voie gratuite", "gratuit" },
					{ PA.premium, "Voie premium", "premium" },
				}
			do
				local cards: { Entry } = {}
				for t = tier + 1, PA.tiers do
					local reward = track[1][t]
					if reward and #cards < SH.passPreview then
						if reward.item then
							table.insert(cards, {
								key = track[3] .. ":" .. t,
								id = reward.item,
								title = CO.items[reward.item].name,
								sub = CO.slotNames[CO.items[reward.item].slot],
								badge = "Palier " .. t,
							})
						else
							table.insert(cards, {
								key = track[3] .. ":" .. t,
								currency = "credits",
								title = string.format("%d crédits", reward.credits),
								badge = "Palier " .. t,
							})
						end
					end
				end
				if #cards > 0 then
					table.insert(out, {
						title = track[2] .. " — prochains paliers",
						kind = "cards",
						entries = cards,
					})
				end
			end
		elseif name == "Défis" then
			local defis = decode(player:GetAttribute(Config.challenges.attribute)) or {}
			for _, part in
				{
					{ "Aujourd'hui", defis.daily, "jour" },
					{ "Cette semaine", defis.weekly, "semaine" },
				}
			do
				local rows: { Entry } = {}
				for i, c in part[2] or {} do
					table.insert(rows, {
						key = part[3] .. ":" .. i,
						title = (if c.done then "✓ " else "") .. c.text,
						sub = string.format("%d / %d", c.progress, c.goal),
						progress = c.progress / math.max(1, c.goal),
					})
				end
				table.insert(out, { title = part[1], kind = "rows", entries = rows })
			end
		elseif name == "Mes cosmétiques" then
			for _, slot in CO.slots do
				local cards: { Entry } = {}
				local ids: { string } = {}
				for id in owned do
					if CO.items[id] and CO.items[id].slot == slot then
						table.insert(ids, id)
					end
				end
				table.sort(ids, function(x, y)
					return CO.items[x].name < CO.items[y].name
				end)
				for _, id in ids do
					table.insert(cards, {
						key = "mien:" .. id,
						id = id,
						title = CO.items[id].name,
						badge = if equipped[slot] == id then "Porté" else "Pas porté",
						owned = true,
						action = "equip",
						arg = id,
					})
				end
				if #cards > 0 then
					table.insert(
						out,
						{ title = CO.slotNames[slot], kind = "cards", entries = cards }
					)
				end
			end
			if #out == 0 then
				table.insert(out, {
					kind = "rows",
					entries = {
						{
							key = "rien",
							title = "Rien encore",
							sub = "Achète, tire, monte le passe ou reviens chaque jour.",
						},
					},
				})
			end
		else
			local packs: { Entry } = {}
			for i, pack in SH.creditPacks do
				if pack.productId ~= 0 then
					table.insert(packs, {
						key = "paquet:" .. i,
						currency = "credits",
						title = string.format("%d crédits", pack.credits),
						badge = string.format("%d Robux", pack.robux),
						price = pack.robux,
						priceKind = "robux",
						action = "pack",
						arg = i,
					})
				end
			end
			table.insert(out, {
				title = "Des crédits en Robux — tout se gagne aussi en jouant",
				kind = "cards",
				entries = packs,
			})
		end
		return out
	end

	-- Le prix d'une carte, centre en bas : l'icone et le nombre, « a toi »,
	-- ou ce que dit son badge (un palier du passe).
	local function priceLine(parent: Instance, e: Entry)
		local holder = Instance.new("Frame")
		holder.Name = "Prix"
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0, 1)
		holder.Position = UDim2.new(0, 0, 1, -2)
		holder.Size = UDim2.new(1, 0, 0, UI.cardFoot - 2)
		holder.ZIndex = 3
		holder.Parent = parent
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.Parent = holder
		if e.owned then
			local worn = e.badge == "Porté"
			local t = label(
				holder,
				if worn then "✓ Porté" elseif e.action == "equip" then "À toi" else "✓ À toi",
				UI.smallSize,
				V.bodyBoldFont,
				if worn or e.action ~= "equip" then rgb(UI.owned) else dim
			)
			t.AutomaticSize = Enum.AutomaticSize.X
			t.Size = UDim2.fromScale(0, 1)
			t.TextWrapped = false
		elseif e.price and e.priceKind ~= "robux" then
			UiKit.amount(
				holder,
				e.priceKind or "credits",
				tostring(e.price),
				UI.smallSize + 1,
				V.bodyBoldFont,
				text
			)
		else
			local t =
				label(holder, e.badge or e.sub or "", UI.smallSize, V.bodyBoldFont, rgb(LANTERN))
			t.AutomaticSize = Enum.AutomaticSize.X
			t.Size = UDim2.fromScale(0, 1)
			t.TextWrapped = false
		end
	end

	-- Une carte : la rarete, l'image sur son halo, le nom, le prix. La case de
	-- la grille reste fixe ; la carte dedans grossit quand on la choisit.
	local function card(parent: Instance, e: Entry, order: number): (Frame, TextButton, UIStroke)
		local cell = Instance.new("Frame")
		cell.Name = e.key
		cell.LayoutOrder = order
		cell.BackgroundTransparency = 1
		local color = if e.id then rarityColor(e.id) else rgb(LANTERN)
		local b = UiKit.button(cell, "Carte")
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position = UDim2.fromScale(0.5, 0.5)
		b.Size = UDim2.new(1, -2 * UI.cardInset, 1, -2 * UI.cardInset)
		b.BackgroundColor3 = Color3.new(1, 1, 1)
		b.ClipsDescendants = true
		round(b, UI.corner)
		UiKit.gradient(b, rgb(UI.card):Lerp(color, UI.cardTint), rgb(UI.cardBottom), 0.55)
		local s = UiKit.stroke(b, color, 1.5, 0.45)
		local imageTop = UI.tagSize + 8
		UiKit.glow(
			b,
			UDim2.new(0.5, 0, 0, imageTop + UI.cardImage / 2),
			UI.cardImage * UI.glowSize,
			color,
			UI.glowStrength
		)
		local view = Instance.new("ViewportFrame")
		view.Name = "Image"
		view.BackgroundTransparency = 1
		view.AnchorPoint = Vector2.new(0.5, 0)
		view.Position = UDim2.new(0.5, 0, 0, imageTop)
		view.Size = UDim2.fromOffset(UI.cardImage, UI.cardImage)
		view.ZIndex = 2
		view.Parent = b
		if e.id then
			ItemThumb.item(view, e.id)
		elseif e.currency then
			ItemThumb.currency(view, e.currency)
		end
		local r = rarityOf(e.id)
		if r then
			local tag = label(b, UiKit.upper(r.name), UI.tagSize, V.bodyBoldFont, color)
			tag.Position = UDim2.fromOffset(10, 5)
			tag.Size = UDim2.new(1, -20, 0, UI.tagSize + 2)
			tag.TextXAlignment = Enum.TextXAlignment.Left
			tag.ZIndex = 3
		end
		local name = label(b, e.title, UI.smallSize, V.bodyBoldFont, text)
		name.Position = UDim2.fromOffset(8, imageTop + UI.cardImage + 2)
		name.Size = UDim2.new(1, -16, 0, UI.smallSize * 2 + 4)
		name.TextYAlignment = Enum.TextYAlignment.Top
		name.ZIndex = 3
		-- Un filet au-dessus du prix.
		local line = Instance.new("Frame")
		line.BorderSizePixel = 0
		line.AnchorPoint = Vector2.new(0.5, 1)
		line.Position = UDim2.new(0.5, 0, 1, -UI.cardFoot)
		line.Size = UDim2.new(1, -24, 0, 1)
		line.BackgroundColor3 = color
		line.BackgroundTransparency = 0.7
		line.ZIndex = 3
		line.Parent = b
		priceLine(b, e)
		cell.Parent = parent
		return cell, b, s
	end

	-- Une ligne : l'etat du passe, un defi, avec sa jauge.
	local function row(parent: Instance, e: Entry, order: number): (Frame, TextButton, UIStroke)
		local holder = Instance.new("Frame")
		holder.Name = e.key
		holder.LayoutOrder = order
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.new(1, 0, 0, UI.rowHeight)
		local b = UiKit.button(holder, "Ligne")
		b.Size = UDim2.fromScale(1, 1)
		b.BackgroundColor3 = Color3.new(1, 1, 1)
		round(b, UI.corner)
		local g = UiKit.gradient(b, rgb(UI.card), rgb(UI.cardBottom), 0.6)
		g.Rotation = 0
		local s = UiKit.stroke(b, rgb(LANTERN), 1.5, 0.6)
		local accent = Instance.new("Frame")
		accent.BorderSizePixel = 0
		accent.Position = UDim2.fromOffset(8, 10)
		accent.Size = UDim2.new(0, 4, 1, -20)
		accent.BackgroundColor3 = if e.progress and e.progress >= 1
			then rgb(UI.owned)
			else rgb(LANTERN)
		round(accent, 2)
		accent.Parent = b
		local left = 22
		local t = label(b, e.title, UI.textSize, V.bodyBoldFont, text)
		t.Position = UDim2.fromOffset(left, 9)
		t.Size = UDim2.new(if e.progress then 0.62 else 1, -left - 12, 0, UI.textSize + 2)
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.TextTruncate = Enum.TextTruncate.AtEnd
		t.TextWrapped = false
		if e.sub then
			local sub = label(b, e.sub, UI.smallSize, V.bodyFont, dim)
			sub.Position = UDim2.fromOffset(left, UI.textSize + 14)
			sub.Size = UDim2.new(0.62, -left - 12, 0, UI.smallSize + 2)
			sub.TextXAlignment = Enum.TextXAlignment.Left
		end
		if e.progress then
			local track = Instance.new("Frame")
			track.AnchorPoint = Vector2.new(1, 0.5)
			track.Position = UDim2.new(1, -16, 0.5, 0)
			track.Size = UDim2.new(0.34, 0, 0, 10)
			track.BackgroundColor3 = Color3.new(0, 0, 0)
			track.BackgroundTransparency = 0.35
			round(track, 5)
			track.Parent = b
			local fill = Instance.new("Frame")
			fill.Size = UDim2.fromScale(math.clamp(e.progress, 0, 1), 1)
			fill.BackgroundColor3 = if e.progress >= 1 then rgb(UI.owned) else rgb(LANTERN)
			round(fill, 5)
			fill.Parent = track
			UiKit.gradient(fill, Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200), 0.5)
		end
		holder.Parent = parent
		return holder, b, s
	end

	-- Une pastille de chance (le tirage) : un filet, le nom a la couleur de sa
	-- rarete, sa chance.
	local function chip(parent: Instance, e: Entry, order: number)
		local f = Instance.new("Frame")
		f.LayoutOrder = order
		f.BackgroundColor3 = rgb(UI.card)
		round(f, 8)
		local strip = Instance.new("Frame")
		strip.BorderSizePixel = 0
		strip.Position = UDim2.fromOffset(5, 6)
		strip.Size = UDim2.new(0, 3, 1, -12)
		strip.BackgroundColor3 = rarityColor(e.id)
		round(strip, 2)
		strip.Parent = f
		local n = label(f, e.title, UI.smallSize - 1, V.bodyBoldFont, rarityColor(e.id))
		n.Position = UDim2.fromOffset(14, 0)
		n.Size = UDim2.new(0.62, -14, 1, 0)
		n.TextXAlignment = Enum.TextXAlignment.Left
		n.TextTruncate = Enum.TextTruncate.AtEnd
		n.TextWrapped = false
		local p = label(f, e.badge or "", UI.smallSize - 1, V.bodyFont, text)
		p.AnchorPoint = Vector2.new(1, 0)
		p.Position = UDim2.new(1, -8, 0, 0)
		p.Size = UDim2.fromScale(0.38, 1)
		p.TextXAlignment = Enum.TextXAlignment.Right
		f.Parent = parent
	end

	-- Ce qui manque pour payer (0 si on peut).
	local function missing(e: Entry): number
		if e.price == nil or e.priceKind == "robux" then
			return 0
		end
		local A = Config.progression.attributes
		local have =
			player:GetAttribute(if e.priceKind == "fragments" then A.fragments else A.credits)
		return math.max(0, e.price - (if typeof(have) == "number" then have else 0))
	end

	-- La barre du bas : l'objet choisi et son bouton.
	local function showDetail(e: Entry?)
		if buyIcon then
			buyIcon:Destroy()
			buyIcon = nil
		end
		if e == nil then
			detailName.Text = ""
			detailSub.Text = if ButtonIcons.touch()
				then "Touche un objet pour le voir"
				else "Choisis un objet avec la croix"
			buy.Visible = false
			return
		end
		local r = rarityOf(e.id)
		detailName.Text = e.title
		detailName.TextColor3 = if e.id then rarityColor(e.id) else text
		local bits: { string } = {}
		if r then
			table.insert(bits, r.name)
		end
		if e.id then
			table.insert(bits, CO.slotNames[CO.items[e.id].slot])
		elseif e.sub then
			table.insert(bits, e.sub)
		end
		detailSub.Text = table.concat(bits, " · ")
		detailStroke.Color = if e.id then rarityColor(e.id) else rgb(LANTERN)
		buy.Visible = e.action ~= nil or e.owned == true
		if e.action == nil then
			buy.BackgroundColor3 = rgb(UI.card)
			buyText.TextColor3 = rgb(UI.owned)
			buyText.Text = "✓ Déjà à toi"
			return
		end
		local short = missing(e)
		if short > 0 then
			buy.BackgroundColor3 = rgb(UI.card)
			buyText.TextColor3 = dim
			buyText.Text = string.format(
				"Il te manque %d %s",
				short,
				if e.priceKind == "fragments" then "fragments" else "crédits"
			)
			return
		end
		buy.BackgroundColor3 = rgb(LANTERN)
		buyText.TextColor3 = rgb(UI.buyText)
		if not ButtonIcons.touch() then
			buyIcon = ButtonIcons.chip(buy, K.confirm, "", UI.buyIcon, UI.smallSize, 1)
		end
		local verb = if e.action == "equip" and e.badge == "Porté"
			then "Retirer"
			else VERBS[e.action]
		if e.price and e.priceKind == "robux" then
			buyText.Text = string.format("%s · %d Robux", verb, e.price)
		elseif e.price then
			buyText.Text = string.format(
				"%s · %d %s",
				verb,
				e.price,
				if e.priceKind == "fragments" then "fragments" else "crédits"
			)
		else
			buyText.Text = verb or "Choisir"
		end
	end

	local function highlight()
		local chosen: Pick? = nil
		for _, p in picks do
			local on = p.key == selectedKey
			p.stroke.Thickness = if on then 3 else 1.5
			p.stroke.Transparency = if on then 0 else 0.45
			if on then
				p.stroke.Color = rgb(LANTERN)
				chosen = p
			else
				p.stroke.Color = if p.entry.id then rarityColor(p.entry.id) else rgb(LANTERN)
			end
			if p.button.Name == "Carte" then
				UiKit.tween(p.button, UI.selectSeconds, {
					Size = if on
						then UDim2.fromScale(1, 1)
						else UDim2.new(1, -2 * UI.cardInset, 1, -2 * UI.cardInset),
				})
			end
			local view = p.button:FindFirstChild("Image")
			if view and view:IsA("ViewportFrame") then
				ItemThumb.spin(view, on)
			end
		end
		showDetail(if chosen then chosen.entry else nil)
		announce(if chosen then chosen.entry.id else nil, true)
		-- La carte choisie reste a l'ecran.
		if chosen then
			local top = chosen.frame.AbsolutePosition.Y
				- body.AbsolutePosition.Y
				+ body.CanvasPosition.Y
			local bottom = top + chosen.frame.AbsoluteSize.Y
			if top < body.CanvasPosition.Y then
				body.CanvasPosition = Vector2.new(0, math.max(0, top - 30))
			elseif bottom > body.CanvasPosition.Y + body.AbsoluteSize.Y then
				body.CanvasPosition = Vector2.new(0, bottom - body.AbsoluteSize.Y + 20)
			end
		end
	end

	-- Le panneau tient dans l'ecran : sa part de largeur et de hauteur. Au
	-- telephone, l'echelle rendrait le texte illisible : il prend presque
	-- toute la largeur, sous la barre de Roblox, et raccourcit (on defile).
	local function refit()
		local camera = workspace.CurrentCamera
		if camera == nil then
			return
		end
		local size = camera.ViewportSize
		local scale = math.min(
			size.X * UI.width / UI.designWidth,
			size.Y * UI.height / UI.designHeight,
			UI.maxScale
		)
		if scale >= UI.minScale then
			fit.Scale = scale
			panel.AnchorPoint = Vector2.new(0, 0.5)
			panel.Position = UDim2.fromScale(UI.left, 0.5)
			panel.Size = UDim2.fromOffset(UI.designWidth, UI.designHeight)
			return
		end
		local top = GuiService:GetGuiInset().Y
		scale = math.min(size.X * UI.smallWidth / UI.designWidth, UI.minScale)
		fit.Scale = scale
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Position = UDim2.new(0.5, 0, 0.5, top / 2)
		panel.Size = UDim2.fromOffset(
			UI.designWidth,
			math.min(UI.designHeight, (size.Y - top) * UI.smallHeight / scale)
		)
	end

	local function render()
		for _, c in body:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		table.clear(picks)
		local A = Config.progression.attributes
		for _, purseInfo in
			{
				{ creditPurse, "credits", player:GetAttribute(A.credits) },
				{ fragmentPurse, "fragments", player:GetAttribute(A.fragments) },
			}
		do
			local pill, kind, value = purseInfo[1], purseInfo[2], purseInfo[3]
			for _, c in pill:GetChildren() do
				if c:IsA("GuiObject") then
					c:Destroy()
				end
			end
			UiKit.amount(
				pill,
				kind,
				tostring(if typeof(value) == "number" then value else 0),
				UI.textSize,
				V.bodyBoldFont,
				text
			).Size =
				UDim2.fromScale(0, 1)
		end
		for i, b in tabButtons do
			local on = i == tab
			b.BackgroundTransparency = if on then 0 else 1
			b.BackgroundColor3 = rgb(LANTERN)
			local t = b:FindFirstChild("Texte") :: TextLabel
			t.TextColor3 = if on then rgb(UI.buyText) else dim
		end
		local touch = ButtonIcons.touch()
		for _, c in tabChips do
			c.Visible = not touch
		end
		local order = 0
		for _, sec in sections() do
			order += 1
			if sec.title then
				local h = Instance.new("Frame")
				h.LayoutOrder = order
				h.BackgroundTransparency = 1
				h.Size = UDim2.new(1, 0, 0, UI.textSize + 8)
				h.Parent = body
				local mark = Instance.new("Frame")
				mark.BorderSizePixel = 0
				mark.AnchorPoint = Vector2.new(0, 0.5)
				mark.Position = UDim2.new(0, 2, 0.5, 0)
				mark.Size = UDim2.fromOffset(8, 8)
				mark.Rotation = 45
				mark.BackgroundColor3 = rgb(LANTERN)
				mark.Parent = h
				local t = label(h, sec.title, UI.textSize, V.font, rgb(LANTERN))
				t.Position = UDim2.fromOffset(18, 0)
				t.Size = UDim2.new(1, -18, 1, 0)
				t.TextXAlignment = Enum.TextXAlignment.Left
				t.TextWrapped = false
				order += 1
			end
			local holder = Instance.new("Frame")
			holder.LayoutOrder = order
			holder.BackgroundTransparency = 1
			holder.Size = UDim2.fromScale(1, 0)
			holder.AutomaticSize = Enum.AutomaticSize.Y
			holder.Parent = body
			if sec.kind == "rows" then
				local l = Instance.new("UIListLayout")
				l.Padding = UDim.new(0, 8)
				l.SortOrder = Enum.SortOrder.LayoutOrder
				l.Parent = holder
			else
				local grid = Instance.new("UIGridLayout")
				grid.CellPadding = UDim2.fromOffset(UI.gap, UI.gap)
				grid.CellSize = if sec.kind == "chips"
					then UDim2.fromOffset(UI.chipWidth, UI.chipHeight)
					else UDim2.fromOffset(UI.cardWidth, UI.cardHeight)
				grid.SortOrder = Enum.SortOrder.LayoutOrder
				grid.Parent = holder
			end
			for j, e in sec.entries do
				if sec.kind == "chips" then
					chip(holder, e, j)
				else
					local f: Frame, b: TextButton, s: UIStroke
					if sec.kind == "rows" then
						f, b, s = row(holder, e, j)
					else
						f, b, s = card(holder, e, j)
					end
					-- Choisissable : ce qui a une action, et tout objet (pour le voir
					-- en vitrine).
					if e.action or e.id then
						table.insert(
							picks,
							{ key = e.key, frame = f, button = b, entry = e, stroke = s }
						)
						-- Au doigt ou a la souris : un premier toucher choisit, un second
						-- achete (comme le bouton du bas).
						b.Activated:Connect(function()
							if selectedKey == e.key then
								act(e.key)
							else
								selectKey(e.key)
							end
						end)
					end
				end
			end
		end
		local found = false
		for _, p in picks do
			if p.key == selectedKey then
				found = true
			end
		end
		if not found then
			selectedKey = if picks[1] then picks[1].key else nil
		end
		task.defer(highlight)
		refit()
	end

	selectKey = function(key: string)
		selectedKey = key
		highlight()
	end

	act = function(key: string)
		for _, p in picks do
			if p.key == key and p.entry.action and missing(p.entry) == 0 then
				remote:FireServer(p.entry.action, p.entry.arg)
				UiKit.pop(buyScale, UI.popFrom, 1, UI.selectSeconds * 2)
			end
		end
	end

	switchTab = function(to: number)
		tab = (to - 1) % #TABS + 1
		selectedKey = nil
		body.CanvasPosition = Vector2.zero
		render()
	end

	-- La croix : la carte la plus proche dans cette direction (a l'ecran).
	local function move(dx: number, dy: number)
		local from: Pick? = nil
		for _, p in picks do
			if p.key == selectedKey then
				from = p
			end
		end
		if from == nil then
			return
		end
		local here = from.frame.AbsolutePosition + from.frame.AbsoluteSize / 2
		local best, bestScore = nil, math.huge
		for _, p in picks do
			if p ~= from then
				local there = p.frame.AbsolutePosition + p.frame.AbsoluteSize / 2
				local d = there - here
				local along = d.X * dx + d.Y * dy
				if along > 4 then
					local across = math.abs(d.X * dy) + math.abs(d.Y * dx)
					local score = along + across * 2
					if score < bestScore then
						best, bestScore = p, score
					end
				end
			end
		end
		if best then
			selectKey(best.key)
		end
	end

	local function close()
		open = false
		gui.Enabled = false
		announce(nil, false)
		for _, name in
			{
				"RoyaleBoutiqueCroix",
				"RoyaleBoutiqueOnglet",
				"RoyaleBoutiqueA",
				"RoyaleBoutiqueFermer",
			}
		do
			ContextActionService:UnbindAction(name)
		end
	end

	-- Les touches (manette et clavier) de ces actions, a plat : une fonction
	-- qui rend deux valeurs n'en donne qu'une au milieu d'une liste
	-- d'arguments (seule la manette etait branchee, vu en jeu).
	local function keys(...: { gamepad: string, keyboard: string }): { Enum.KeyCode }
		local out = {}
		for _, b in { ... } do
			table.insert(out, Enum.KeyCode[b.gamepad])
			table.insert(out, Enum.KeyCode[b.keyboard])
		end
		return out
	end

	local function openShop()
		open = true
		gui.Enabled = true
		tab = 1
		selectedKey = nil
		local priority = Enum.ContextActionPriority.High.Value + 1
		ContextActionService:BindActionAtPriority(
			"RoyaleBoutiqueCroix",
			function(_, state: Enum.UserInputState, input: InputObject)
				if state == Enum.UserInputState.Begin then
					local k = input.KeyCode
					local function is(b: { gamepad: string, keyboard: string }): boolean
						return k == Enum.KeyCode[b.gamepad] or k == Enum.KeyCode[b.keyboard]
					end
					if is(K.up) then
						move(0, -1)
					elseif is(K.down) then
						move(0, 1)
					elseif is(K.left) then
						move(-1, 0)
					elseif is(K.right) then
						move(1, 0)
					end
				end
				return Enum.ContextActionResult.Sink
			end,
			false,
			priority,
			table.unpack(keys(K.up, K.down, K.left, K.right))
		)
		ContextActionService:BindActionAtPriority(
			"RoyaleBoutiqueOnglet",
			function(_, state: Enum.UserInputState, input: InputObject)
				if state == Enum.UserInputState.Begin then
					local forward = input.KeyCode == Enum.KeyCode[K.nextTab.gamepad]
						or input.KeyCode == Enum.KeyCode[K.nextTab.keyboard]
					switchTab(tab + (if forward then 1 else -1))
				end
				return Enum.ContextActionResult.Sink
			end,
			false,
			priority,
			table.unpack(keys(K.nextTab, K.previousTab))
		)
		ContextActionService:BindActionAtPriority(
			"RoyaleBoutiqueA",
			function(_, state: Enum.UserInputState)
				if state == Enum.UserInputState.Begin and selectedKey then
					act(selectedKey)
				end
				return Enum.ContextActionResult.Sink
			end,
			false,
			priority,
			table.unpack(keys(K.confirm))
		)
		ContextActionService:BindActionAtPriority(
			"RoyaleBoutiqueFermer",
			function(_, state: Enum.UserInputState)
				if state == Enum.UserInputState.Begin then
					close()
				end
				return Enum.ContextActionResult.Sink
			end,
			false,
			priority,
			table.unpack(keys(K.close))
		)
		-- Le pied : les boutons, avec l'icone de la manette ; au doigt, une phrase.
		for _, c in foot:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		if ButtonIcons.touch() then
			local hint = label(
				foot,
				"Touche un objet pour le voir, encore une fois pour l'acheter. Glisse pour défiler.",
				UI.smallSize,
				V.bodyFont,
				dim
			)
			hint.Size = UDim2.fromScale(1, 1)
			hint.TextXAlignment = Enum.TextXAlignment.Left
		else
			ButtonIcons.chip(foot, K.confirm, "Acheter / porter", 26, UI.smallSize, 1)
			ButtonIcons.chip(foot, K.nextTab, "Onglets", 26, UI.smallSize, 2)
			ButtonIcons.chip(foot, K.close, "Fermer", 26, UI.smallSize, 3)
		end
		render()
	end

	toggler = function()
		if open then
			close()
		elseif player:GetAttribute(Config.match.aliveAttribute) == nil then
			openShop()
		end
	end

	-- Au doigt et a la souris : les onglets, la croix, le bouton d'achat.
	for i, b in tabButtons do
		b.Activated:Connect(function()
			switchTab(i)
		end)
	end
	closeButton.Activated:Connect(close)
	buy.Activated:Connect(function()
		if selectedKey then
			act(selectedKey)
		end
	end)

	local shopKey = Config.controls.contexts.lobby.shop
	ContextActionService:BindActionAtPriority(
		"RoyaleBoutique",
		function(_, state: Enum.UserInputState)
			if state ~= Enum.UserInputState.Begin then
				return Enum.ContextActionResult.Pass
			end
			-- Seulement au salon (pas participant d'une partie).
			if player:GetAttribute(Config.match.aliveAttribute) ~= nil then
				return Enum.ContextActionResult.Pass
			end
			toggler()
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode[shopKey.gamepad],
		Enum.KeyCode[shopKey.keyboard]
	)

	-- X devant le comptoir de l'echoppe du salon ouvre aussi la boutique.
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		if prompt.Name == SH.stallPrompt and not open then
			openShop()
		end
	end)

	-- Ce que le serveur change (achat, credits) se voit tout de suite.
	RunService.Heartbeat:Connect(function()
		if open and player:GetAttribute(Config.match.aliveAttribute) ~= nil then
			close()
		end
	end)
	for _, attribute in
		{
			Config.challenges.attribute,
			SH.playerAttribute,
			Config.progression.attributes.credits,
			Config.progression.attributes.fragments,
		}
	do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			if open then
				render()
			end
		end)
	end
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(refit)
	end
end

return ShopView
