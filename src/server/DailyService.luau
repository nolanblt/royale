--!strict
--[[
	DailyService — les recompenses quotidiennes (Config.daily, Daily ; choisi
	avec Josh le 14 novembre 2026).

	A l'arrivee, une fois le profil lu : si la case du jour n'est pas encore
	prise, on la donne (credits, fragments ou l'objet du jour 2 / jour 7),
	et l'ecran du jour (DailyView) la montre. Jamais sur un profil illisible
	(il serait ecrase a la sauvegarde).
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Royale = ReplicatedStorage:WaitForChild("Royale")
local Config = require(Royale:WaitForChild("Config"))
local Daily = require(Royale:WaitForChild("Daily"))

local ProfileService = require(script.Parent.ProfileService)
local ShopService = require(script.Parent.ShopService)

local DailyService = {}

local D = Config.daily
local items = Config.cosmetics.items

local function today(): number
	return os.time() // 86400
end

local function grant(player: Player)
	if not ProfileService.readable(player) then
		return
	end
	local d = ProfileService.get(player)
	if d == nil then
		return
	end
	local length = #D.weeks * D.days
	local step, state = Daily.claim(d.daily, today(), length)
	if step == nil then
		return
	end
	d.daily = state
	local week, day = Daily.weekDay(step, D.days)
	local reward = D.weeks[week][day]
	local got: string
	if reward.item then
		local def = items[reward.item]
		if d.owned[reward.item] then
			local credits = D.ownedCredits[def.rarity]
			d.credits += credits
			got = string.format("%s (déjà à toi : +%d crédits)", def.name, credits)
		else
			d.owned[reward.item] = true
			got = def.name
		end
	elseif reward.credits then
		d.credits += reward.credits
		got = string.format("+%d crédits", reward.credits)
	else
		d.fragments += reward.fragments
		got = string.format("+%d fragments", reward.fragments)
	end
	ProfileService.changed(player)
	ShopService.refresh(player)
	-- L'ecran du jour : la semaine, la case prise, ce qu'elle a donne.
	player:SetAttribute(
		D.attribute,
		HttpService:JSONEncode({ week = week, day = day, got = got, at = os.time() })
	)
	print(
		string.format(
			"[Royale] Récompense du jour pour %s : semaine %d, jour %d — %s",
			player.Name,
			week,
			day,
			got
		)
	)
end

function DailyService.start()
	ProfileService.onLoaded(function(player: Player)
		task.spawn(grant, player)
	end)
end

return DailyService
