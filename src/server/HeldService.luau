--!strict
--[[
	HeldService — l'objet tenu se voit en main (Josh, le 16 novembre 2026 :
	« qu'ils apparaissent dans la main quand on les choisit dans
	l'inventaire »).

	Pour chaque participant (joueur ou bot) : l'objet de la place choisie du
	sac (attributs publies par ItemService), dessine par ItemModels et soude
	a la main droite, vu par tous. Rien aux mains nues, rien cache dans un
	abri, et rien quand la batte servie est deja en main (BatService).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Royale = ReplicatedStorage:WaitForChild("Royale")
local Bag = require(Royale:WaitForChild("Bag"))
local Config = require(Royale:WaitForChild("Config"))
local ItemModels = require(Royale:WaitForChild("Effets"):WaitForChild("ItemModels"))
local ItemShapes = require(Royale:WaitForChild("ItemShapes"))

local Roster = require(script.Parent.Roster)

local HeldService = {}

local BG = Config.bag
local H = Config.heldItems

type Held = { id: string, model: Model }
local held: { [Model]: Held } = {}

local function wanted(actor: Roster.Actor): string?
	if actor:GetAttribute(Config.hiding.hiddenAttribute) ~= nil then
		return nil
	end
	local bat = actor:GetAttribute(Config.effects.batAttribute)
	if typeof(bat) == "number" and bat > 0 then
		return nil
	end
	local text = actor:GetAttribute(BG.attribute)
	local sel = actor:GetAttribute(BG.selectedAttribute)
	if typeof(text) ~= "string" or typeof(sel) ~= "number" then
		return nil
	end
	local id = Bag.decode(text, BG.slots)[sel]
	return if id and id ~= "" and ItemShapes[id] then id else nil
end

local function sync()
	local seen: { [Model]: boolean } = {}
	for _, actor in Roster.participants() do
		local character = Roster.characterOf(actor)
		if character == nil then
			continue
		end
		seen[character] = true
		local want = wanted(actor)
		local current = held[character]
		if current and (current.id ~= want or current.model.Parent == nil) then
			current.model:Destroy()
			held[character] = nil
			current = nil
		end
		if want and current == nil then
			local hand = character:FindFirstChild("RightHand")
			if hand and hand:IsA("BasePart") then
				local model = ItemModels.hold(ItemShapes, want, hand, H.tilts[want] or H.tilt)
				if model then
					model.Parent = character
					held[character] = { id = want, model = model }
				end
			end
		end
	end
	for character, h in held do
		if not seen[character] then
			h.model:Destroy()
			held[character] = nil
		end
	end
end

function HeldService.start()
	task.spawn(function()
		while true do
			local ok, err = pcall(sync)
			if not ok then
				warn("[Royale] Objet en main : " .. tostring(err))
			end
			task.wait(H.refreshSeconds)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		local character = player.Character
		local h = character and held[character]
		if h then
			h.model:Destroy()
			held[character :: Model] = nil
		end
	end)
end

return HeldService
