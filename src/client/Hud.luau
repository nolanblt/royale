--!strict
--[[
	Hud — l'ecran du joueur. Il ne decide de rien : il lit les attributs que
	le serveur publie (Workspace et le joueur) et les dit simplement.

	En haut : le Regard, son titre, l'etat de l'Oeil et le compte a rebours.
	A droite : les joueurs restants. En bas : la jauge (« Il te voit »), et
	les bords de l'ecran qui rougissent avec elle. Au centre : ce qu'il faut
	savoir maintenant (la phase, hors du cercle, « Il te sent… », cache).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Royale = ReplicatedStorage:WaitForChild("Royale")
local Config = require(Royale:WaitForChild("Config"))

local ButtonIcons = require(script.Parent.ButtonIcons)

local Hud = {}

local V = Config.view
local M = Config.match
local E = Config.eye

local player = Players.LocalPlayer

local function label(
	parent: Instance,
	name: string,
	size: UDim2,
	position: UDim2,
	textSize: number
): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Font = (Enum.Font :: any)[V.bodyFont]
	l.TextSize = textSize
	l.TextColor3 = Color3.fromRGB(240, 232, 220)
	l.TextStrokeTransparency = 0.4
	l.TextWrapped = true
	-- Le texte se reduit pour tenir sur un petit ecran (vu en image : « L'ŒIL
	-- EST OUVERT — encore 23 s » perdait sa fin), jamais au-dela de sa taille.
	l.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = textSize
	limit.Parent = l
	-- Une largeur en pixels au plus, jamais plus que l'ecran : a 760 pixels
	-- fixes, une ligne depassait des deux cotes d'un ecran etroit (vu en
	-- image, et un telephone est plus etroit encore).
	if size.X.Scale == 0 then
		l.Size = UDim2.new(V.hudWidthShare, 0, size.Y.Scale, size.Y.Offset)
		local cap = Instance.new("UISizeConstraint")
		cap.MaxSize = Vector2.new(size.X.Offset, math.huge)
		cap.Parent = l
	end
	l.Text = ""
	l.Parent = parent
	return l
end

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- Le texte de la direction a prendre pour rentrer dans le cercle, d'apres
-- ou regarde la camera : devant, derriere, a gauche, a droite.
local function direction(from: Vector3, to: Vector3): string
	local camera = workspace.CurrentCamera
	local look = camera.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	local toward = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if flatLook.Magnitude == 0 or toward.Magnitude == 0 then
		return ""
	end
	flatLook, toward = flatLook.Unit, toward.Unit
	local forward = flatLook:Dot(toward)
	local right = flatLook:Cross(Vector3.new(0, 1, 0)):Dot(toward)
	if forward > 0.7 then
		return "devant toi ↑"
	elseif forward < -0.7 then
		return "derrière toi ↓"
	elseif right > 0 then
		return "à ta droite →"
	end
	return "à ta gauche ←"
end

function Hud.start()
	-- La liste de Roblox ne montre que les vrais joueurs : elle trahirait les
	-- bots (CONCEPT.md). Le jeu aura sa propre liste ; en attendant, le
	-- nombre de restants suffit.
	local ok, err = pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
	if not ok then
		warn("[Royale] Impossible de cacher la liste des joueurs : " .. tostring(err))
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "RoyaleEcran"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Les bords rouges : quatre degrades qui montent avec la jauge.
	local edges: { Frame } = {}
	for _, spec in
		{
			{ UDim2.fromScale(1, 0.25), UDim2.fromScale(0.5, 0), 90 },
			{ UDim2.fromScale(1, 0.25), UDim2.fromScale(0.5, 0.75), -90 },
			{ UDim2.fromScale(0.2, 1), UDim2.fromScale(0.1, 0), 0 },
			{ UDim2.fromScale(0.2, 1), UDim2.fromScale(0.9, 0), 180 },
		}
	do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
		f.Size = spec[1]
		f.Position = spec[2]
		f.AnchorPoint = Vector2.new(0.5, 0)
		f.BackgroundTransparency = 1
		local g = Instance.new("UIGradient")
		g.Rotation = spec[3]
		g.Transparency = NumberSequence.new(0, 1)
		g.Parent = f
		f.Parent = gui
		table.insert(edges, f)
	end

	-- Le haut est etroit sur un petit ecran : le Regard au centre sur la
	-- moitie de la largeur, les restants dessous (vu en jeu : a droite, ils
	-- passaient sur le titre).
	local regard = label(gui, "Regard", UDim2.new(0.9, 0, 0, 28), UDim2.new(0.5, 0, 0, 44), 22)
	local eyeState = label(gui, "Oeil", UDim2.new(0.6, 0, 0, 26), UDim2.new(0.5, 0, 0, 74), 22)
	local alive = label(gui, "Restants", UDim2.new(0.6, 0, 0, 24), UDim2.new(0.5, 0, 0, 102), 20)
	-- Les pouvoirs de l'Oeil : la liste en petit, et le dernier annonce en
	-- grand quelques secondes.
	local powers = label(gui, "Pouvoirs", UDim2.new(0.9, 0, 0, 20), UDim2.new(0.5, 0, 0, 128), 17)
	powers.TextColor3 = Color3.fromRGB(255, 150, 120)
	local power = label(gui, "Pouvoir", UDim2.new(0.9, 0, 0, 64), UDim2.new(0.5, 0, 0, 154), 26)
	power.TextColor3 = Color3.fromRGB(255, 110, 80)
	local center = label(gui, "Centre", UDim2.fromOffset(760, 90), UDim2.fromScale(0.5, 0.3), 30)
	-- La voix de l'Oeil et les titres gardent la machine a ecrire (Config.view).
	for _, voice in { regard, eyeState, power, center } do
		voice.Font = (Enum.Font :: any)[V.font]
	end
	local warning = label(gui, "Alerte", UDim2.fromOffset(760, 34), UDim2.fromScale(0.5, 0.62), 28)
	local hint = label(gui, "Aide", UDim2.fromOffset(760, 28), UDim2.new(0.5, 0, 1, -150), 22)

	local barBack = Instance.new("Frame")
	barBack.Name = "Jauge"
	barBack.AnchorPoint = Vector2.new(0.5, 0)
	barBack.Size = UDim2.fromOffset(360, 12)
	barBack.Position = UDim2.new(0.5, 0, 1, -110)
	barBack.BackgroundColor3 = Color3.fromRGB(30, 10, 10)
	barBack.BackgroundTransparency = 0.3
	barBack.BorderSizePixel = 0
	barBack.Parent = gui
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromScale(0, 1)
	bar.BackgroundColor3 = Color3.fromRGB(220, 40, 30)
	bar.BorderSizePixel = 0
	bar.Parent = barBack
	local barText = label(barBack, "Texte", UDim2.new(1, 0, 0, 24), UDim2.new(0.5, 0, 0, -28), 22)

	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		local phase = workspace:GetAttribute(M.phaseAttribute)
		local phaseEnds = workspace:GetAttribute(M.phaseEndsAttribute)
		local left = if typeof(phaseEnds) == "number" then phaseEnds - now else nil
		local inMatch = player:GetAttribute(M.aliveAttribute)

		-- Le Regard et l'Oeil.
		local index = workspace:GetAttribute(M.regardAttribute)
		local title = workspace:GetAttribute(M.regardTitleAttribute)
		-- Seulement pour ceux qui jouent cette partie (au salon, l'attribut
		-- n'existe pas).
		local inGame = inMatch ~= nil
		if
			inGame
			and phase == "Partie"
			and typeof(index) == "number"
			and typeof(title) == "string"
		then
			regard.Text = string.format(
				"Regard %d — %s%s",
				index,
				title,
				if left then "   " .. clock(left) else ""
			)
			local open = workspace:GetAttribute(M.eyeOpenAttribute) == true
			local change = workspace:GetAttribute(E.changeAttribute)
			local untilChange = if typeof(change) == "number" then change - now else nil
			if open then
				eyeState.TextColor3 = Color3.fromRGB(255, 90, 70)
				eyeState.Text = if untilChange
					then string.format("L'ŒIL EST OUVERT — encore %d s", math.ceil(untilChange))
					else "L'ŒIL NE SE FERMERA PLUS"
			else
				eyeState.TextColor3 = Color3.fromRGB(240, 232, 220)
				eyeState.Text = if untilChange
					then string.format("L'Œil s'ouvre dans %d s", math.ceil(untilChange))
					else "L'Œil dort… pour l'instant"
			end
		else
			regard.Text = ""
			eyeState.Text = ""
		end
		local P = Config.eyePowers
		local list = workspace:GetAttribute(P.listAttribute)
		powers.Text = if inGame
				and phase == "Partie"
				and typeof(list) == "string"
			then "Ses pouvoirs : " .. list
			else ""
		power.Text = ""
		local last = workspace:GetAttribute(P.announceAttribute)
		if inGame and phase == "Partie" and typeof(last) == "string" then
			local name, text, at = string.match(last, "^(.-)|(.-)|(.+)$")
			local t = tonumber(at)
			if name and text and t and now - t < P.announceSeconds then
				power.Text = "L'ŒIL APPREND : " .. name .. "\n" .. text
			end
		end
		local count = workspace:GetAttribute(M.aliveAttribute)
		-- Seulement pendant une partie (au salon, le compte vaut 0).
		local playing = phase == "Visee" or phase == "Chute" or phase == "Partie" or phase == "Fin"
		alive.Text = if typeof(count) == "number"
				and playing
				and inGame
			then string.format("Survivants : %d", count)
			else ""

		-- Le centre : la phase.
		local text = ""
		if phase == "Attente" then
			text = if left
				then string.format("La partie commence dans %d s", math.ceil(left))
				else "Il attend d'autres proies…"
		elseif phase == "Visee" then
			text = if ButtonIcons.touch()
				then "Choisis où l'Œil te crache\nglisse le doigt pour viser"
				else "Choisis où l'Œil te crache\nstick gauche pour viser"
		elseif phase == "Fin" then
			local winner = workspace:GetAttribute(M.winnerAttribute)
			text = if typeof(winner) == "string" and winner ~= ""
				then winner .. (if string.find(winner, ",", 1, true)
					then " ont survécu à l'Œil"
					else " a survécu à l'Œil")
				else "L'Œil les a tous pris"
			if left then
				text ..= string.format("\nNouvelle partie dans %d s", math.ceil(left))
			end
		elseif
			phase == "Partie" and player:GetAttribute(Config.goulag.stateAttribute) == "Cage"
		then
			local round = workspace:GetAttribute(Config.goulag.roundAttribute)
			-- Ce qu'on fait ici, des l'arrivee (Josh ne comprenait pas ou il etait).
			text =
				"LE VENTRE DE L'ŒIL\nDernière chance : gagne ton duel, il te recrache dans la partie."
			if typeof(round) == "number" and round > now then
				text ..= string.format("\nProchain duel dans %d s", math.ceil(round - now))
			end
		elseif
			phase == "Partie" and player:GetAttribute(Config.goulag.stateAttribute) == "Duel"
		then
			text = if player:GetAttribute(Config.goulag.suddenAttribute) == true
				then "MORT SUBITE — le sol s'effondre"
				else "DUEL — jette-le dans le vide"
		elseif phase == "Partie" and inMatch == false then
			text = "L'Œil t'a avalé."
		elseif phase == "Partie" and player:GetAttribute(Config.combat.carriedAttribute) then
			text = "On te porte…"
		elseif phase == "Partie" and player:GetAttribute(Config.combat.koAttribute) then
			text = "K.O."
		end
		center.Text = text
		-- Pendant la visee, le texte descend : il cachait la carte (vu en jeu).
		center.Position = if phase == "Visee"
			then UDim2.fromScale(0.5, 0.8)
			else UDim2.fromScale(0.5, 0.3)

		-- La jauge et les alertes.
		local level = player:GetAttribute(E.exposureAttribute)
		local exposure = if typeof(level) == "number" and inMatch == true then level else 0
		bar.Size = UDim2.fromScale(exposure, 1)
		barBack.Visible = exposure > 0
		barText.Text = if exposure > 0 then "IL TE VOIT" else ""
		for _, f in edges do
			f.BackgroundTransparency = 1 - exposure * 0.85
		end

		local alert = ""
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local circle = workspace:GetAttribute(Config.zone.attribute)
		if inMatch == true and phase == "Partie" and root and root:IsA("BasePart") then
			if typeof(circle) == "Vector3" then
				local dx, dz = root.Position.X - circle.X, root.Position.Z - circle.Z
				local outside = math.sqrt(dx * dx + dz * dz) - circle.Y
				if outside > 0 then
					alert = string.format(
						"HORS DU CERCLE — il te voit partout ! Rentre : %s (%d m)",
						direction(root.Position, Vector3.new(circle.X, 0, circle.Z)),
						math.ceil(outside)
					)
				end
			end
			local suspicion = player:GetAttribute(Config.suspicion.attribute)
			if
				alert == ""
				and typeof(suspicion) == "number"
				and suspicion >= Config.suspicion.warnAt
			then
				alert = "Il te sent… ne reste pas là."
			end
			if alert == "" and player:GetAttribute(E.huntedAttribute) == true then
				alert = "IL TE TRAQUE — casse sa ligne de vue !"
			end
		end
		warning.Text = alert
		warning.TextColor3 = Color3.fromRGB(255, 120, 90)

		local hidden = player:GetAttribute(Config.hiding.hiddenAttribute)
		local carried = player:GetAttribute(Config.combat.carryingAttribute)
		-- Au doigt, les noms des boutons a l'ecran (pas ceux de la manette).
		local touch = ButtonIcons.touch()
		-- Dans un egout, SewerView a sa propre aide (choisir la sortie).
		local inSewer = hidden == Config.hiding.displayNames[Config.hiding.sewer.name]
		hint.Text = if inSewer
			then ""
			elseif typeof(hidden) == "string" then (if touch
				then "Caché (" .. hidden .. ") · Sortir, ou Jaillir en force"
				else string.format(
					"Caché (%s) · %s sortir · %s jaillir",
					hidden,
					ButtonIcons.name(Config.controls.contexts.hidden.leave),
					ButtonIcons.name(Config.controls.contexts.hidden.burstOut)
				))
			elseif typeof(carried) == "string" then "Tu portes " .. carried .. (if touch
				then " — Jeter ou Poser"
				else string.format(
					" — %s jeter, %s poser",
					ButtonIcons.name(Config.controls.contexts.carrying.throw),
					ButtonIcons.name(Config.controls.contexts.carrying.putDown)
				))
			elseif player:GetAttribute(Config.goulag.stateAttribute) == "Duel" then (if touch
				then "Frapper · 3 coups : à terre · 1 de plus : dans le vide"
				else string.format(
					"%s frapper · 3 coups : à terre · 1 de plus : dans le vide",
					ButtonIcons.name(Config.controls.contexts.gulag.hit)
				))
			else ""
		-- L'issue d'un duel du Ventre, pour tout le monde, quelques secondes.
		local issue = workspace:GetAttribute(Config.goulag.resultAttribute)
		if warning.Text == "" and phase == "Partie" and typeof(issue) == "string" then
			local said, at = string.match(issue, "^(.-)|(.+)$")
			local t = tonumber(at)
			if said and t and now - t < Config.goulag.resultSeconds then
				warning.Text = said
			end
		end
	end)
end

return Hud
