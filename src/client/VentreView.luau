--!strict
--[[
	VentreView — on voit clair au Ventre (Josh, le 16 novembre 2026 : « c'est
	sombre partout, on ne voit meme pas le monstre en face »).

	Au Ventre (attribut `Goulag` du joueur), chez soi seulement : la brume
	et la lumiere de la carte (faites pour cacher la ville) laissent place a
	une lumiere rouge sourde ou l'on distingue tout ; en duel, l'adversaire
	porte un contour rouge vif, visible meme dans l'ombre. On rend tout a la
	sortie.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Royale = ReplicatedStorage:WaitForChild("Royale")
local Config = require(Royale:WaitForChild("Config"))

local VentreView = {}

local G = Config.goulag
local VV = G.view

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

function VentreView.start()
	local player = Players.LocalPlayer
	local saved: { [string]: any }? = nil
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "RoyaleVentre"
	grade.Enabled = false
	grade.Brightness = VV.brightness
	grade.Contrast = VV.contrast
	grade.Saturation = VV.saturation
	grade.TintColor = rgb(VV.tint)
	grade.Parent = Lighting

	local function atmosphere(): Atmosphere?
		return Lighting:FindFirstChildOfClass("Atmosphere")
	end

	local function enter()
		if saved then
			return
		end
		local atm = atmosphere()
		saved = {
			ambient = Lighting.Ambient,
			outdoor = Lighting.OutdoorAmbient,
			exposure = Lighting.ExposureCompensation,
			density = atm and atm.Density,
			haze = atm and atm.Haze,
			color = atm and atm.Color,
		}
		Lighting.Ambient = rgb(VV.ambient)
		Lighting.OutdoorAmbient = rgb(VV.outdoorAmbient)
		Lighting.ExposureCompensation = VV.exposure
		if atm then
			atm.Density = VV.atmosphereDensity
			atm.Haze = 0
			atm.Color = rgb(VV.atmosphereColor)
		end
		grade.Enabled = true
	end

	local function leave()
		local s = saved
		if s == nil then
			return
		end
		saved = nil
		Lighting.Ambient = s.ambient
		Lighting.OutdoorAmbient = s.outdoor
		Lighting.ExposureCompensation = s.exposure
		local atm = atmosphere()
		if atm and s.density then
			atm.Density = s.density
			atm.Haze = s.haze
			atm.Color = s.color
		end
		grade.Enabled = false
	end

	-- Le contour de l'adversaire en duel : le plus proche des autres
	-- personnages, a portee de plateforme.
	local foeLight = Instance.new("Highlight")
	foeLight.Name = "RoyaleAdversaire"
	foeLight.FillColor = rgb(VV.foeColor)
	foeLight.OutlineColor = rgb(VV.foeOutline)
	foeLight.FillTransparency = VV.foeFill
	foeLight.OutlineTransparency = 0
	foeLight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	foeLight.Enabled = false
	-- Dans un ecran qui survit a la reapparition (PlayerGui se vide a chaque
	-- nouveau personnage, sauf ces ecrans-la).
	local keep = Instance.new("ScreenGui")
	keep.Name = "RoyaleVentreContours"
	keep.ResetOnSpawn = false
	keep.Parent = player:WaitForChild("PlayerGui")
	foeLight.Parent = keep

	local function foe(): Model?
		local character = player.Character
		local me = character and character:FindFirstChild("HumanoidRootPart")
		if me == nil or not me:IsA("BasePart") then
			return nil
		end
		local best: Model? = nil
		local bestD = VV.foeRange
		for _, part in workspace:GetPartBoundsInRadius(me.Position, VV.foeRange) do
			if part.Name == "HumanoidRootPart" then
				local model = part.Parent
				if model and model:IsA("Model") and model ~= character then
					local d = (part.Position - me.Position).Magnitude
					if d < bestD and model:FindFirstChildOfClass("Humanoid") then
						best, bestD = model, d
					end
				end
			end
		end
		return best
	end

	RunService.Heartbeat:Connect(function()
		local state = player:GetAttribute(G.stateAttribute)
		if state ~= nil then
			enter()
		else
			leave()
		end
		local target = if state == "Duel" then foe() else nil
		foeLight.Adornee = target
		foeLight.Enabled = target ~= nil
	end)
end

return VentreView
