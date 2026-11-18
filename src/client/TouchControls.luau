--!strict
--[[
	TouchControls — les boutons au doigt, au telephone et a la tablette
	(choisi avec Josh le 15 novembre 2026 : « rendre le jeu jouable
	facilement et sympa sur telephone »).

	Le stick (gauche) et le saut (droite) restent ceux de Roblox ; on regarde
	en glissant le doigt. Peu de boutons (Josh, le 16 novembre 2026 : il y en
	avait trop), comme les jeux Roblox au telephone : un gros bouton d'action
	qui dit ce qu'il fait selon ce qu'on tient (Frapper, Utiliser, Lancer :
	maintenu on vise, lache on lance), Accroupi (en courant : glisser ;
	maintenu : ramper), Courir (bascule), et Pousser seulement quand
	quelqu'un est a portee. On choisit ce qu'on tient en touchant sa place
	dans le sac (ItemView). Cache, Frapper devient Jaillir et Pousser devient
	Sortir ; en portant, Jeter et Poser. En haut a droite : la carte, le
	signal (deux touches : danger), l'emote. Elimine : la rangee du
	spectateur.

	Chaque bouton lance l'action du jeu par InputBus, comme le bouton de
	manette qu'il remplace : aucune regle n'est recopiee ici.
	Les boutons n'apparaissent qu'au doigt (ButtonIcons.touch) : une manette
	branchee au telephone les cache.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Royale = ReplicatedStorage:WaitForChild("Royale")
local Bag = require(Royale:WaitForChild("Bag"))
local Config = require(Royale:WaitForChild("Config"))

local ButtonIcons = require(script.Parent.ButtonIcons)
local InputBus = require(script.Parent.InputBus)
local Spectate = require(script.Parent.Spectate)
local UiKit = require(script.Parent.UiKit)

local TouchControls = {}

local T = Config.touch
local F = Config.controls.contexts.onFoot
local HC = Config.controls.contexts.hidden
local S = Config.controls.contexts.spectating
local H = Config.lobby.hud
local sewerName = Config.hiding.displayNames[Config.hiding.sewer.name]
local LANTERN = Config.lobby.colors.lantern

local rgb = UiKit.rgb

type Button = {
	frame: TextButton,
	text: TextLabel,
	scale: UIScale,
	stroke: UIStroke,
	-- L'action et le bouton de manette qu'il remplace (d'apres la situation).
	action: string,
	gamepad: string?,
	held: InputObject?,
}

function TouchControls.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "RoyaleTactile"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = T.displayOrder
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local buttons: { [string]: Button } = {}
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude

	-- Un rond (ou une pastille) a la facon du jeu : sombre, cerne de lanterne.
	local function make(id: string, pill: boolean): Button
		local b = UiKit.button(gui, id)
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.BackgroundColor3 = rgb(H.background)
		b.BackgroundTransparency = H.transparency
		b.Active = true
		UiKit.round(b, if pill then T.pillHeight else 999)
		local stroke = UiKit.stroke(b, rgb(LANTERN), 2, H.strokeTransparency)
		local text = UiKit.label(b, "", T.textMax, Config.view.bodyBoldFont, rgb(H.text))
		text.Size = UDim2.fromScale(0.9, 0.9)
		text.Position = UDim2.fromScale(0.05, 0.05)
		text.TextScaled = true
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = T.textMax
		limit.Parent = text
		local scale = Instance.new("UIScale")
		scale.Parent = b
		local button: Button = {
			frame = b,
			text = text,
			scale = scale,
			stroke = stroke,
			action = "",
			gamepad = nil,
			held = nil,
		}
		-- Appuyer, puis relacher : le relachement compte meme si le doigt a
		-- glisse hors du bouton (on le suit jusqu'a ce qu'il se leve).
		b.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType ~= Enum.UserInputType.Touch and not ButtonIcons.touch() then
				return
			end
			if button.held then
				return
			end
			button.held = input
			scale.Scale = T.pressedScale
			InputBus.fire(button.action, Enum.UserInputState.Begin, button.gamepad)
		end)
		buttons[id] = button
		return button
	end
	UserInputService.InputEnded:Connect(function(input: InputObject)
		for _, button in buttons do
			if button.held == input then
				button.held = nil
				button.scale.Scale = 1
				InputBus.fire(button.action, Enum.UserInputState.End, button.gamepad)
			end
		end
	end)

	-- L'arc autour du saut.
	for id in T.layout do
		make(id, false)
	end
	-- La colonne du haut, et la rangee du spectateur.
	local smallOrder = { "map", "signal", "emote" }
	for _, id in smallOrder do
		make(id, false)
	end
	local pillOrder = { "watchPrevious", "bet", "watchNext", "quit" }
	for _, id in pillOrder do
		make(id, true)
	end

	-- L'objet tenu (la place choisie du sac), ou rien aux mains nues.
	local function heldItem(): any
		local text = player:GetAttribute(Config.bag.attribute)
		local bag = Bag.decode(if typeof(text) == "string" then text else "", Config.bag.slots)
		local sel = player:GetAttribute(Config.bag.selectedAttribute)
		return if typeof(sel) == "number" then Config.items[bag[sel]] else nil
	end

	-- Quelqu'un (joueur, bot, Repris) a portee de poussee devant soi : sinon
	-- le bouton Pousser n'a rien a faire a l'ecran.
	local function someoneInReach(): boolean
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root == nil or not root:IsA("BasePart") then
			return false
		end
		local reach = Config.touch.shoveShowRange
		for _, part in workspace:GetPartBoundsInRadius(root.Position, reach, overlap) do
			local model = part:FindFirstAncestorOfClass("Model")
			if
				model
				and model ~= character
				and model:FindFirstChildOfClass("Humanoid")
				and part.Name == "HumanoidRootPart"
			then
				return true
			end
		end
		return false
	end

	-- Ce que fait chaque bouton dans la situation : action, bouton de manette
	-- remplace, texte. Rien (nil) : cache.
	type Role = { action: string, gamepad: string?, text: string }
	local function roles(): { [string]: Role }
		local out: { [string]: Role } = {}
		local phase = workspace:GetAttribute(Config.match.phaseAttribute)
		local alive = player:GetAttribute(Config.match.aliveAttribute)
		local inBelly = player:GetAttribute(Config.goulag.stateAttribute) ~= nil
		if Spectate.watching() then
			out.watchPrevious =
				{ action = "RoyaleRegarder", gamepad = S.previousPlayer.gamepad, text = "<" }
			out.watchNext =
				{ action = "RoyaleRegarder", gamepad = S.nextPlayer.gamepad, text = ">" }
			out.bet = { action = "RoyaleParier", gamepad = S.bet.gamepad, text = "Parier" }
			out.quit = { action = "RoyaleQuitter", gamepad = S.leave.gamepad, text = "Quitter" }
			return out
		end
		if inBelly then
			-- Au Ventre, en duel : frapper et s'accroupir (le saut est a Roblox).
			out.hit = { action = "RoyaleFrapper", gamepad = F.hit.gamepad, text = "Frapper" }
			out.posture =
				{ action = "RoyalePosture", gamepad = F.posture.gamepad, text = "Accroupi" }
			return out
		end
		if phase ~= "Partie" or alive ~= true then
			return out
		end
		local hidden = player:GetAttribute(Config.hiding.hiddenAttribute) ~= nil
		local carrying = player:GetAttribute(Config.combat.carryingAttribute) ~= nil
		out.map = { action = "RoyaleCarte", gamepad = F.map.gamepad, text = "Carte" }
		out.signal = { action = "RoyaleSignal", gamepad = F.signal.gamepad, text = "Signal" }
		-- Le gros bouton dit ce qu'il fera : l'objet tenu, sinon frapper.
		local held = heldItem()
		local action = if held == nil
			then "Frapper"
			elseif held.kind == "throw" then "Lancer"
			else "Utiliser"
		if hidden then
			out.hit = {
				action = "RoyaleFrapper",
				gamepad = HC.burstOut.gamepad,
				text = if held then action else "Jaillir",
			}
			out.shove = { action = "RoyaleSortir", gamepad = HC.leave.gamepad, text = "Sortir" }
			-- Dans un egout : choisir la plaque ou ressortir (SewerView).
			if player:GetAttribute(Config.hiding.hiddenAttribute) == sewerName then
				out.watchPrevious = {
					action = "RoyaleEgoutChoix",
					gamepad = HC.previousExit.gamepad,
					text = "‹",
				}
				out.watchNext =
					{ action = "RoyaleEgoutChoix", gamepad = HC.nextExit.gamepad, text = "›" }
			end
			return out
		end
		out.emote = { action = "RoyaleEmote", gamepad = F.emote.gamepad, text = "Emote" }
		out.hit = { action = "RoyaleFrapper", gamepad = F.hit.gamepad, text = action }
		out.sprint = { action = "RoyaleCourir", gamepad = F.sprint.gamepad, text = "Courir" }
		if carrying then
			out.shove = { action = "RoyalePousser", gamepad = F.shove.gamepad, text = "Jeter" }
			out.posture = { action = "RoyalePosture", gamepad = F.posture.gamepad, text = "Poser" }
		else
			if someoneInReach() then
				out.shove =
					{ action = "RoyalePousser", gamepad = F.shove.gamepad, text = "Pousser" }
			end
			out.posture =
				{ action = "RoyalePosture", gamepad = F.posture.gamepad, text = "Accroupi" }
		end
		return out
	end

	-- Le bouton de saut de Roblox : son centre et sa taille a l'ecran.
	local function jump(): (Vector2, number)
		local touchGui = player.PlayerGui:FindFirstChild("TouchGui")
		local jumpButton = touchGui and touchGui:FindFirstChild("JumpButton", true)
		if jumpButton and jumpButton:IsA("GuiObject") and jumpButton.AbsoluteSize.X > 0 then
			-- Ses mesures partent sous la barre de Roblox si son ecran ne
			-- l'ignore pas ; les notres partent du haut de l'ecran.
			local shift = if (touchGui :: ScreenGui).IgnoreGuiInset
				then Vector2.zero
				else GuiService:GetGuiInset()
			return jumpButton.AbsolutePosition + jumpButton.AbsoluteSize / 2 + shift,
				jumpButton.AbsoluteSize.X
		end
		local camera = workspace.CurrentCamera
		local size = if camera then camera.ViewportSize else Vector2.new(800, 400)
		return size - Vector2.new(T.fallbackCenter[1], T.fallbackCenter[2]), T.fallbackJump
	end

	local function place()
		local center, unit = jump()
		for id, spot in T.layout do
			local a = math.rad(spot.angle)
			local b = buttons[id].frame
			b.Position = UDim2.fromOffset(
				center.X + math.cos(a) * spot.ring * unit,
				center.Y - math.sin(a) * spot.ring * unit
			)
			b.Size = UDim2.fromOffset(spot.size * unit, spot.size * unit)
		end
		local camera = workspace.CurrentCamera
		local view = if camera then camera.ViewportSize else Vector2.new(800, 400)
		local top = GuiService:GetGuiInset().Y + T.margin
		-- En rangee, de droite a gauche : en colonne, ils descendaient sur
		-- l'arc (vu en image sur un ecran de telephone).
		for i, id in smallOrder do
			local b = buttons[id].frame
			b.Size = UDim2.fromOffset(T.small, T.small)
			b.Position = UDim2.fromOffset(
				view.X - T.margin - T.small / 2 - (i - 1) * (T.small + T.smallGap),
				top + T.small / 2
			)
		end
		local widths =
			{ T.pillHeight * 1.4, T.pillHeight * 2.4, T.pillHeight * 1.4, T.pillHeight * 2.4 }
		local total = (#pillOrder - 1) * T.pillGap
		for _, w in widths do
			total += w
		end
		local x = view.X / 2 - total / 2
		for i, id in pillOrder do
			local b = buttons[id].frame
			b.Size = UDim2.fromOffset(widths[i], T.pillHeight)
			b.Position = UDim2.fromOffset(x + widths[i] / 2, view.Y - T.pillBottom)
			x += widths[i] + T.pillGap
		end
	end

	local running = false
	RunService.RenderStepped:Connect(function()
		local show = ButtonIcons.touch()
		gui.Enabled = show
		if not show then
			return
		end
		place()
		local current = roles()
		for id, button in buttons do
			local role = current[id]
			button.frame.Visible = role ~= nil
			if role then
				-- Un bouton maintenu garde son action jusqu'au relachement (sinon
				-- « viser » commencerait sur une action et finirait sur une autre).
				if button.held == nil then
					button.action = role.action
					button.gamepad = role.gamepad
				end
				button.text.Text = role.text
			elseif button.held then
				button.held = nil
				button.scale.Scale = 1
			end
		end
		-- Courir est une bascule : allume, il se remplit.
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		running = humanoid ~= nil and humanoid.WalkSpeed >= Config.movement.runSpeed
		local sprint = buttons.sprint
		sprint.frame.BackgroundColor3 = if running then rgb(LANTERN) else rgb(H.background)
		sprint.text.TextColor3 = if running then rgb(H.background) else rgb(H.text)
	end)
end

return TouchControls
