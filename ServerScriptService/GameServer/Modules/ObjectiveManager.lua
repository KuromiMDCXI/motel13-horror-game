local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local ObjectiveManager = {}
ObjectiveManager.__index = ObjectiveManager

function ObjectiveManager.new(inventoryService)
	local self = setmetatable({}, ObjectiveManager)
	self._inventoryService = inventoryService
	self._remotes = ReplicatedStorage:WaitForChild("Remotes")
	self._objectiveRemote = self._remotes:WaitForChild("ObjectiveUpdated")
	self._state = {
		keysFound = 0,
		fusesInserted = 0,
		powerRestored = false,
		exitUnlocked = false,
	}
	self._connections = {}
	self._spawnedItems = {}
	self._claims = {}
	self._exitGate = nil
	self._onRoundFinished = nil
	self._onPowerChanged = nil
	return self
end

local function shuffle<T>(arr: { T }): { T }
	local clone = table.clone(arr)
	for i = #clone, 2, -1 do
		local j = math.random(1, i)
		clone[i], clone[j] = clone[j], clone[i]
	end
	return clone
end

function ObjectiveManager:StartRound(onObjectivesComplete: () -> (), onPowerChanged: (boolean) -> ())
	self:ResetRound()
	self._onRoundFinished = onObjectivesComplete
	self._onPowerChanged = onPowerChanged
	self._inventoryService:ResetRound()

	local keySpawns = shuffle(CollectionService:GetTagged(Config.Tags.KeySpawn))
	local fuseSpawns = shuffle(CollectionService:GetTagged(Config.Tags.FuseSpawn))

	for i = 1, math.min(Config.Objectives.RequiredKeys, #keySpawns) do
		self:_spawnPickup("Key", i, keySpawns[i])
	end
	for i = 1, math.min(Config.Objectives.RequiredFuses, #fuseSpawns) do
		self:_spawnPickup("Fuse", i, fuseSpawns[i])
	end

	self:_bindPowerBox()
	self:_bindExitGate()
	self:BroadcastState()
	if self._onPowerChanged then
		self._onPowerChanged(false)
	end
end

function ObjectiveManager:ResetRound()
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
	for _, item in ipairs(self._spawnedItems) do
		if item and item.Parent then
			item:Destroy()
		end
	end
	table.clear(self._spawnedItems)
	table.clear(self._claims)
	self._state = { keysFound = 0, fusesInserted = 0, powerRestored = false, exitUnlocked = false }
	self._exitGate = nil
end

function ObjectiveManager:IsPowerRestored(): boolean
	return self._state.powerRestored
end

function ObjectiveManager:GetState()
	return table.clone(self._state)
end

function ObjectiveManager:BroadcastState(player: Player?)
	if player then
		self._objectiveRemote:FireClient(player, self:GetState())
	else
		self._objectiveRemote:FireAllClients(self:GetState())
	end
end

function ObjectiveManager:_spawnPickup(kind: string, id: number, spawnPoint: Instance)
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
	table.insert(self._connections, prompt.Triggered:Connect(function(player)
		local claimKey = kind .. id
		if self._claims[claimKey] then
			return
		end
		self._claims[claimKey] = true
		if kind == "Key" then
			self._inventoryService:AddKey(player, id)
			self._state.keysFound += 1
		else
			self._inventoryService:AddFuse(player)
			self._state.fusesInserted += 1
		end
		part:Destroy()
		self:_evaluateExitUnlock()
		self:BroadcastState()
	end))
end

function ObjectiveManager:_bindPowerBox()
	local box = CollectionService:GetTagged(Config.Tags.PowerBox)[1]
	if not box or not box:IsA("BasePart") then
		warn("[ObjectiveManager] Missing PowerBox")
		return
	end
	local prompt = box:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
	prompt.ActionText = "Restore Power"
	prompt.ObjectText = "Power Box"
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 10
	prompt.Parent = box

	table.insert(self._connections, prompt.Triggered:Connect(function(_player)
		if self._state.powerRestored then
			return
		end
		if self._state.fusesInserted < Config.Objectives.RequiredFuses then
			return
		end
		self._state.powerRestored = true
		self:_evaluateExitUnlock()
		self:BroadcastState()
		if self._onPowerChanged then
			self._onPowerChanged(true)
		end
	end))
end

function ObjectiveManager:_bindExitGate()
	local gate = CollectionService:GetTagged(Config.Tags.ExitGate)[1]
	if not gate or not gate:IsA("BasePart") then
		warn("[ObjectiveManager] Missing ExitGate")
		return
	end
	self._exitGate = gate
	gate:SetAttribute("Unlocked", false)
	local prompt = gate:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
	prompt.ActionText = "Unlock Exit"
	prompt.ObjectText = "Gate Console"
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 10
	prompt.Parent = gate

	table.insert(self._connections, prompt.Triggered:Connect(function(_player)
		if self._state.exitUnlocked and self._onRoundFinished then
			self._onRoundFinished()
		end
	end))
end

function ObjectiveManager:_evaluateExitUnlock()
	if self._state.keysFound >= Config.Objectives.RequiredKeys and self._state.powerRestored then
		self._state.exitUnlocked = true
		if self._exitGate then
			self._exitGate:SetAttribute("Unlocked", true)
			self._exitGate.Color = Color3.fromRGB(71, 255, 126)
		end
	end
end

return ObjectiveManager
