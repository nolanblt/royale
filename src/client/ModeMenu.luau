--!strict
--[[
	ModeMenu — le menu du mode et de la partie, au centre de l'ecran (Josh,
	le 18 novembre 2026 : « Y ouvre un menu au centre, on choisit le mode ;
	la, on ne voit pas que ca change en haut »).

	Deux listes : le mode (solo, duo, escouade) et la partie (publique,
	privee avec ou sans bots). Le choix en cours est coche. A la manette, la
	croix monte et descend, A prend la ligne, B ou Y ferme ; au doigt et a
	la souris, on touche la ligne. Le serveur verifie (seul le chef du
	groupe choisit) : l'ecran ne decide rien.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Royale = ReplicatedStorage:WaitForChild("Royale")
local Config = require(Royale:WaitForChild("Config"))

local ButtonIcons = require(script.Parent.ButtonIcons)
local UiKit = require(script.Parent.UiKit)

local ModeMenu = {}

local LB = Config.lobby
local MM = LB.modeMenu
local K = Config.controls.contexts.modeMenu
local KL = Config.controls.contexts.lobby
local rgb = UiKit.rgb

local isOpen = false
local toggleImpl: () -> () = function() end

function ModeMenu.toggle()
	toggleImpl()
end

function ModeMenu.open(): boolean
	return isOpen
end

type Entry = { kind: string, value: string, label: string }

function ModeMenu.start()
	local player = Players.LocalPlayer
	local remote =
		Royale:WaitForChild(Config.remotes.folder):WaitForChild(Config.remotes.lobby) :: RemoteEvent
	local H = LB.hud
	local lantern = rgb(LB.colors.lantern)

	local entries: { Entry } = {}
	for _, m in LB.modes do
		table.insert(entries, { kind = "mode", value = m, label = LB.modeNames[m] or m })
	end
	for _, p in LB.privacies do
		table.insert(entries, { kind = "privacy", value = p, label = LB.privacyNames[p] or p })
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "RoyaleMenuMode"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = MM.displayOrder
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Le fond assombri : le menu se voit, et se ferme au doigt a cote.
	local veil = UiKit.button(gui, "Voile")
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.new(0, 0, 0)
	veil.BackgroundTransparency = MM.veil

	local rows = #entries + 2
	local height = MM.titleHeight + rows * (MM.rowHeight + MM.gap) + MM.footHeight + MM.pad * 2
	local panel = Instance.new("Frame")
	panel.Name = "Menu"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(MM.width, height)
	panel.BackgroundColor3 = rgb(H.background)
	panel.BackgroundTransparency = 0.05
	panel.Parent = gui
	UiKit.round(panel, H.corner + 4)
	UiKit.stroke(panel, lantern, 2, 0.2)
	UiKit.gradient(panel, rgb({ 46, 30, 24 }), rgb(H.background), 0.4)
	-- Sur un petit ecran, le menu retrecit pour tenir.
	local fit = Instance.new("UIScale")
	fit.Parent = panel
	local function refit()
		local camera = workspace.CurrentCamera
		if camera then
			local view = camera.ViewportSize
			fit.Scale = math.min(1, view.X * 0.92 / MM.width, view.Y * 0.9 / height)
		end
	end

	local title = UiKit.label(panel, "CHOISIS TA PARTIE", MM.titleSize, Config.view.font, lantern)
	title.Size = UDim2.new(1, 0, 0, MM.titleHeight)
	title.Position = UDim2.fromOffset(0, MM.pad)

	type Row = {
		entry: Entry,
		button: TextButton,
		text: TextLabel,
		mark: TextLabel,
		stroke: UIStroke,
	}
	local rowList: { Row } = {}
	local y = MM.pad + MM.titleHeight
	local lastKind = ""
	local function section(name: string)
		local s = UiKit.label(panel, name, MM.sectionSize, Config.view.bodyBoldFont, rgb(H.text))
		s.TextTransparency = 0.35
		s.TextXAlignment = Enum.TextXAlignment.Left
		s.Size = UDim2.new(1, -2 * MM.pad, 0, MM.rowHeight)
		s.Position = UDim2.fromOffset(MM.pad, y)
		y += MM.rowHeight + MM.gap
	end
	for _, e in entries do
		if e.kind ~= lastKind then
			lastKind = e.kind
			section(if e.kind == "mode" then "MODE" else "PARTIE")
		end
		local b = UiKit.button(panel, "Ligne_" .. e.value)
		b.Size = UDim2.new(1, -2 * MM.pad, 0, MM.rowHeight)
		b.Position = UDim2.fromOffset(MM.pad, y)
		b.BackgroundColor3 = rgb({ 38, 29, 25 })
		UiKit.round(b, H.corner)
		local stroke = UiKit.stroke(b, lantern, 1.5, 0.7)
		local t = UiKit.label(b, e.label, MM.rowSize, Config.view.bodyBoldFont, rgb(H.text))
		t.Size = UDim2.new(1, -60, 1, 0)
		t.Position = UDim2.fromOffset(16, 0)
		t.TextXAlignment = Enum.TextXAlignment.Left
		local mark = UiKit.label(b, "✓", MM.rowSize, Config.view.bodyBoldFont, rgb(H.ready))
		mark.Size = UDim2.new(0, 40, 1, 0)
		mark.Position = UDim2.new(1, -48, 0, 0)
		table.insert(rowList, { entry = e, button = b, text = t, mark = mark, stroke = stroke })
		y += MM.rowHeight + MM.gap
	end
	local foot = UiKit.label(panel, "", MM.sectionSize, Config.view.bodyFont, rgb(H.text))
	foot.TextTransparency = 0.25
	foot.Size = UDim2.new(1, -2 * MM.pad, 0, MM.footHeight)
	foot.Position = UDim2.fromOffset(MM.pad, y + MM.gap)

	local cursor = 1

	local function pick(e: Entry)
		remote:FireServer(e.kind, e.value)
	end

	local function paint()
		local mode = player:GetAttribute(LB.modeAttribute)
		local privacy = player:GetAttribute(LB.privacyAttribute)
		local pad = not ButtonIcons.touch()
		for i, r in rowList do
			local chosen = (r.entry.kind == "mode" and r.entry.value == mode)
				or (r.entry.kind == "privacy" and r.entry.value == privacy)
			r.mark.Visible = chosen
			local on = pad and i == cursor
			r.stroke.Transparency = if on then 0 else 0.7
			r.stroke.Thickness = if on then 3 else 1.5
			r.button.BackgroundColor3 = if on then rgb({ 70, 44, 24 }) else rgb({ 38, 29, 25 })
		end
		foot.Text = if ButtonIcons.touch()
			then "Touche une ligne pour la choisir"
			else string.format(
				"%s choisir · %s fermer",
				ButtonIcons.name(K.pick),
				ButtonIcons.name(K.close)
			)
	end

	local function close()
		if not isOpen then
			return
		end
		isOpen = false
		gui.Enabled = false
		for _, name in { "RoyaleMenuModeHaut", "RoyaleMenuModeChoix", "RoyaleMenuModeFermer" } do
			ContextActionService:UnbindAction(name)
		end
	end

	local function keys(...: { gamepad: string, keyboard: string }): { Enum.KeyCode }
		local out: { Enum.KeyCode } = {}
		for _, b in { ... } do
			table.insert(out, (Enum.KeyCode :: any)[b.gamepad])
			table.insert(out, (Enum.KeyCode :: any)[b.keyboard])
		end
		return out
	end

	local function openMenu()
		isOpen = true
		gui.Enabled = true
		refit()
		-- Le curseur part sur le mode en cours.
		local mode = player:GetAttribute(LB.modeAttribute)
		for i, r in rowList do
			if r.entry.kind == "mode" and r.entry.value == mode then
				cursor = i
			end
		end
		local priority = Enum.ContextActionPriority.High.Value + MM.priorityAbove
		ContextActionService:BindActionAtPriority("RoyaleMenuModeHaut", function(_, state, input)
			if state == Enum.UserInputState.Begin then
				local up = input.KeyCode == Enum.KeyCode[K.up.gamepad]
					or input.KeyCode == Enum.KeyCode[K.up.keyboard]
				cursor = (cursor - 1 + (if up then -1 else 1)) % #rowList + 1
				paint()
			end
			return Enum.ContextActionResult.Sink
		end, false, priority, table.unpack(keys(K.up, K.down)))
		ContextActionService:BindActionAtPriority("RoyaleMenuModeChoix", function(_, state)
			if state == Enum.UserInputState.Begin then
				pick(rowList[cursor].entry)
			end
			return Enum.ContextActionResult.Sink
		end, false, priority, table.unpack(keys(K.pick)))
		ContextActionService:BindActionAtPriority("RoyaleMenuModeFermer", function(_, state)
			if state == Enum.UserInputState.Begin then
				close()
			end
			return Enum.ContextActionResult.Sink
		end, false, priority, table.unpack(keys(K.close, KL.mode)))
		paint()
	end

	toggleImpl = function()
		if isOpen then
			close()
		else
			openMenu()
		end
	end

	for _, r in rowList do
		r.button.Activated:Connect(function()
			pick(r.entry)
		end)
	end
	veil.Activated:Connect(close)
	for _, attribute in { LB.modeAttribute, LB.privacyAttribute } do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			if isOpen then
				paint()
			end
		end)
	end
	-- Hors du salon (une partie part), le menu se ferme.
	RunService.Heartbeat:Connect(function()
		if isOpen and player:GetAttribute(Config.match.aliveAttribute) ~= nil then
			close()
		end
	end)
end

return ModeMenu
