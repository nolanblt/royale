--!strict
--[[
	ItemView — le sac a l'ecran et ce que les objets montrent.

	- En bas : les 4 places (CONCEPT.md : pas de panneau de sac), la place
	  choisie encadree, sa couleur de rarete. L1 / R1 pour choisir.
	- L2 : un objet a lancer se vise tant qu'on tient (le trait de l'arc), et
	  part au lacher ; les autres servent a l'appui.
	- Les effets : lancers des autres, ebloui, joueurs reveles (Jumelles, Oeil
	  de verre), grappin, Regard vole, clochettes, relique, messages.

	Rien ne se decide ici : le serveur publie, l'ecran montre.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Royale = ReplicatedStorage:WaitForChild("Royale")
local ActionAnim = require(Royale:WaitForChild("Effets"):WaitForChild("ActionAnim"))
local Bag = require(Royale:WaitForChild("Bag"))
local ItemModels = require(Royale:WaitForChild("Effets"):WaitForChild("ItemModels"))
local ItemShapes = require(Royale:WaitForChild("ItemShapes"))
local Config = require(Royale:WaitForChild("Config"))

local ButtonIcons = require(script.Parent.ButtonIcons)
local InputBus = require(script.Parent.InputBus)
local UiKit = require(script.Parent.UiKit)
local Throw = require(Royale:WaitForChild("Throw"))

local ItemView = {}

-- Branches par start ; avant, rien n'est tenu.
ItemView.holding = function(): boolean
	return false
end
ItemView.useHeld = function(_state: Enum.UserInputState) end

local BG = Config.bag
local T = Config.throw
local I = Config.items
local FX = Config.effects
local V = Config.view
local onFoot = Config.controls.contexts.onFoot
local hiddenCtx = Config.controls.contexts.hidden

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function keys(binding: { gamepad: string, keyboard: string }): { any }
	local out: { any } = {}
	for _, name in { binding.gamepad, binding.keyboard } do
		local ok, code = pcall(function()
			return (Enum.KeyCode :: any)[name]
		end)
		table.insert(out, if ok and code then code else (Enum.UserInputType :: any)[name])
	end
	return out
end

local function merged(list: { { gamepad: string, keyboard: string } }): { any }
	local seen: { [any]: boolean } = {}
	local out: { any } = {}
	for _, binding in list do
		for _, k in keys(binding) do
			if not seen[k] then
				seen[k] = true
				table.insert(out, k)
			end
		end
	end
	return out
end

local function active(instance: Instance, attribute: string): number?
	local untilT = instance:GetAttribute(attribute)
	if typeof(untilT) == "number" then
		local left = untilT - workspace:GetServerTimeNow()
		if left > 0 then
			return left
		end
	end
	return nil
end

-- « texte|heure » : le texte, s'il date de moins de `seconds`.
local function recent(value: any, seconds: number): string?
	if typeof(value) ~= "string" then
		return nil
	end
	local text, at = string.match(value, "^(.*)|([%d%.]+)$")
	if text and at and workspace:GetServerTimeNow() - (tonumber(at) :: number) < seconds then
		return text
	end
	return nil
end

local function textLabel(
	parent: Instance,
	size: UDim2,
	position: UDim2,
	textSize: number
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Font = (Enum.Font :: any)[V.bodyFont]
	l.TextSize = textSize
	l.TextColor3 = Color3.fromRGB(240, 232, 220)
	l.TextStrokeTransparency = 0.4
	l.TextWrapped = true
	-- Le texte retrecit plutot que deborder (un petit ecran, un long nom).
	l.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = textSize
	limit.Parent = l
	l.Text = ""
	l.Parent = parent
	return l
end

function ItemView.start()
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	local remotes = Royale:WaitForChild(Config.remotes.folder)
	local itemRemote = remotes:WaitForChild(Config.remotes.item) :: RemoteEvent
	local projectileRemote = remotes:WaitForChild(Config.remotes.projectile) :: RemoteEvent
	local steerRemote = remotes:WaitForChild(Config.remotes.steer) :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "RoyaleSac"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Les mains nues puis les 4 places, en bas au centre. La largeur se
	-- deduit du nombre de places.
	local slotW, slotH, gap = V.slotWidth, V.slotHeight, V.slotGap
	local count = BG.slots - BG.hands + 1
	local bar = Instance.new("Frame")
	bar.Name = "Places"
	bar.BackgroundTransparency = 1
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Size = UDim2.fromOffset(count * slotW + (count - 1) * gap, slotH)
	bar.Position = UDim2.new(0.5, 0, 1, -V.slotBottom)
	bar.Parent = gui
	-- Sur un ecran etroit, la barre retrecit pour tenir (vu en jeu : elle
	-- debordait sur une petite fenetre). L'echelle se deduit de la largeur.
	local fit = Instance.new("UIScale")
	fit.Parent = bar
	-- Au doigt, il se decale a gauche et retrecit : au milieu, il passait
	-- sous le bouton Frapper (Config.touch).
	local center, share = 0.5, V.slotFitFraction
	-- Les textes du sac (l'objet choisi, son etat) suivent la barre.
	local followers: { GuiObject } = {}
	local function refit()
		local touch = ButtonIcons.touch()
		center = if touch then Config.touch.bagCenter else 0.5
		share = if touch then Config.touch.bagWidth else V.slotFitFraction
		bar.Position = UDim2.new(center, 0, 1, -V.slotBottom)
		for _, l in followers do
			l.Position = UDim2.new(center, 0, l.Position.Y.Scale, l.Position.Y.Offset)
		end
		local width = gui.AbsoluteSize.X
		if width > 0 then
			fit.Scale = math.min(1, width * share / bar.Size.X.Offset)
		end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	UserInputService.LastInputTypeChanged:Connect(refit)
	refit()
	local slots: { [number]: { frame: Frame, name: TextLabel, stroke: UIStroke, pop: UIScale } } =
		{}
	local lastBag: { [number]: string } = {}
	for i = BG.hands, BG.slots do
		local f = Instance.new("Frame")
		f.Name = "Place" .. i
		f.Size = UDim2.fromOffset(slotW, slotH)
		f.Position = UDim2.fromOffset((i - BG.hands) * (slotW + gap), 0)
		-- Au doigt, on touche la place qu'on veut tenir (plus de fleches).
		f.Active = true
		local index = i
		-- Toucher : la prendre en main ; maintenir : la lacher.
		local pressed: InputObject? = nil
		f.InputBegan:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.Touch
				and player:GetAttribute(Config.match.aliveAttribute) == true
			then
				itemRemote:FireServer("select", index)
				pressed = input
				task.delay(BG.dropHoldSeconds, function()
					if pressed == input and index ~= BG.hands then
						itemRemote:FireServer("drop")
					end
				end)
			end
		end)
		f.InputEnded:Connect(function(input: InputObject)
			if pressed == input then
				pressed = nil
			end
		end)
		f.BackgroundColor3 = Color3.fromRGB(20, 14, 14)
		f.BackgroundTransparency = 0.35
		f.BorderSizePixel = 0
		f.Parent = bar
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = f
		local name = textLabel(f, UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0), 16)
		local pop = Instance.new("UIScale")
		pop.Parent = f
		slots[i] = { frame = f, name = name, stroke = stroke, pop = pop }
	end
	-- Sous le sac : comment changer d'objet et le lacher (Josh ne savait pas).
	local bagHelp = textLabel(
		gui,
		UDim2.new(V.slotFitFraction, 0, 0, V.bagHelpSize + 4),
		UDim2.new(0.5, 0, 1, -(V.slotBottom - 2)),
		V.bagHelpSize
	)
	bagHelp.TextTransparency = 0.25
	table.insert(followers, bagHelp)
	local selectedName = textLabel(
		gui,
		UDim2.new(V.slotFitFraction, 0, 0, 24),
		UDim2.new(0.5, 0, 1, -(V.slotBottom + slotH + 30)),
		20
	)
	local status =
		textLabel(gui, UDim2.new(V.slotFitFraction, 0, 0, 24), UDim2.new(0.5, 0, 1, -190), 20)
	status.TextColor3 = Color3.fromRGB(255, 220, 140)
	table.insert(followers, selectedName)
	table.insert(followers, status)
	refit()
	local message =
		textLabel(gui, UDim2.new(V.slotFitFraction, 0, 0, 30), UDim2.fromScale(0.5, 0.68), 24)
	local announce =
		textLabel(gui, UDim2.new(V.slotFitFraction, 0, 0, 34), UDim2.fromScale(0.5, 0.2), 26)
	announce.TextColor3 = rgb(Config.rarities.legendary.color)
	local flash = Instance.new("Frame")
	flash.Name = "Ebloui"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 10
	flash.Parent = gui

	local function playing(): boolean
		return workspace:GetAttribute(Config.match.phaseAttribute) == "Partie"
			and player:GetAttribute(Config.match.aliveAttribute) == true
	end

	local function currentBag(): Bag.Bag
		local text = player:GetAttribute(BG.attribute)
		return Bag.decode(if typeof(text) == "string" then text else "", BG.slots)
	end

	local function selectedSlot(): number
		local s = player:GetAttribute(BG.selectedAttribute)
		return if typeof(s) == "number" then s else 1
	end

	-- Le trait de l'arc, pendant qu'on vise.
	local aiming = false
	local dots: { Part } = {}
	for _ = 1, T.previewPoints do
		local d = Instance.new("Part")
		d.Shape = Enum.PartType.Ball
		d.Size = Vector3.one * V.aimDotSize
		d.Material = Enum.Material.Neon
		d.Color = rgb(V.beamColor)
		d.Anchored = true
		d.CanCollide = false
		d.CanQuery = false
		d.CanTouch = false
		d.Transparency = 1
		d.Parent = camera
		table.insert(dots, d)
	end
	local function hideDots()
		for _, d in dots do
			d.Transparency = 1
		end
	end

	InputBus.bind("RoyaleObjetLacher", function(_, state)
		if state == Enum.UserInputState.Begin and playing() then
			itemRemote:FireServer("drop")
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, table.unpack(keys(onFoot.dropItem)))

	InputBus.bind(
		"RoyaleObjetChoix",
		function(_, state, input: InputObject)
			if state ~= Enum.UserInputState.Begin or not playing() then
				return Enum.ContextActionResult.Pass
			end
			local step = if input.KeyCode == Enum.KeyCode[onFoot.previousItem.gamepad]
					or input.KeyCode == Enum.KeyCode[onFoot.previousItem.keyboard]
				then -1
				else 1
			itemRemote:FireServer("cycle", step)
			return Enum.ContextActionResult.Sink
		end,
		false,
		table.unpack(merged({
			onFoot.previousItem,
			onFoot.nextItem,
			hiddenCtx.previousItem,
			hiddenCtx.nextItem,
		}))
	)

	local function heldDef(): any
		return I[currentBag()[selectedSlot()]]
	end
	ItemView.holding = function(): boolean
		return playing() and heldDef() ~= nil
	end
	-- R2 (Controls) : se servir de l'objet tenu. Au doigt, un objet a lancer
	-- se vise tant qu'on tient le bouton et part au lacher ; a la manette et
	-- a la souris, il part a l'appui (vise ou non avec L2).
	-- Le geste de l'objet, joue chez soi au moment ou il sert.
	local function gesture()
		local id = currentBag()[selectedSlot()]
		local def = I[id]
		local character = player.Character
		if def and character then
			ActionAnim.play(
				Config.actionAnims,
				character:FindFirstChildOfClass("Humanoid"),
				ActionAnim.forItem(Config.actionAnims, id, def.kind)
			)
		end
	end
	ItemView.useHeld = function(state: Enum.UserInputState)
		local def = heldDef()
		if def == nil or def.kind == "passive" then
			return
		end
		local touch = ButtonIcons.touch()
		if state == Enum.UserInputState.Begin then
			if def.kind == "throw" and touch then
				aiming = true
				return
			end
			aiming = false
			hideDots()
			gesture()
			itemRemote:FireServer("use", camera.CFrame.LookVector)
		elseif state == Enum.UserInputState.End and touch and aiming then
			aiming = false
			hideDots()
			gesture()
			itemRemote:FireServer("use", camera.CFrame.LookVector)
		end
	end

	-- L2 maintenu : l'arc d'un objet a lancer ; lacher sans lancer le range.
	InputBus.bind("RoyaleViser", function(_, state)
		local def = heldDef()
		if state == Enum.UserInputState.Begin and playing() and def and def.kind == "throw" then
			aiming = true
		elseif state ~= Enum.UserInputState.Begin then
			aiming = false
			hideDots()
		end
		return Enum.ContextActionResult.Sink
	end, false, table.unpack(keys(onFoot.aim)))

	-- Les lancers, vus par tous.
	projectileRemote.OnClientEvent:Connect(
		function(id: string, origin: Vector3, velocity: Vector3, flight: number)
			local def = I[id]
			if def == nil then
				return
			end
			-- L'objet lui-meme, qui tourne sur son arc (avant : une boule de
			-- lumiere). Sans dessin, la boule a la couleur de sa rarete.
			local p: Model | Part
			local drawn = ItemModels.build(ItemShapes, id, CFrame.new(origin))
			if drawn then
				for _, d in drawn:GetDescendants() do
					if d:IsA("BasePart") then
						d.Anchored = true
					end
				end
				drawn.Parent = workspace
				p = drawn
			else
				local ball = Instance.new("Part")
				ball.Size = Vector3.one * V.projectileSize
				ball.Material = Enum.Material.Neon
				ball.Color = rgb(Config.rarities[def.rarity].color)
				ball.Anchored = true
				ball.CanCollide = false
				ball.CanQuery = false
				ball.CanTouch = false
				ball.Parent = workspace
				p = ball
			end
			local spin = Config.heldItems.spin * math.pi * 2
			local started = os.clock()
			local o = { x = origin.X, y = origin.Y, z = origin.Z }
			local v = { x = velocity.X, y = velocity.Y, z = velocity.Z }
			local connection: RBXScriptConnection? = nil
			connection = RunService.RenderStepped:Connect(function()
				local t = os.clock() - started
				if t >= flight then
					if connection then
						connection:Disconnect()
					end
					p:Destroy()
					return
				end
				local at = Throw.at(o, v, T.gravity, t)
				local cf = CFrame.new(at.x, at.y, at.z) * CFrame.Angles(t * spin, 0, t * spin * 0.4)
				if p:IsA("Model") then
					p:PivotTo(cf)
				else
					p.CFrame = cf
				end
			end)
		end
	)

	-- Ceux qu'on voit grace aux Jumelles ou a l'Oeil de verre.
	local revealed: { [Model]: Highlight } = {}
	local function characters(): { Model }
		local out: { Model } = {}
		for _, other in Players:GetPlayers() do
			if other ~= player and other.Character then
				table.insert(out, other.Character)
			end
		end
		local bots = workspace:FindFirstChild(Config.bots.folder)
		if bots then
			for _, b in bots:GetChildren() do
				if b:IsA("Model") then
					table.insert(out, b)
				end
			end
		end
		return out
	end
	local function ownerOf(character: Model): Instance
		return Players:GetPlayerFromCharacter(character) or character
	end

	-- Le grappin : monter jusqu'au point donne par le serveur.
	local lastGrapple = 0
	local lastSteer = 0
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		local bag = currentBag()
		local sel = selectedSlot()
		local inMatch = playing()
		bar.Visible = inMatch
		selectedName.Visible = inMatch
		bagHelp.Visible = inMatch
		bagHelp.Text = if ButtonIcons.touch()
			then "Touche une case pour la prendre · maintiens-la pour lâcher"
			else string.format(
				"%s / %s changer d'objet · %s lâcher",
				ButtonIcons.name(onFoot.previousItem),
				ButtonIcons.name(onFoot.nextItem),
				ButtonIcons.name(onFoot.dropItem)
			)
		for i, slot in slots do
			local def = I[bag[i]]
			-- Un objet qui arrive : sa case saute (on le voit tout de suite).
			local now_ = bag[i] or ""
			if now_ ~= "" and now_ ~= (lastBag[i] or "") then
				UiKit.pop(slot.pop, BG.newItemPop, 1, 0.3)
			end
			lastBag[i] = now_
			slot.name.Text = if def then def.name elseif i == BG.hands then "Mains nues" else ""
			slot.stroke.Color = if def
				then rgb(Config.rarities[def.rarity].color)
				else Color3.fromRGB(70, 60, 60)
			slot.stroke.Thickness = if i == sel then V.slotSelectedStroke else 1
			slot.frame.BackgroundTransparency = if i == sel then 0.1 else 0.45
		end
		local selDef = I[bag[sel]]
		-- Au doigt, le gros bouton dit deja ce qu'il fait (Lancer, Utiliser).
		local pad = ButtonIcons.gamepad()
		local how = if selDef == nil
			then ""
			elseif selDef.kind == "passive" then " · agit tout seul"
			elseif ButtonIcons.touch() then ""
			elseif selDef.kind == "throw" then (if pad
				then " · R2 lancer · L2 viser"
				else " · clic lancer · clic droit viser")
			else (if pad then " · R2 utiliser" else " · clic utiliser")
		selectedName.Text = if selDef then selDef.name .. " — " .. selDef.blurb .. how else ""

		-- Les effets en cours.
		local lines: { string } = {}
		local function add(attribute: string, label: string)
			local left = active(player, attribute)
			if left then
				table.insert(lines, string.format("%s %d s", label, math.ceil(left)))
			end
		end
		add(FX.cloakAttribute, "Cape d'ombre")
		add(FX.adrenalineAttribute, "Adrénaline")
		add(FX.steerAttribute, "Tu tiens son regard — choisis sa proie")
		local sheet = player:GetAttribute(FX.sheetAttribute)
		if sheet ~= nil then
			table.insert(
				lines,
				if sheet then "Sous la bâche, il ne te voit pas" else "Bâche : ne bouge pas !"
			)
		elseif active(player, FX.veiledAttribute) then
			add(FX.veiledAttribute, "Invisible pour l'Œil")
		end
		local bat = player:GetAttribute(FX.batAttribute)
		if typeof(bat) == "number" then
			table.insert(lines, string.format("Batte : %d coups", bat))
		end
		status.Text = table.concat(lines, "   ")

		-- Messages et annonces.
		local bell = workspace:GetAttribute(FX.bellAttribute)
		local bellAt = workspace:GetAttribute(FX.bellTimeAttribute)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local text = recent(player:GetAttribute(BG.messageAttribute), V.messageSeconds) or ""
		if
			text == ""
			and typeof(bell) == "Vector3"
			and typeof(bellAt) == "number"
			and now - bellAt < I.bell.seconds
			and root
			and (root.Position - bell).Magnitude <= I.bell.hearRadius
		then
			text = string.format(
				"Une clochette ! Quelqu'un se cache à %d m",
				math.floor((root.Position - bell).Magnitude)
			)
		end
		message.Text = text
		local relic = workspace:GetAttribute(Config.relics.attribute)
		announce.Text = recent(workspace:GetAttribute(BG.announceAttribute), V.announceSeconds)
			or (
				if typeof(relic) == "Vector3"
						and root
						and inMatch
					then string.format(
						"Relique à %d m",
						math.floor((root.Position - relic).Magnitude)
					)
					else ""
			)

		-- Ebloui : l'ecran blanchit, puis revient.
		local dazzled = active(player, FX.dazzledAttribute)
		flash.BackgroundTransparency = if dazzled
			then 1 - math.clamp(dazzled / I.torch.seconds, 0, 1) * V.dazzleOpacity
			else 1

		-- Le trait de l'arc.
		if aiming and character then
			local head = character:FindFirstChild("Head") :: BasePart?
			if head then
				local look = camera.CFrame.LookVector
				local origin = head.Position + look * T.handForward
				local o = { x = origin.X, y = origin.Y, z = origin.Z }
				local v = Throw.velocity({ x = look.X, y = look.Y, z = look.Z }, T.speed, T.lift)
				params.FilterDescendantsInstances = { character, camera }
				local previous = origin
				local stopped = false
				for i, d in dots do
					local t = i * T.maxSeconds / T.previewPoints
					local p = Throw.at(o, v, T.gravity, t)
					local here = Vector3.new(p.x, p.y, p.z)
					if not stopped and workspace:Raycast(previous, here - previous, params) then
						stopped = true
					end
					d.Transparency = if stopped then 1 else V.aimDotTransparency
					d.CFrame = CFrame.new(here)
					previous = here
				end
			end
		end

		-- Reveles.
		local reveal = active(player, FX.revealAttribute)
		local range = player:GetAttribute(FX.revealRangeAttribute)
		local throughWalls = player:GetAttribute(FX.revealHiddenAttribute) == true
		local keep: { [Model]: boolean } = {}
		if reveal and root and typeof(range) == "number" then
			for _, other in characters() do
				local otherRoot = other:FindFirstChild("HumanoidRootPart") :: BasePart?
				local hidden = ownerOf(other):GetAttribute(Config.hiding.hiddenAttribute) ~= nil
				if
					otherRoot
					and (otherRoot.Position - root.Position).Magnitude <= range
					and (throughWalls or not hidden)
				then
					keep[other] = true
					if revealed[other] == nil then
						local h = Instance.new("Highlight")
						h.FillColor = Color3.fromRGB(255, 80, 60)
						h.OutlineColor = Color3.fromRGB(255, 200, 180)
						h.FillTransparency = 0.5
						h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
						h.Adornee = other
						h.Parent = gui
						revealed[other] = h
					end
				end
			end
		end
		for other, h in revealed do
			if not keep[other] then
				h:Destroy()
				revealed[other] = nil
			end
		end

		-- Le grappin.
		local grappleAt = player:GetAttribute(FX.grappleTimeAttribute)
		local target = player:GetAttribute(FX.grappleAttribute)
		if
			typeof(grappleAt) == "number"
			and grappleAt > lastGrapple
			and typeof(target) == "Vector3"
			and root
			and character
		then
			lastGrapple = grappleAt
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local standAt = target
				+ Vector3.new(0, (if humanoid then humanoid.HipHeight else 2) + root.Size.Y / 2, 0)
			local from = root.Position
			local look = camera.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			flat = if flat.Magnitude > 0.1 then flat.Unit else Vector3.new(0, 0, -1)
			root.Anchored = true
			local started = os.clock()
			local connection: RBXScriptConnection? = nil
			connection = RunService.Heartbeat:Connect(function()
				local t = math.min((os.clock() - started) / I.grapple.seconds, 1)
				local at = from:Lerp(standAt, t)
				root.CFrame = CFrame.lookAt(at, at + flat)
				if t >= 1 then
					if connection then
						connection:Disconnect()
					end
					root.Anchored = false
					root.AssemblyLinearVelocity = Vector3.zero
				end
			end)
		end

		-- Le Regard vole : le faisceau va la ou l'on regarde.
		if
			active(player, FX.steerAttribute)
			and os.clock() - lastSteer >= V.steerSendSeconds
			and character
		then
			lastSteer = os.clock()
			params.FilterDescendantsInstances = { character, camera }
			local hit = workspace:Raycast(
				camera.CFrame.Position,
				camera.CFrame.LookVector * V.steerRange,
				params
			)
			local at = if hit
				then hit.Position
				else camera.CFrame.Position + camera.CFrame.LookVector * V.steerRange
			steerRemote:FireServer(at.X, at.Z)
		end
	end)
end

return ItemView
