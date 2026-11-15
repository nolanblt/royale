--!strict
--[[
	UiKit — les briques communes de la boutique et des recompenses du jour
	(choisi avec Josh le 15 novembre 2026 : « rends ca encore plus beau »).
	Un seul endroit pour le style : fond en degrade, halo derriere une image,
	la piece des credits, le cristal des fragments, le bouton tactile.
	Toutes les mesures arrivent de Config.shop.ui.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Royale = ReplicatedStorage:WaitForChild("Royale")
local Config = require(Royale:WaitForChild("Config"))

local UiKit = {}

local UI = Config.shop.ui

function UiKit.rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end
local rgb = UiKit.rgb

-- En capitales, accents compris (string.upper laisse « é » en minuscule :
-- « LéGENDAIRE », vu en image).
function UiKit.upper(s: string): string
	local out = string.upper(s)
	for low, up in
		{ ["é"] = "É", ["è"] = "È", ["ê"] = "Ê", ["à"] = "À", ["ç"] = "Ç", ["ô"] = "Ô" }
	do
		out = string.gsub(out, low, up)
	end
	return out
end

function UiKit.round(f: GuiObject, px: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = f
end

function UiKit.stroke(
	f: GuiObject,
	color: Color3,
	thickness: number,
	transparency: number
): UIStroke
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency
	s.Parent = f
	return s
end

-- Un degrade vertical de `top` a `bottom` (le haut colore, le bas sombre).
function UiKit.gradient(f: GuiObject, top: Color3, bottom: Color3, at: number?): UIGradient
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	local mid = math.clamp(at or 0.5, 0.01, 0.99)
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, top),
		ColorSequenceKeypoint.new(mid, top:Lerp(bottom, 0.7)),
		ColorSequenceKeypoint.new(1, bottom),
	})
	g.Parent = f
	return g
end

function UiKit.label(
	parent: Instance,
	text: string,
	size: number,
	font: string,
	color: Color3
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = (Enum.Font :: any)[font]
	l.TextSize = size
	l.TextColor3 = color
	l.TextWrapped = true
	l.Text = text
	l.Parent = parent
	return l
end

-- Un bouton sans texte ni couleur automatique : il porte ce qu'on y pose.
-- Au doigt et a la souris, il se touche ; a la manette, la croix choisit.
function UiKit.button(parent: Instance, name: string): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.AutoButtonColor = false
	b.Text = ""
	b.BorderSizePixel = 0
	b.Selectable = false
	b.Parent = parent
	return b
end

-- Un halo doux derriere une image : des disques de plus en plus grands et
-- transparents (un degrade de Roblox est lineaire, pas rond).
function UiKit.glow(
	parent: Instance,
	center: UDim2,
	diameter: number,
	color: Color3,
	strength: number
)
	local holder = Instance.new("Frame")
	holder.Name = "Halo"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = center
	holder.Size = UDim2.fromOffset(diameter, diameter)
	holder.ZIndex = 1
	holder.Parent = parent
	for i = 1, UI.glowRings do
		local k = i / UI.glowRings
		local disc = Instance.new("Frame")
		disc.BorderSizePixel = 0
		disc.AnchorPoint = Vector2.new(0.5, 0.5)
		disc.Position = UDim2.fromScale(0.5, 0.5)
		disc.Size = UDim2.fromScale(k, k)
		disc.BackgroundColor3 = color
		disc.BackgroundTransparency = 1 - strength / UI.glowRings
		disc.ZIndex = 1
		UiKit.round(disc, diameter)
		disc.Parent = holder
	end
	return holder
end

-- La piece des credits, dessinee (nette a toute taille, pas une image 3D).
function UiKit.coin(parent: Instance, size: number): Frame
	local coin = Instance.new("Frame")
	coin.Name = "Piece"
	coin.Size = UDim2.fromOffset(size, size)
	coin.BackgroundColor3 = rgb(UI.coin)
	UiKit.round(coin, size)
	UiKit.stroke(coin, rgb(UI.coinEdge), math.max(1, size / 10), 0)
	local inner = Instance.new("Frame")
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromScale(0.5, 0.5)
	inner.BackgroundColor3 = rgb(UI.coinEdge)
	inner.BackgroundTransparency = 0.5
	UiKit.round(inner, size)
	inner.Parent = coin
	coin.Parent = parent
	return coin
end

-- Le cristal des fragments : un losange violet.
function UiKit.crystal(parent: Instance, size: number): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Cristal"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(size, size)
	local gem = Instance.new("Frame")
	gem.AnchorPoint = Vector2.new(0.5, 0.5)
	gem.Position = UDim2.fromScale(0.5, 0.5)
	gem.Size = UDim2.fromScale(0.68, 0.68)
	gem.Rotation = 45
	gem.BackgroundColor3 = rgb(UI.fragment)
	UiKit.round(gem, math.max(2, size / 8))
	UiKit.stroke(gem, rgb(UI.fragmentEdge), math.max(1, size / 12), 0)
	gem.Parent = holder
	holder.Parent = parent
	return holder
end

-- Une ligne d'icone et de texte (le prix, le porte-monnaie).
function UiKit.amount(
	parent: Instance,
	kind: string,
	text: string,
	size: number,
	font: string,
	color: Color3
): Frame
	local row = Instance.new("Frame")
	row.Name = "Montant"
	row.BackgroundTransparency = 1
	row.AutomaticSize = Enum.AutomaticSize.X
	row.Size = UDim2.fromOffset(0, size + 4)
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, math.floor(size / 3))
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row
	local icon = if kind == "fragments" then UiKit.crystal(row, size) else UiKit.coin(row, size)
	icon.LayoutOrder = 1
	local t = UiKit.label(row, text, size, font, color)
	t.LayoutOrder = 2
	t.TextWrapped = false
	t.AutomaticSize = Enum.AutomaticSize.X
	t.Size = UDim2.fromOffset(0, size + 4)
	row.Parent = parent
	return row
end

-- Un petit rebond : l'element grossit puis revient (achat, recompense).
function UiKit.pop(scale: UIScale, from: number, to: number, seconds: number)
	scale.Scale = from
	TweenService:Create(
		scale,
		TweenInfo.new(seconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = to }
	):Play()
end

function UiKit.tween(object: Instance, seconds: number, goal: { [string]: any })
	TweenService
		:Create(
			object,
			TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			goal
		)
		:Play()
end

return UiKit
