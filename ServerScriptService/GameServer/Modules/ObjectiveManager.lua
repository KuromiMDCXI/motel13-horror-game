local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local ObjectiveManager = {}
ObjectiveManager.__index = ObjectiveManager

function ObjectiveManager.new()
	local self = setmetatable({}, ObjectiveManager)
	self._remotes = ReplicatedStorage:WaitForChild("Remotes")
	self._objectiveRemote = self._remotes:WaitForChild("ObjectiveUpdated")
	self._state = {
		keysFound = 0,
		fusesInserted = 0,
		powerRestored = false,
		exitUnlocked = false,
	}
	self._aliveRoundConnections = {}
	self._spawnedItems = {}
	self._keyClaims = {}
	self._fuseClaims = {}
	self._powerBox = nil
	self._exitGate = nil
	self._onRoundFinished = nil
	return self
end

local function shuffle<T>(arr: {T}): {T}
	local clone = table.clone(arr)
	for i = #clone, 2, -1 do
		local j = math.random(1, i)
		clone[i], clone[j] = clone[j], clone[i]
	end
	return clone
end

local function clearConnections(connections)
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
end

function ObjectiveManager:StartRound(onObjectivesComplete: () -> ())
	self:ResetRound()
	self._onRoundFinished = onObjectivesComplete

	local keySpawns = shuffle(CollectionService:GetTagged(Config.Tags.KeySpawn))
	local fuseSpawns = shuffle(CollectionService:GetTagged(Config.Tags.FuseSpawn))

	for i = 1, math.min(Config.Objectives.RequiredKeys, #keySpawns) do
		self:_spawnPickup("Key", i, keySpawns[i], self._keyClaims)
	end

	for i = 1, math.min(Config.Objectives.RequiredFuses, #fuseSpawns) do
		self:_spawnPickup("Fuse", i, fuseSpawns[i], self._fuseClaims)
	end

	self:_bindPowerBox()
	self:_bindExitGate()
	self:BroadcastState()
end

function ObjectiveManager:ResetRound()
	clearConnections(self._aliveRoundConnections)
	for _, item in ipairs(self._spawnedItems) do
		if item and item.Parent then
			item:Destroy()
		end
	end
	table.clear(self._spawnedItems)
	table.clear(self._keyClaims)
	table.clear(self._fuseClaims)
	self._powerBox = nil
	self._exitGate = nil
	self._state.keysFound = 0
	self._state.fusesInserted = 0
	self._state.powerRestored = false
	self._state.exitUnlocked = false
end

function ObjectiveManager:GetState()
	return table.clone(self._state)
end

function ObjectiveManager:IsExitUnlocked(): boolean
	return self._state.exitUnlocked
end

function ObjectiveManager:BroadcastState(player)
	if player then
		self._objectiveRemote:FireClient(player, self:GetState())
		return
	end
	self._objectiveRemote:FireAllClients(self:GetState())
end

function ObjectiveManager:_spawnPickup(kind: string, id: number, spawnPoint: Instance, claimsTable)
	if not spawnPoint:IsA("BasePart") then
		return
	end

	local part = Instance.new("Part")
	part.Name = string.format("%s_%d", kind, id)
	part.Size = Vector3.new(1, 1, 1)
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Neon
	part.Color = kind == "Key" and Color3.fromRGB(255, 213, 84) or Color3.fromRGB(119, 220, 255)
	part.CFrame = spawnPoint.CFrame + Vector3.new(0, 1.5, 0)
	part:SetAttribute(kind .. "Id", id)
	part.Parent = Workspace

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick Up"
	prompt.ObjectText = kind
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 10
	prompt.Parent = part

	table.insert(self._spawnedItems, part)

	table.insert(self._aliveRoundConnections, prompt.Triggered:Connect(function(player)
		if claimsTable[id] then
			return
		end
		claimsTable[id] = player.UserId
		part:Destroy()
		if kind == "Key" then
			self._state.keysFound += 1
		else
			self._state.fusesInserted += 1
		end
		self:_evaluateExitUnlock()
		self:BroadcastState()
	end))
end

function ObjectiveManager:_bindPowerBox()
	local boxes = CollectionService:GetTagged(Config.Tags.PowerBox)
	local box = boxes[1]
	if not box or not box:IsA("BasePart") then
		warn("[ObjectiveManager] Missing tagged PowerBox part")
		return
	end
	self._powerBox = box
	local prompt = box:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Restore Power"
		prompt.ObjectText = "Power Box"
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 10
		prompt.Parent = box
	end

	table.insert(self._aliveRoundConnections, prompt.Triggered:Connect(function(_player)
		if self._state.powerRestored then
			return
		end
		if self._state.fusesInserted < Config.Objectives.RequiredFuses then
			return
		end
		self._state.powerRestored = true
		self:_evaluateExitUnlock()
		self:BroadcastState()
	end))
end

function ObjectiveManager:_bindExitGate()
	local gates = CollectionService:GetTagged(Config.Tags.ExitGate)
	local gate = gates[1]
	if not gate or not gate:IsA("BasePart") then
		warn("[ObjectiveManager] Missing tagged ExitGate part")
		return
	end
	self._exitGate = gate
	gate:SetAttribute("Unlocked", false)
	local prompt = gate:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Unlock Exit"
		prompt.ObjectText = "Gate Console"
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 10
		prompt.Parent = gate
	end

	table.insert(self._aliveRoundConnections, prompt.Triggered:Connect(function(_player)
		if not self._state.exitUnlocked then
			return
		end
		if self._onRoundFinished then
			self._onRoundFinished()
		end
	end))
end

function ObjectiveManager:_evaluateExitUnlock()
	local keysReady = self._state.keysFound >= Config.Objectives.RequiredKeys
	if keysReady and self._state.powerRestored then
		self._state.exitUnlocked = true
		if self._exitGate then
			self._exitGate:SetAttribute("Unlocked", true)
			self._exitGate.Color = Color3.fromRGB(71, 255, 126)
		end
	end
end

return ObjectiveManager
