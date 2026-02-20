local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local InteractionService = {}
InteractionService.__index = InteractionService

function InteractionService.new(playerStateService, inventoryService)
	local self = setmetatable({}, InteractionService)
	self._playerStateService = playerStateService
	self._inventoryService = inventoryService
	self._connections = {}
	self._running = false
	self._interactRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Interact")
	return self
end

function InteractionService:StartRound()
	self:StopRound()
	self._running = true
	self:_bindHideSpots()
	self:_bindDoors()
	self:_bindRevives()
	table.insert(self._connections, self._interactRemote.OnServerEvent:Connect(function(player, action)
		if action == "ExitHide" then
			self._playerStateService:SetHidden(player, false)
		end
	end))
end

function InteractionService:StopRound()
	self._running = false
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
	for _, player in ipairs(Players:GetPlayers()) do
		self._playerStateService:SetHidden(player, false)
	end
end

function InteractionService:_bindHideSpots()
	for _, spot in ipairs(CollectionService:GetTagged(Config.Tags.HideSpot)) do
		if not spot:IsA("BasePart") then
			continue
		end
		spot:SetAttribute("Occupied", false)
		local prompt = spot:FindFirstChild("HidePrompt")
		if not prompt then
			prompt = Instance.new("ProximityPrompt")
			prompt.Name = "HidePrompt"
			prompt.ActionText = "Hide"
			prompt.ObjectText = "Hide Spot"
			prompt.HoldDuration = 0.2
			prompt.RequiresLineOfSight = false
			prompt.MaxActivationDistance = 8
			prompt.Parent = spot
		end
		table.insert(self._connections, prompt.Triggered:Connect(function(player)
			if spot:GetAttribute("Occupied") then
				return
			end
			if self._playerStateService:IsDowned(player) then
				return
			end
			spot:SetAttribute("Occupied", true)
			self._playerStateService:SetHidden(player, true, spot)
		end))
	end
end

function InteractionService:_bindDoors()
	for _, door in ipairs(CollectionService:GetTagged(Config.Tags.LockedDoor)) do
		if not door:IsA("BasePart") then
			continue
		end
		if door:GetAttribute("Unlocked") == nil then
			door:SetAttribute("Unlocked", false)
		end
		local prompt = door:FindFirstChild("DoorPrompt")
		if not prompt then
			prompt = Instance.new("ProximityPrompt")
			prompt.Name = "DoorPrompt"
			prompt.ActionText = "Unlock"
			prompt.ObjectText = "Locked Door"
			prompt.RequiresLineOfSight = false
			prompt.MaxActivationDistance = 8
			prompt.Parent = door
		end
		table.insert(self._connections, prompt.Triggered:Connect(function(player)
			if door:GetAttribute("Unlocked") then
				return
			end
			local requiredKeyId = door:GetAttribute("RequiredKeyId") or 1
			if not self._inventoryService:HasKey(player, requiredKeyId) then
				self._playerStateService:SendHint(player, string.format("Need Key %d", requiredKeyId))
				return
			end
			door:SetAttribute("Unlocked", true)
			door.CanCollide = false
			door.Transparency = 0.35
			door.Color = Color3.fromRGB(90, 180, 120)
			prompt.Enabled = false
		end))
	end
end

function InteractionService:_bindRevives()
	for _, player in ipairs(Players:GetPlayers()) do
		table.insert(self._connections, player.CharacterAdded:Connect(function(character)
			task.wait(0.3)
			self:_attachRevivePrompt(player, character)
		end))
		if player.Character then
			self:_attachRevivePrompt(player, player.Character)
		end
	end
end

function InteractionService:_attachRevivePrompt(targetPlayer: Player, character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local prompt = root:FindFirstChild("RevivePrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "RevivePrompt"
		prompt.ActionText = "Revive"
		prompt.ObjectText = targetPlayer.Name
		prompt.HoldDuration = Config.Player.ReviveDuration
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt.Parent = root
	end

	table.insert(self._connections, targetPlayer:GetAttributeChangedSignal("Downed"):Connect(function()
		prompt.Enabled = targetPlayer:GetAttribute("Downed") == true
	end))
	prompt.Enabled = targetPlayer:GetAttribute("Downed") == true

	table.insert(self._connections, prompt.Triggered:Connect(function(reviver)
		if reviver == targetPlayer then
			return
		end
		if not targetPlayer:GetAttribute("Downed") then
			return
		end
		if (reviver:GetAttribute("RevivesUsed") or 0) >= Config.Player.MaxRevivesPerRound then
			self._playerStateService:SendHint(reviver, "No revives left")
			return
		end
		reviver:SetAttribute("RevivesUsed", (reviver:GetAttribute("RevivesUsed") or 0) + 1)
		self._playerStateService:RevivePlayer(targetPlayer)
	end))
end

return InteractionService
