--!strict
--[[
	LootGlow — les meubles a fouiller se voient (Josh, le 16 novembre 2026 :
	« qu'on voie un peu les zones qu'on peut fouiller »).

	En partie, les meubles de Carte.Fouilles proches et pas encore fouilles
	(attribut `Fouille`, pose par le serveur) ont un contour couleur
	lanterne qui respire, et quelques poussieres qui scintillent. Les plus
	proches seulement : Roblox ne montre qu'une trentaine de contours a la
	fois, et une carte entiere qui brille ne designe plus rien.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Royale = ReplicatedStorage:WaitForChild("Royale")
local Config = require(Royale:WaitForChild("Config"))

local LootGlow = {}

local G = Config.lootGlow

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

function LootGlow.start()
	local player = Players.LocalPlayer
	local root = workspace:WaitForChild(Config.world.folder)
	local containers = root:WaitForChild(Config.world.containers)

	-- Un ecran qui survit a la reapparition : PlayerGui se vide a chaque
	-- nouveau personnage, sauf ces ecrans-la (un dossier y disparaissait).
	local holder = Instance.new("ScreenGui")
	holder.Name = "RoyaleFouillesVues"
	holder.ResetOnSpawn = false
	holder.Parent = player:WaitForChild("PlayerGui")

	type Glow = { highlight: Highlight, dust: ParticleEmitter }
	local glows: { [BasePart]: Glow } = {}

	local function make(part: BasePart): Glow
		local h = Instance.new("Highlight")
		h.Adornee = part
		h.FillColor = rgb(G.color)
		h.OutlineColor = rgb(G.color)
		h.FillTransparency = G.fillTransparency
		h.OutlineTransparency = G.outlineTransparency
		h.DepthMode = Enum.HighlightDepthMode.Occluded
		h.Parent = holder
		local dust = Instance.new("ParticleEmitter")
		dust.Color = ColorSequence.new(rgb(G.color))
		dust.LightEmission = 1
		dust.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, G.dustSize),
			NumberSequenceKeypoint.new(1, 0),
		})
		dust.Lifetime = NumberRange.new(1, 1.8)
		dust.Rate = G.dustRate
		dust.Speed = NumberRange.new(0.3, 0.8)
		dust.SpreadAngle = Vector2.new(180, 180)
		dust.Acceleration = Vector3.new(0, 0.6, 0)
		dust.Parent = part
		return { highlight = h, dust = dust }
	end

	local function drop(part: BasePart)
		local g = glows[part]
		if g then
			g.highlight:Destroy()
			g.dust:Destroy()
			glows[part] = nil
		end
	end

	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		-- La respiration du contour.
		local pulse = (math.sin(os.clock() * G.pulseSpeed) + 1) / 2
		for _, g in glows do
			g.highlight.OutlineTransparency = G.outlineTransparency + pulse * G.pulseDepth
		end
		acc += dt
		if acc < G.refreshSeconds then
			return
		end
		acc = 0
		local character = player.Character
		local me = character and character:FindFirstChild("HumanoidRootPart")
		local playing = workspace:GetAttribute(Config.match.phaseAttribute) == "Partie"
			and player:GetAttribute(Config.match.aliveAttribute) == true
		if not playing or me == nil or not me:IsA("BasePart") then
			for part in glows do
				drop(part)
			end
			return
		end
		-- Les plus proches, pas encore fouilles, a portee.
		type Near = { part: BasePart, d: number }
		local near: { Near } = {}
		for _, part in containers:GetChildren() do
			if part:IsA("BasePart") and part:GetAttribute(Config.loot.searchedAttribute) == nil then
				local d = (part.Position - me.Position).Magnitude
				if d <= G.radius then
					table.insert(near, { part = part, d = d })
				end
			end
		end
		table.sort(near, function(a, b)
			return a.d < b.d
		end)
		local keep: { [BasePart]: boolean } = {}
		for i = 1, math.min(#near, G.max) do
			local part = near[i].part
			keep[part] = true
			if glows[part] == nil then
				glows[part] = make(part)
			end
		end
		for part in glows do
			if not keep[part] then
				drop(part)
			end
		end
	end)
end

return LootGlow
