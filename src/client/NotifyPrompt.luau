--!strict
--[[
	La demande d'accord pour les notifications (Config.notifications ; choisie
	avec Josh le 15 novembre 2026). Roblox conseille de la poser apres un bon
	moment : on la pose en fermant la recompense du jour, une fois par
	session. Roblox lui-meme ne l'affiche pas aux moins de 13 ans, ni a qui l'a
	deja vue dans les 30 derniers jours.
]]

local ExperienceNotificationService = game:GetService("ExperienceNotificationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Royale = ReplicatedStorage:WaitForChild("Royale")
local Config = require(Royale:WaitForChild("Config"))

local NotifyPrompt = {}

local asked = false

function NotifyPrompt.ask()
	-- Rien a promettre tant que les notifications ne partent pas.
	if asked or Config.notifications.messages.daily == "" then
		return
	end
	asked = true
	task.spawn(function()
		local ok, can = pcall(function()
			return ExperienceNotificationService:CanPromptOptInAsync()
		end)
		if not ok then
			warn("[Royale] Notifications : accord impossible à demander : " .. tostring(can))
			return
		end
		if can then
			ExperienceNotificationService:PromptOptIn()
		end
	end)
end

return NotifyPrompt
