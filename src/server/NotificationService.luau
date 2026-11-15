--!strict
--[[
	NotificationService — les notifications hors du jeu (choisies avec Josh le
	15 novembre 2026, Config.notifications) :
	- le rappel du jour, aux absents (Reminders decide qui) ;
	- « ton ami joue », aux amis Roblox de qui arrive.

	Envoyees par l'API Open Cloud de Roblox (HttpService, cle rangee dans les
	secrets de l'experience). Rien ne part tant que les identifiants ne sont
	pas remplis : le service le dit au demarrage et s'arrete.

	Chaque echec s'ecrit avec sa raison : une notification qui ne part pas en
	silence, on ne saurait jamais pourquoi.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Royale = ReplicatedStorage:WaitForChild("Royale")
local Config = require(Royale:WaitForChild("Config"))
local Reminders = require(Royale:WaitForChild("Reminders"))

local NotificationService = {}

local N = Config.notifications

local function minutes(): number
	return os.time() // 60
end

-- La cle Open Cloud (un Secret : elle ne s'ecrit jamais en clair).
local function key(): any?
	local ok, secret = pcall(function()
		return HttpService:GetSecret(N.secretName)
	end)
	if not ok then
		warn(
			"[Royale] Notifications : secret « "
				.. N.secretName
				.. " » introuvable : "
				.. tostring(secret)
		)
		return nil
	end
	return secret
end

local secret: any? = nil

local function send(
	userId: number,
	messageId: string,
	category: string,
	parameters: { [string]: any }?
): boolean
	local body = {
		source = { universe = "universes/" .. tostring(game.GameId) },
		payload = {
			message_id = messageId,
			type = "MOMENT",
			parameters = parameters,
			join_experience = { launch_data = category },
			analytics_data = { category = category },
		},
	}
	local ok, response = pcall(function()
		return HttpService:RequestAsync({
			Url = string.format(N.url, userId),
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json", ["x-api-key"] = secret },
			Body = HttpService:JSONEncode(body),
		})
	end)
	if not ok then
		warn("[Royale] Notification " .. category .. " impossible : " .. tostring(response))
		return false
	end
	if not response.Success then
		warn(
			string.format(
				"[Royale] Notification %s refusée pour %d : %d %s",
				category,
				userId,
				response.StatusCode,
				string.sub(response.Body, 1, 200)
			)
		)
		return false
	end
	return true
end

local seen: OrderedDataStore? = nil
local sent: DataStore? = nil

-- Retient le jour ou un rappel part : un seul serveur l'envoie, une fois.
local function claim(userId: number, today: number): boolean
	local claimed = false
	local ok, err = pcall(function()
		(sent :: DataStore):UpdateAsync(tostring(userId), function(last: any)
			if last == today then
				claimed = false
				return nil
			end
			claimed = true
			return today
		end)
	end)
	if not ok then
		warn("[Royale] Notifications : rappel non réservé : " .. tostring(err))
		return false
	end
	return claimed
end

local function scan()
	local now = minutes()
	local oldest, newest = Reminders.window(N, now)
	local ok, page = pcall(function()
		return (seen :: OrderedDataStore)
			:GetSortedAsync(true, N.scanBatch, oldest, newest)
			:GetCurrentPage()
	end)
	if not ok then
		warn("[Royale] Notifications : absents illisibles : " .. tostring(page))
		return
	end
	local count = 0
	for _, entry in page do
		local userId = tonumber(entry.key)
		if
			userId
			and Players:GetPlayerByUserId(userId) == nil
			and Reminders.due(N, entry.value, nil, now)
			and claim(userId, Reminders.dayOf(now))
			and send(userId, N.messages.daily, "daily")
		then
			count += 1
		end
	end
	if count > 0 then
		print(string.format("[Royale] Notifications : %d rappel(s) du jour envoyé(s)", count))
	end
end

local function arrived(player: Player, tellFriends: boolean)
	local ok, err = pcall(function()
		(seen :: OrderedDataStore):SetAsync(tostring(player.UserId), minutes())
	end)
	if not ok then
		warn("[Royale] Notifications : passage non noté : " .. tostring(err))
	end
	if not tellFriends then
		return
	end
	local okFriends, pages = pcall(function()
		return Players:GetFriendsAsync(player.UserId)
	end)
	if not okFriends then
		warn("[Royale] Notifications : amis illisibles : " .. tostring(pages))
		return
	end
	local told = 0
	for _, friend in (pages :: FriendPages):GetCurrentPage() do
		if told >= N.friendsMax then
			break
		end
		local id = friend.Id
		if Players:GetPlayerByUserId(id) == nil then
			send(
				id,
				N.messages.friend,
				"friend",
				{ ["userId-friend"] = { int64_value = player.UserId } }
			)
			told += 1
		end
	end
end

-- `lobby` : seul le salon previent les amis (sinon ils le seraient deux
-- fois, a l'arrivee au salon puis au depart de la partie).
function NotificationService.start(lobby: boolean)
	if N.messages.daily == "" or N.messages.friend == "" then
		print("[Royale] Notifications : en attente des textes de notification (Creator Hub)")
		return
	end
	-- Dans Studio, rien ne part : l'API et les secrets sont ceux du jeu publie.
	if RunService:IsStudio() then
		print("[Royale] Notifications : coupées dans Studio")
		return
	end
	secret = key()
	if secret == nil then
		return
	end
	seen = DataStoreService:GetOrderedDataStore(N.seenStore)
	sent = DataStoreService:GetDataStore(N.sentStore)
	Players.PlayerAdded:Connect(function(player)
		task.spawn(arrived, player, lobby)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(arrived, player, lobby)
	end
	task.spawn(function()
		while true do
			task.wait(N.scanSeconds)
			scan()
		end
	end)
	print("[Royale] Notifications : rappel du jour et amis, actifs")
end

return NotificationService
