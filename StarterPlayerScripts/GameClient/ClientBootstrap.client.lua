local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local UIController = require(script.Parent:WaitForChild("UIController"))

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local selectGameMode = remotes:WaitForChild("SelectGameMode")
local ui = UIController.new(selectGameMode)
local ui = UIController.new()
local spectateTarget: Player? = nil

local breathing = Instance.new("Sound")
breathing.SoundId = "rbxassetid://9118828562"
breathing.Volume = 0.2
breathing.Looped = true
breathing.Parent = SoundService
breathing:Play()

local chaseMusic = Instance.new("Sound")
chaseMusic.SoundId = "rbxassetid://1843529639"
chaseMusic.Volume = 0.35
chaseMusic.Looped = true
chaseMusic.Parent = SoundService

local flashlight: SpotLight? = nil

local function attachFlashlight(character: Model)
	local head = character:WaitForChild("Head") :: BasePart
	if flashlight then
		flashlight:Destroy()
	end
	flashlight = Instance.new("SpotLight")
	flashlight.Angle = 60
	flashlight.Brightness = 2
	flashlight.Range = 35
	flashlight.Enabled = false
	flashlight.Parent = head
end

local function playWorldSound(soundId: string, position: Vector3, volume: number)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.Transparency = 1
	holder.Position = position
	holder.Size = Vector3.new(1, 1, 1)
	holder.Parent = Workspace
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.RollOffMaxDistance = 120
	sound.Parent = holder
	sound:Play()
	sound.Ended:Connect(function()
		holder:Destroy()
	end)
	task.delay(5, function()
		if holder.Parent then
			holder:Destroy()
		end
	end)
end

player.CharacterAdded:Connect(attachFlashlight)
if player.Character then
	attachFlashlight(player.Character)
end

remotes:WaitForChild("RoundStateChanged").OnClientEvent:Connect(function(roundData)
	ui:UpdateRound(roundData)
end)

remotes:WaitForChild("ObjectiveUpdated").OnClientEvent:Connect(function(state)
	ui:UpdateObjectives(state)
end)

remotes:WaitForChild("PlayerStateUpdated").OnClientEvent:Connect(function(playerState)
	ui:UpdatePlayerState(playerState)
	ui:SetSprintButtonActive(playerState.isRunning == true)
	ui:SetFlashlightButtonActive(playerState.flashlightOn == true)
	if flashlight then
		flashlight.Enabled = player:GetAttribute("FlashlightOn") == true
	end
end)

remotes:WaitForChild("SpectateUpdated").OnClientEvent:Connect(function(targetPlayer)
	spectateTarget = targetPlayer
	ui:SetSpectateTarget(targetPlayer)
end)

remotes:WaitForChild("Jumpscare").OnClientEvent:Connect(function()
	ui:FlashJumpscare()
	local scare = Instance.new("Sound")
	scare.SoundId = "rbxassetid://9043523309"
	scare.Volume = 0.9
	scare.PlayOnRemove = true
	scare.Parent = SoundService
	scare:Destroy()
end)

remotes:WaitForChild("AtmosphereEvent").OnClientEvent:Connect(function(kind, worldPos, flavor)
	if kind == "EmitterSfx" and typeof(worldPos) == "Vector3" then
		if flavor == "Whisper" then
			playWorldSound("rbxassetid://9125649971", worldPos, 0.7)
		else
			playWorldSound("rbxassetid://9114395903", worldPos, 0.65)
		end
	elseif kind == "DistantScream" then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			playWorldSound("rbxassetid://138186576", root.Position + Vector3.new(0, 0, -30), 0.55)
		end
	elseif kind == "StaticBurst" or kind == "BreakerPop" then
		ui:PlayStaticBurst()
	elseif kind == "StaticBurst" then
		ui:PlayStaticBurst()
	elseif kind == "BreakerPop" then
		ui:PlayStaticBurst()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			playWorldSound("rbxassetid://12222225", root.Position, 0.45)
		end
	end
end)

RunService.RenderStepped:Connect(function()
	if player:GetAttribute("Downed") and spectateTarget and spectateTarget.Character then
		local targetRoot = spectateTarget.Character:FindFirstChild("HumanoidRootPart")
		if targetRoot then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = CFrame.new(targetRoot.Position + Vector3.new(0, 8, 14), targetRoot.Position)
		end
		if not chaseMusic.Playing then
			chaseMusic:Play()
		end
	else
		camera.CameraType = Enum.CameraType.Custom
		if chaseMusic.Playing then
			chaseMusic:Stop()
		end
	end
end)
