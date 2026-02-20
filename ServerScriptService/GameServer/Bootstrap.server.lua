local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local function ensureFolder(parent: Instance, name: string): Folder
	local folder = parent:FindFirstChild(name)
	if folder and folder:IsA("Folder") then
		return folder
	end

	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function ensureRemoteEvent(parent: Instance, name: string): RemoteEvent
	local remote = parent:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end

	remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = parent
	return remote
end

local remotesFolder = ensureFolder(ReplicatedStorage, "Remotes")
ensureRemoteEvent(remotesFolder, "RoundStateChanged")
ensureRemoteEvent(remotesFolder, "ObjectiveUpdated")
ensureRemoteEvent(remotesFolder, "PlayerStateUpdated")
ensureRemoteEvent(remotesFolder, "SpectateUpdated")
ensureRemoteEvent(remotesFolder, "Jumpscare")

-- Canonical gameplay input remotes
ensureRemoteEvent(remotesFolder, "SprintState")
ensureRemoteEvent(remotesFolder, "FlashlightToggle")

-- Backward compatibility with earlier naming
ensureRemoteEvent(remotesFolder, "RequestSprint")
ensureRemoteEvent(remotesFolder, "ToggleFlashlight")

ensureRemoteEvent(remotesFolder, "RequestSpectateTarget")

local modulesFolder = ServerScriptService:WaitForChild("GameServer"):WaitForChild("Modules")
local ObjectiveManager = require(modulesFolder:WaitForChild("ObjectiveManager"))
local PlayerStateService = require(modulesFolder:WaitForChild("PlayerStateService"))
local EnemyController = require(modulesFolder:WaitForChild("EnemyController"))
local AtmosphereService = require(modulesFolder:WaitForChild("AtmosphereService"))
local RoundManager = require(modulesFolder:WaitForChild("RoundManager"))

local objectiveManager = ObjectiveManager.new()
local playerStateService = PlayerStateService.new(objectiveManager)
local enemyController = EnemyController.new(playerStateService)
local atmosphereService = AtmosphereService.new(playerStateService)

local roundManager = RoundManager.new(objectiveManager, playerStateService, enemyController, atmosphereService)
roundManager:Start()
