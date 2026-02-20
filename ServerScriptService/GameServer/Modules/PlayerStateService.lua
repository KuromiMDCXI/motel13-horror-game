local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local PlayerStateService = {}
PlayerStateService.__index = PlayerStateService

function PlayerStateService.new(objectiveManager)
	local self = setmetatable({}, PlayerStateService)
	self._objectiveManager = objectiveManager
	self._states = {}
	self._alivePlayers = {}
	self._runningPlayers = {}
	self._connections = {}
	self._roundActive = false
	self._remotes = ReplicatedStorage:WaitForChild("Remotes")
	self._playerStateUpdated = self._remotes:WaitForChild("PlayerStateUpdated")
	self._spectateUpdated = self._remotes:WaitForChild("SpectateUpdated")
	self._requestSprint = self._remotes:WaitForChild("RequestSprint")
	self._toggleFlashlight = self._remotes:WaitForChild("ToggleFlashlight")
	self._requestSpectate = self._remotes:WaitForChild("RequestSpectateTarget")

	table.insert(self._connections, Players.PlayerAdded:Connect(function(player)
		self:_setupPlayer(player)
	end))
	for _, player in ipairs(Players:GetPlayers()) do
		self:_setupPlayer(player)
	end

	table.insert(self._connections, Players.PlayerRemoving:Connect(function(player)
		self._states[player] = nil
		self._alivePlayers[player] = nil
		self._runningPlayers[player] = nil
	end))

	table.insert(self._connections, self._requestSprint.OnServerEvent:Connect(function(player, wantsSprint)
		self:_handleSprintRequest(player, wantsSprint)
	end))

	table.insert(self._connections, self._toggleFlashlight.OnServerEvent:Connect(function(player, enabled)
		self:_handleFlashlightToggle(player, enabled)
	end))

	table.insert(self._connections, self._requestSpectate.OnServerEvent:Connect(function(player, step)
		self:_handleSpectateRequest(player, step)
	end))

	self._heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		self:_tick(dt)
	end)

	return self
end

function PlayerStateService:SetRoundActive(roundActive: boolean)
	self._roundActive = roundActive
	if not roundActive then
		for player, _ in pairs(self._runningPlayers) do
			self:_setRunning(player, false)
		end
	end
end

function PlayerStateService:ResetForRound()
	for _, player in ipairs(Players:GetPlayers()) do
		self:_setupPlayer(player)
		local state = self._states[player]
		state.isDowned = false
		state.isRunning = false
		state.stamina = Config.Player.MaxStamina
		state.flashlightBattery = Config.Player.FlashlightBatteryMax
		state.flashlightOn = false
		state.spectateIndex = 1
		self._alivePlayers[player] = true
		self._runningPlayers[player] = nil
		self:_applyCharacterSpeed(player)
		player:SetAttribute("Downed", false)
		player:SetAttribute("IsRunning", false)
		player:SetAttribute("FlashlightOn", false)
		self:_broadcastState(player)
	end
end

function PlayerStateService:DownPlayer(player: Player)
	local state = self._states[player]
	if not state or state.isDowned then
		return
	end
	state.isDowned = true
	state.isRunning = false
	self._runningPlayers[player] = nil
	self._alivePlayers[player] = nil
	player:SetAttribute("Downed", true)
	player:SetAttribute("IsRunning", false)
	self:_applyCharacterSpeed(player)
	self:_broadcastState(player)
	self:_pushSpectate(player)
end

function PlayerStateService:GetAlivePlayers(): {Player}
	local alive = {}
	for player, _ in pairs(self._alivePlayers) do
		table.insert(alive, player)
	end
	return alive
end

function PlayerStateService:IsAllPlayersDowned(): boolean
	if not self._roundActive then
		return false
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local state = self._states[player]
		if state and not state.isDowned then
			return false
		end
	end
	return #Players:GetPlayers() > 0
end

function PlayerStateService:IsPlayerRunning(player: Player): boolean
	return self._runningPlayers[player] == true
end

