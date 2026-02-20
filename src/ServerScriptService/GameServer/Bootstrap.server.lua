-- Explorer Path: ServerScriptService/GameServer/Bootstrap
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local function ensureFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function ensureRemoteEvent(parent: Instance, name: string): RemoteEvent
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = parent
	return remote
end

local function ensureRemoteFunction(parent: Instance, name: string): RemoteFunction
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("RemoteFunction") then
		return existing
	end

	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = parent
	return remote
end

local remotesFolder = ensureFolder(ReplicatedStorage, "Remotes")
local sharedFolder = ensureFolder(ReplicatedStorage, "Shared")

if not sharedFolder:FindFirstChild("GameConfig") then
	warn("GameConfig ModuleScript missing in ReplicatedStorage/Shared")
end

ensureRemoteEvent(remotesFolder, "RoundState")
ensureRemoteEvent(remotesFolder, "ObjectiveUpdate")
ensureRemoteEvent(remotesFolder, "PlayerStateUpdate")
ensureRemoteEvent(remotesFolder, "AtmosphereCue")
ensureRemoteEvent(remotesFolder, "Jumpscare")
ensureRemoteEvent(remotesFolder, "SpectateTargets")
ensureRemoteEvent(remotesFolder, "SprintState")
ensureRemoteEvent(remotesFolder, "FlashlightToggle")
ensureRemoteEvent(remotesFolder, "RequestInteract")
ensureRemoteFunction(remotesFolder, "RequestSpectateNext")

local main = ServerScriptService:WaitForChild("GameServer"):WaitForChild("Main")
if main:IsA("Script") then
	main.Disabled = false
end
