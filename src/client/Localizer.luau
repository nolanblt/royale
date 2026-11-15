--!strict
--[[
	Le jeu en anglais pour qui ne joue pas en francais (Config.lang, choisi
	avec Josh le 15 novembre 2026). Chaque texte affiche (ecrans, panneaux et
	etiquettes du monde, invites) est remplace des qu'il change, par Lang et le
	dictionnaire Strings : aucun ecran n'a a s'en occuper, et les messages
	envoyes par le serveur (en francais) se traduisent chez chacun dans sa
	langue.

	Dans Studio, un texte francais sans traduction s'ecrit une fois dans la
	console : c'est la liste de ce qui reste a ajouter a Strings.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Royale")
local Config = require(Shared:WaitForChild("Config"))
local Lang = require(Shared:WaitForChild("Lang"))
local Strings = require(Shared:WaitForChild("Strings"))

local Localizer = {}

local compiled = Lang.compile(Strings.en)
local forced: boolean? = nil
local active = false
local cache: { [string]: string | false } = {}
local cached = 0
local reported: { [string]: boolean } = {}
local studio = RunService:IsStudio()

-- Un morceau qui ressemble a du francais (lettre accentuee ou mot courant) :
-- seuls ceux-la meritent d'etre signales comme oublies.
local FRENCH_WORDS = {
	le = true,
	la = true,
	les = true,
	de = true,
	des = true,
	du = true,
	un = true,
	une = true,
	et = true,
	pour = true,
	dans = true,
	tu = true,
	te = true,
	il = true,
	pas = true,
}
local function looksFrench(s: string): boolean
	if string.find(s, "[\195\197][\128-\191]") then
		return true
	end
	for word in string.gmatch(string.lower(s), "%a+") do
		if FRENCH_WORDS[word] then
			return true
		end
	end
	return false
end

local function report(piece: string)
	if studio and not reported[piece] and looksFrench(piece) then
		reported[piece] = true
		warn("[Royale] Pas traduit : " .. piece)
	end
end

local function translated(text: string): string?
	local hit = cache[text]
	if hit ~= nil then
		return if hit == false then nil else hit
	end
	local out = Lang.translate(compiled, text, report)
	if cached >= Config.lang.cacheSize then
		table.clear(cache)
		cached = 0
	end
	cache[text] = out or false
	cached += 1
	return out
end

local function watchProperty(inst: Instance, property: string)
	local function apply()
		local text = (inst :: any)[property]
		if typeof(text) ~= "string" or text == "" then
			return
		end
		local out = translated(text)
		if out and out ~= text then
			(inst :: any)[property] = out
		end
	end
	apply()
	inst:GetPropertyChangedSignal(property):Connect(function()
		if active then
			apply()
		end
	end)
end

local watched: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function hook(inst: Instance)
	if watched[inst] then
		return
	end
	if inst:IsA("TextLabel") or inst:IsA("TextButton") then
		watched[inst] = true
		watchProperty(inst, "Text")
	elseif inst:IsA("ProximityPrompt") then
		watched[inst] = true
		watchProperty(inst, "ActionText")
		watchProperty(inst, "ObjectText")
	end
end

local function english(): boolean
	if forced ~= nil then
		return forced
	end
	local locale = string.lower(Players.LocalPlayer.LocaleId)
	return string.sub(locale, 1, #Config.lang.sourcePrefix) ~= Config.lang.sourcePrefix
end

local started = false
local function begin()
	if started then
		return
	end
	started = true
	local roots: { Instance } = {
		Players.LocalPlayer:WaitForChild("PlayerGui"),
		workspace,
	}
	for _, root in roots do
		root.DescendantAdded:Connect(function(d)
			if active then
				hook(d)
			end
		end)
		for _, d in root:GetDescendants() do
			hook(d)
		end
	end
end

-- La langue a pu changer (essai dans Studio) : le texte deja traduit reste,
-- le prochain changement suit la nouvelle langue.
local function refresh()
	active = english()
	if active then
		begin()
	end
	print(string.format("[Royale] Langue : %s", if active then "anglais" else "français"))
end

-- Pour les essais dans Studio : forcer l'anglais (true), le francais (false),
-- ou la langue du compte (nil). Depuis un LocalScript injecte.
function Localizer.force(on: boolean?)
	forced = on
	refresh()
end

function Localizer.english(): boolean
	return active
end

function Localizer.start()
	refresh()
	Players.LocalPlayer:GetPropertyChangedSignal("LocaleId"):Connect(refresh)
end

return Localizer
