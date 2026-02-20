-- Explorer Path: ServerScriptService/GameServer/Modules/ObjectiveManager
--!strict

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local ObjectiveManager = {}
ObjectiveManager.__index = ObjectiveManager

function ObjectiveManager.new(config, remotes, playerState)
	local self = setmetatable({}, ObjectiveManager)
	self._config = config
	self._remotes = remotes
	self._playerState = playerState
	self._folder = Workspace:FindFirstChild("DynamicObjectives")
	if not self._folder then
		self._folder = Instance.new("Folder")
		self._folder.Name = "DynamicObjectives"
		self._folder.Parent = Workspace
	end
	self:ResetObjectives()
	return self
end

function ObjectiveManager:ResetObjectives()
	self.KeysFound = 0
	self.FusesInserted = 0
	self.PowerRestored = false
	self.GateUnlocked = false

	self._activeKeyModels = {}
	self._activeFuseModels = {}

	for _, child in ipairs(self._folder:GetChildren()) do
		child:Destroy()
	end
end

local function buildPickup(name: string, color: Color3, cf: CFrame): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Block
	part.Size = Vector3.new(1, 0.6, 2)
	part.Color = color
	part.Material = Enum.Material.Metal
	part.CFrame = cf
	part.Anchored = true
	part.CanCollide = false
	return part
end

function ObjectiveManager:SpawnObjectives()
	self:ResetObjectives()

	local keySpawns = CollectionService:GetTagged("KeySpawn")
	local fuseSpawns = CollectionService:GetTagged("FuseSpawn")

	self:_spawnCollectibles(keySpawns, self._config.Objectives.RequiredKeys, true)
	self:_spawnCollectibles(fuseSpawns, self._config.Objectives.RequiredFuses, false)
	self:_setupPowerBoxes()
	self:_setupExitGates()
	self:PushObjectiveUpdate()
end

function ObjectiveManager:_spawnCollectibles(spawns: {Instance}, amount: number, isKey: boolean)
	if #spawns == 0 then
		warn("No spawns found for", isKey and "keys" or "fuses")
		return
	end

	local pool = table.clone(spawns)
	for i = #pool, 2, -1 do
		local j = math.random(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end

	for i = 1, math.min(amount, #pool) do
		local spawnPart = pool[i]
		if not spawnPart:IsA("BasePart") then
			continue
		end

		local itemName = isKey and ("RoomKey_" .. i) or ("Fuse_" .. i)
		local part = buildPickup(itemName, isKey and Color3.fromRGB(255, 214, 92) or Color3.fromRGB(96, 197, 255), spawnPart.CFrame + Vector3.new(0, 2, 0))
		part.Parent = self._folder

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "PickupPrompt"
		prompt.ObjectText = isKey and "Room Key" or "Fuse"
		prompt.ActionText = "Collect"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = self._config.Objectives.InteractDistance
		prompt.RequiresLineOfSight = false
		prompt.Parent = part

		prompt.Triggered:Connect(function(player)
			if isKey then
				self.KeysFound += 1
			else
				self._playerState:AddFuse(player)
			end
			part:Destroy()
			self:_checkGateState()
			self:PushObjectiveUpdate()
		end)

		if isKey then
			table.insert(self._activeKeyModels, part)
		else
			table.insert(self._activeFuseModels, part)
		end
	end
end

function ObjectiveManager:_setupPowerBoxes()
	for _, instance in ipairs(CollectionService:GetTagged("PowerBox")) do
		if not instance:IsA("BasePart") then
			continue
		end
		local prompt = instance:FindFirstChild("PowerPrompt")
		if not prompt then
			prompt = Instance.new("ProximityPrompt")
			prompt.Name = "PowerPrompt"
			prompt.Parent = instance
		end
		prompt.ObjectText = "Power Box"
		prompt.ActionText = "Insert Fuse"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = self._config.Objectives.InteractDistance
		prompt.RequiresLineOfSight = false

		prompt.Triggered:Connect(function(player)
			if self.PowerRestored then
				return
			end
			if self._playerState:ConsumeFuse(player) then
				self.FusesInserted += 1
				if self.FusesInserted >= self._config.Objectives.RequiredFuses then
					self.PowerRestored = true
				end
				self:_checkGateState()
				self:PushObjectiveUpdate()
			end
		end)
	end
end

function ObjectiveManager:_setupExitGates()
	for _, instance in ipairs(CollectionService:GetTagged("ExitGate")) do
		if not instance:IsA("BasePart") then
			continue
		end
		local prompt = instance:FindFirstChild("ExitPrompt")
		if not prompt then
			prompt = Instance.new("ProximityPrompt")
			prompt.Name = "ExitPrompt"
			prompt.Parent = instance
		end
		prompt.ObjectText = "Exit Gate"
		prompt.ActionText = "Escape"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = self._config.Objectives.InteractDistance
		prompt.RequiresLineOfSight = false

		prompt.Triggered:Connect(function(player)
			if not self.GateUnlocked then
				return
			end
			self._playerState:SetEscaped(player)
			self:PushObjectiveUpdate()
		end)
	end
end

function ObjectiveManager:_checkGateState()
	self.GateUnlocked = self.PowerRestored and self.KeysFound >= self._config.Objectives.RequiredKeys
end

function ObjectiveManager:PushObjectiveUpdate(player: Player?)
	local payload = {
		keysFound = self.KeysFound,
		requiredKeys = self._config.Objectives.RequiredKeys,
		fusesInserted = self.FusesInserted,
		requiredFuses = self._config.Objectives.RequiredFuses,
		powerRestored = self.PowerRestored,
		gateUnlocked = self.GateUnlocked,
	}
	local remote = self._remotes:WaitForChild("ObjectiveUpdate")
	if player then
		remote:FireClient(player, payload)
	else
		remote:FireAllClients(payload)
	end
end

function ObjectiveManager:IsGateUnlocked(): boolean
	return self.GateUnlocked
end

return ObjectiveManager
