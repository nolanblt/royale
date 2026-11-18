--!strict
--[[
	ActionAnim — jouer un geste (Config.actionAnims) sur un personnage.

	Le client joue ceux de son personnage (sans attendre le serveur, et
	Roblox les montre aux autres) ; le serveur joue ceux des bots et le
	recul de qui est frappe. Chaque geste ne joue que son passage utile :
	on saute a `from`, et on l'arrete a `to`.
]]

local ActionAnim = {}

type Spec = { id: number, from: number, to: number, speed: number }

local tracks: { [Animator]: { [string]: AnimationTrack } } = {}
local stops: { [AnimationTrack]: number } = {}

local function trackOf(animator: Animator, name: string, spec: Spec): AnimationTrack?
	local byName = tracks[animator]
	if byName == nil then
		byName = {}
		tracks[animator] = byName
		animator.Destroying:Connect(function()
			tracks[animator] = nil
		end)
	end
	local track = byName[name]
	if track then
		return track
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://" .. spec.id
	local ok, loaded = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok then
		warn("[Royale] Geste " .. name .. " : " .. tostring(loaded))
		return nil
	end
	local t = loaded :: AnimationTrack
	t.Priority = Enum.AnimationPriority.Action4
	t.Looped = false
	byName[name] = t
	return t
end

-- Joue le geste `name` de `config` (Config.actionAnims) sur `humanoid`.
function ActionAnim.play(config: any, humanoid: Humanoid?, name: string?)
	if humanoid == nil or name == nil then
		return
	end
	local spec = config[name] :: Spec?
	if spec == nil then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		return
	end
	local track = trackOf(animator, name, spec)
	if track == nil then
		return
	end
	track:Play(config.fadeSeconds, 1, spec.speed)
	track.TimePosition = spec.from
	-- Un nouvel appui relance le geste : seul le dernier arret compte.
	local token = (stops[track] or 0) + 1
	stops[track] = token
	task.delay((spec.to - spec.from) / spec.speed, function()
		if stops[track] == token then
			track:Stop(config.fadeSeconds * 2)
		end
	end)
end

-- Le geste d'un objet (sa sorte, ou son exception).
function ActionAnim.forItem(config: any, id: string, kind: string): string?
	return config.byItem[id] or config.byKind[kind]
end

return ActionAnim
