local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local UIController = require(script.Parent:WaitForChild("UIController"))

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local remotes = ReplicatedStorage:WaitForChild("Remotes")

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

player.CharacterAdded:Connect(attachFlashlight)
if player.Character then
	attachFlashlight(player.Character)
end

remotes:WaitForChild("ObjectiveUpdated").OnClientEvent:Connect(function(state)
	ui:UpdateObjectives(state)
end)

remotes:WaitForChild("RoundStateChanged").OnClientEvent:Connect(function(roundData)
	ui:UpdateRound(roundData)
end)

remotes:WaitForChild("PlayerStateUpdated").OnClientEvent:Connect(function(playerState)
	ui:UpdatePlayerState(playerState)
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