function PlayerStateService:_setupPlayer(player: Player)
	if not self._states[player] then
		self._states[player] = {
			stamina = Config.Player.MaxStamina,
			flashlightBattery = Config.Player.FlashlightBatteryMax,
			flashlightOn = false,
			isDowned = false,
			isRunning = false,
			spectateIndex = 1,
		}
	end
	player:SetAttribute("Downed", self._states[player].isDowned)
	player:SetAttribute("IsRunning", false)
	player:SetAttribute("FlashlightOn", false)

	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		self:_applyCharacterSpeed(player)
	end)
end

function PlayerStateService:_handleSprintRequest(player: Player, wantsSprint: boolean)
	local state = self._states[player]
	if not state then
		return
	end
	if state.isDowned or not self._roundActive then
		self:_setRunning(player, false)
		return
	end
	if wantsSprint and state.stamina > 0 then
		self:_setRunning(player, true)
	else
		self:_setRunning(player, false)
	end
end

function PlayerStateService:_handleFlashlightToggle(player: Player, enabled: boolean)
	local state = self._states[player]
	if not state then
		return
	end
	if state.isDowned then
		enabled = false
	end
	if enabled and state.flashlightBattery <= 0 then
		enabled = false
	end
	state.flashlightOn = enabled
	player:SetAttribute("FlashlightOn", enabled)
	self:_broadcastState(player)
end

function PlayerStateService:_handleSpectateRequest(player: Player, step: number)
	local state = self._states[player]
	if not state or not state.isDowned then
		return
	end
	state.spectateIndex += step
	self:_pushSpectate(player)
end

function PlayerStateService:_pushSpectate(player: Player)
	local alive = self:GetAlivePlayers()
	local state = self._states[player]
	if #alive == 0 then
		self._spectateUpdated:FireClient(player, nil)
		return
	end
	if state.spectateIndex > #alive then
		state.spectateIndex = 1
	elseif state.spectateIndex < 1 then
		state.spectateIndex = #alive
	end
	local target = alive[state.spectateIndex]
	self._spectateUpdated:FireClient(player, target)
end

function PlayerStateService:_setRunning(player: Player, isRunning: boolean)
	local state = self._states[player]
	if not state then
		return
	end
	state.isRunning = isRunning
	player:SetAttribute("IsRunning", isRunning)
	if isRunning then
		self._runningPlayers[player] = true
	else
		self._runningPlayers[player] = nil
	end
	self:_applyCharacterSpeed(player)
	self:_broadcastState(player)
end

function PlayerStateService:_applyCharacterSpeed(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local state = self._states[player]
	if state.isDowned then
		humanoid.WalkSpeed = Config.Player.DownedWalkSpeed
	elseif state.isRunning then
		humanoid.WalkSpeed = Config.Player.SprintSpeed
	else
		humanoid.WalkSpeed = Config.Player.WalkSpeed
	end
end

function PlayerStateService:_tick(dt: number)
	for player, state in pairs(self._states) do
		if state.isRunning then
			state.stamina = math.max(0, state.stamina - Config.Player.StaminaDrainPerSecond * dt)
			if state.stamina <= 0 then
				self:_setRunning(player, false)
			end
		else
			state.stamina = math.min(Config.Player.MaxStamina, state.stamina + Config.Player.StaminaRegenPerSecond * dt)
		end

		if state.flashlightOn then
			state.flashlightBattery = math.max(0, state.flashlightBattery - Config.Player.FlashlightDrainPerSecond * dt)
			if state.flashlightBattery <= 0 then
				state.flashlightOn = false
				player:SetAttribute("FlashlightOn", false)
			end
		else
			state.flashlightBattery = math.min(Config.Player.FlashlightBatteryMax, state.flashlightBattery + Config.Player.FlashlightRegenPerSecond * dt)
		end

		self:_broadcastState(player)
	end
end

function PlayerStateService:_broadcastState(player: Player)
	local state = self._states[player]
	if not state then
		return
	end
	self._playerStateUpdated:FireClient(player, {
		stamina = state.stamina,
		staminaMax = Config.Player.MaxStamina,
		flashlightBattery = state.flashlightBattery,
		flashlightBatteryMax = Config.Player.FlashlightBatteryMax,
		isDowned = state.isDowned,
	})
end

return PlayerStateService
