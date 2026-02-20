-- Explorer Path: StarterPlayer/StarterPlayerScripts/GameClient/ClientMain
--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local gui = Instance.new("ScreenGui")
gui.Name = "Motel13HUD"
gui.ResetOnSpawn = false
gui.Parent = localPlayer:WaitForChild("PlayerGui")

local objectiveLabel = Instance.new("TextLabel")
objectiveLabel.Size = UDim2.new(0, 420, 0, 120)
objectiveLabel.Position = UDim2.new(0, 20, 0, 20)
objectiveLabel.BackgroundTransparency = 0.35
objectiveLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
objectiveLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
objectiveLabel.TextXAlignment = Enum.TextXAlignment.Left
objectiveLabel.TextYAlignment = Enum.TextYAlignment.Top
objectiveLabel.TextSize = 20
objectiveLabel.Font = Enum.Font.GothamBold
objectiveLabel.Text = "MOTEL 13"
objectiveLabel.Parent = gui

local staminaFrame = Instance.new("Frame")
staminaFrame.Size = UDim2.new(0, 250, 0, 18)
staminaFrame.Position = UDim2.new(0.5, -125, 1, -70)
staminaFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
staminaFrame.Parent = gui

local staminaFill = Instance.new("Frame")
staminaFill.Size = UDim2.new(1, 0, 1, 0)
staminaFill.BackgroundColor3 = Color3.fromRGB(84, 194, 110)
staminaFill.Parent = staminaFrame

local batteryFrame = Instance.new("Frame")
batteryFrame.Size = UDim2.new(0, 250, 0, 18)
batteryFrame.Position = UDim2.new(0.5, -125, 1, -45)
batteryFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
batteryFrame.Parent = gui

local batteryFill = Instance.new("Frame")
batteryFill.Size = UDim2.new(1, 0, 1, 0)
batteryFill.BackgroundColor3 = Color3.fromRGB(104, 167, 255)
batteryFill.Parent = batteryFrame

local stateLabel = Instance.new("TextLabel")
stateLabel.Size = UDim2.new(0, 320, 0, 30)
stateLabel.Position = UDim2.new(0.5, -160, 0, 20)
stateLabel.BackgroundTransparency = 0.4
stateLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
stateLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
stateLabel.TextSize = 24
stateLabel.Font = Enum.Font.GothamBlack
stateLabel.Text = "Lobby"
stateLabel.Parent = gui

local spectateLabel = Instance.new("TextLabel")
spectateLabel.Size = UDim2.new(0, 360, 0, 30)
spectateLabel.Position = UDim2.new(0.5, -180, 0, 55)
spectateLabel.BackgroundTransparency = 0.4
spectateLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
spectateLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
spectateLabel.TextSize = 20
spectateLabel.Font = Enum.Font.Gotham
spectateLabel.Text = ""
spectateLabel.Visible = false
spectateLabel.Parent = gui

local flashFrame = Instance.new("Frame")
flashFrame.Size = UDim2.fromScale(1, 1)
flashFrame.BackgroundColor3 = Color3.new(1, 1, 1)
flashFrame.BackgroundTransparency = 1
flashFrame.Parent = gui

local flashlight: SpotLight? = nil
local playerState = {
	downed = false,
	flashlightOn = false,
	stamina = 100,
	battery = 100,
	heldFuses = 0,
}

local function ensureFlashlight()
	local character = localPlayer.Character
	if not character then
		return
	end
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	if flashlight and flashlight.Parent == head then
		return
	end
	flashlight = head:FindFirstChild("MotelFlashlight") :: SpotLight?
	if flashlight then
		return
	end
	local light = Instance.new("SpotLight")
	light.Name = "MotelFlashlight"
	light.Brightness = 3
	light.Angle = 70
	light.Range = 32
	light.Color = Color3.fromRGB(236, 236, 215)
	light.Enabled = false
	light.Parent = head
	flashlight = light
end

local function playOneShot(soundId: string, volume: number)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.RollOffMaxDistance = 120
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

local function setBar(frame: Frame, alpha: number)
	frame.Size = UDim2.new(math.clamp(alpha, 0, 1), 0, 1, 0)
end

