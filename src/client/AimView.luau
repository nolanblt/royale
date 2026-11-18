--!strict
--[[
	AimView — la visee du depart (CONCEPT.md, Le depart) : pendant la phase
	`Visee`, on regarde la carte d'en haut, et un reticule au sol se deplace
	a l'un ou l'autre stick (ou aux fleches, ZQSD, WASD). La camera suit le
	reticule de haut, le nord toujours en haut : depuis la pupille, elle
	penchait sur le cote des qu'on visait loin (Josh, le 18 novembre 2026). Le point est envoye
	au serveur deux fois par seconde ; il le ramene dans la carte.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Royale = ReplicatedStorage:WaitForChild("Royale")
local Config = require(Royale:WaitForChild("Config"))

local SkyView = require(script.Parent.SkyView)

local AimView = {}

local V = Config.view

-- Les couleurs de Config sont des { r, v, b } (Config se charge sans Roblox).
local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

function AimView.start()
	local remotes = Royale:WaitForChild(Config.remotes.folder)
	local aimRemote = remotes:WaitForChild(Config.remotes.aim) :: RemoteEvent
	local camera = workspace.CurrentCamera
	local player = Players.LocalPlayer

	local reticle = Instance.new("Part")
	reticle.Name = "RoyaleViseur"
	reticle.Shape = Enum.PartType.Cylinder
	reticle.Material = Enum.Material.Neon
	reticle.Color = rgb(V.beamColor)
	reticle.Anchored = true
	reticle.CanCollide = false
	reticle.CanQuery = false
	reticle.CanTouch = false
	reticle.Transparency = 1
	reticle.Size = Vector3.new(1, 24, 24)
	reticle.Parent = workspace

	-- Les deux sticks visent (le droit, comme on oriente la vue partout).
	local sticks: { [Enum.KeyCode]: Vector2 } = {}
	local stick = Vector2.zero
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if
			input.KeyCode == Enum.KeyCode.Thumbstick1
			or input.KeyCode == Enum.KeyCode.Thumbstick2
		then
			local v = Vector2.new(input.Position.X, -input.Position.Y)
			sticks[input.KeyCode] = if v.Magnitude < V.stickDeadZone then Vector2.zero else v
			local a = sticks[Enum.KeyCode.Thumbstick1] or Vector2.zero
			local b = sticks[Enum.KeyCode.Thumbstick2] or Vector2.zero
			stick = if b.Magnitude > a.Magnitude then b else a
		end
	end)

	local aim = Vector2.zero
	local active = false
	-- Au doigt : on glisse le reticule (la camera regarde la carte d'en
	-- haut, le haut de l'ecran vers -Z : glisser a droite va vers +X, vers
	-- le bas vers +Z).
	UserInputService.TouchMoved:Connect(function(touch: InputObject, processed: boolean)
		if active and not processed then
			aim += Vector2.new(touch.Delta.X, touch.Delta.Y) * Config.touch.aimStudsPerPixel
		end
	end)
	-- Ce qu'on ecarte le temps de viser, et ce qu'on remet apres.
	local saved: { density: number?, haze: number?, clouds: boolean? } = {}
	local function clearView(on: boolean)
		local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
		local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
		if on then
			if atmosphere then
				saved.density = atmosphere.Density
				saved.haze = atmosphere.Haze
				atmosphere.Density = V.aimAtmosphereDensity
				atmosphere.Haze = V.aimHaze
			end
			if clouds then
				saved.clouds = clouds.Enabled
				clouds.Enabled = false
			end
		else
			if atmosphere and saved.density then
				atmosphere.Density = saved.density
				atmosphere.Haze = saved.haze
			end
			if clouds and saved.clouds ~= nil then
				clouds.Enabled = saved.clouds
			end
			table.clear(saved)
		end
	end
	local lastSend = 0
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { reticle }

	RunService:BindToRenderStep(
		"RoyaleVisee",
		Enum.RenderPriority.Camera.Value + 1,
		function(dt: number)
			local aiming = workspace:GetAttribute(Config.match.phaseAttribute) == "Visee"
			if aiming and not active then
				active = true
				aim = Vector2.new(SkyView.eyeOrigin.X, SkyView.eyeOrigin.Z)
				clearView(true)
			elseif not aiming and active then
				active = false
				clearView(false)
				reticle.Transparency = 1
				camera.CameraType = Enum.CameraType.Custom
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					camera.CameraSubject = humanoid
				end
			end
			if not active then
				return
			end
			local move = stick
			local function key(k: Enum.KeyCode): number
				return if UserInputService:IsKeyDown(k) then 1 else 0
			end
			local kx = key(Enum.KeyCode.D)
				+ key(Enum.KeyCode.Right)
				- key(Enum.KeyCode.A)
				- key(Enum.KeyCode.Q)
				- key(Enum.KeyCode.Left)
			local kz = key(Enum.KeyCode.S)
				+ key(Enum.KeyCode.Down)
				- key(Enum.KeyCode.W)
				- key(Enum.KeyCode.Z)
				- key(Enum.KeyCode.Up)
			if kx ~= 0 or kz ~= 0 then
				move = Vector2.new(kx, kz)
			end
			aim += move * V.aimSpeed * dt
			local half = Config.world.half
			aim = Vector2.new(math.clamp(aim.X, -half, half), math.clamp(aim.Y, -half, half))

			local hit = workspace:Raycast(
				Vector3.new(aim.X, 500, aim.Y),
				Vector3.new(0, -800, 0),
				rayParams
			)
			local ground = if hit then hit.Position else Vector3.new(aim.X, 0, aim.Y)
			reticle.Transparency = 0.2
			reticle.CFrame = CFrame.new(ground + Vector3.new(0, 0.5, 0))
				* CFrame.Angles(0, 0, math.pi / 2)

			-- La camera au-dessus du reticule, un peu au sud, le nord en haut :
			-- elle ne penche jamais.
			camera.CameraType = Enum.CameraType.Scriptable
			local from = ground + Vector3.new(0, V.aimCameraHeight, V.aimCameraBack)
			local want = CFrame.lookAt(from, ground)
			camera.CFrame = camera.CFrame:Lerp(want, math.clamp(dt * V.aimCameraFollow, 0, 1))

			local now = os.clock()
			if now - lastSend >= V.aimSendSeconds then
				lastSend = now
				aimRemote:FireServer(aim.X, aim.Y)
			end
		end
	)
end

return AimView