local function refreshObjectiveText(payload)
	objectiveLabel.Text = string.format(
		"MOTEL 13\nKeys: %d/%d\nFuses inserted: %d/%d\nPower: %s\nExit: %s\nHeld Fuses: %d",
		payload.keysFound,
		payload.requiredKeys,
		payload.fusesInserted,
		payload.requiredFuses,
		payload.powerRestored and "ONLINE" or "OFFLINE",
		payload.gateUnlocked and "UNLOCKED" or "LOCKED",
		playerState.heldFuses
	)
end

local chaseSound = Instance.new("Sound")
chaseSound.SoundId = config.Audio.ChaseMusicSoundId
chaseSound.Looped = true
chaseSound.Volume = 0
chaseSound.Parent = SoundService
chaseSound:Play()

local breathingSound = Instance.new("Sound")
breathingSound.SoundId = config.Audio.BreathingSoundId
breathingSound.Looped = false
breathingSound.Volume = 0.3
breathingSound.Parent = SoundService

local function spectateUserId(userId: number?)
	if not userId then
		return
	end
	local player = Players:GetPlayerByUserId(userId)
	if not player or not player.Character then
		return
	end
	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
		spectateLabel.Text = "Spectating: " .. player.Name .. " (press RMB to cycle)"
	end
end

remotes:WaitForChild("RoundState").OnClientEvent:Connect(function(payload)
	stateLabel.Text = string.format("%s (%ss)", payload.state or "", payload.timeLeft or "-")
	if payload.state == "InRound" then
		TweenService:Create(chaseSound, TweenInfo.new(0.4), { Volume = 0.15 }):Play()
	else
		TweenService:Create(chaseSound, TweenInfo.new(0.4), { Volume = 0 }):Play()
		camera.CameraSubject = (localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")) or camera.CameraSubject
		spectateLabel.Visible = false
	end
end)

remotes:WaitForChild("ObjectiveUpdate").OnClientEvent:Connect(function(payload)
	refreshObjectiveText(payload)
end)

remotes:WaitForChild("PlayerStateUpdate").OnClientEvent:Connect(function(payload)
	playerState.downed = payload.downed
	playerState.flashlightOn = payload.flashlightOn
	playerState.stamina = payload.stamina
	playerState.battery = payload.battery
	playerState.heldFuses = payload.heldFuses
	setBar(staminaFill, payload.stamina / config.Player.StaminaMax)
	setBar(batteryFill, payload.battery / config.Player.FlashlightBatteryMax)
	ensureFlashlight()
	if flashlight then
		flashlight.Enabled = payload.flashlightOn
	end

	if payload.downed then
		spectateLabel.Visible = true
		spectateLabel.Text = "You were downed. Spectating..."
	end
end)

remotes:WaitForChild("AtmosphereCue").OnClientEvent:Connect(function(cueType)
	if cueType == "knock" then
		playOneShot(config.Audio.DistantKnockSoundId, 0.35)
	elseif cueType == "breathing" then
		breathingSound:Play()
	end
end)

remotes:WaitForChild("Jumpscare").OnClientEvent:Connect(function(payload)
	playOneShot(payload.soundId, 0.8)
	flashFrame.BackgroundTransparency = 0.85
	TweenService:Create(flashFrame, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	local start = tick()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if tick() - start > 0.35 then
			connection:Disconnect()
			return
		end
		camera.CFrame *= CFrame.new((math.random() - 0.5) * 0.18, (math.random() - 0.5) * 0.18, 0)
	end)
end)

remotes:WaitForChild("SpectateTargets").OnClientEvent:Connect(function(ids)
	if not playerState.downed then
		return
	end
	if #ids == 0 then
		spectateLabel.Text = "All teammates are down."
		return
	end
	spectateUserId(ids[1])
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		remotes:WaitForChild("SprintState"):FireServer(true)
	elseif input.KeyCode == Enum.KeyCode.F then
		remotes:WaitForChild("FlashlightToggle"):FireServer()
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 and playerState.downed then
		local userId = remotes:WaitForChild("RequestSpectateNext"):InvokeServer()
		spectateUserId(userId)
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		remotes:WaitForChild("SprintState"):FireServer(false)
	end
end)

localPlayer.CharacterAdded:Connect(function()
	task.wait(0.2)
	ensureFlashlight()
end)
