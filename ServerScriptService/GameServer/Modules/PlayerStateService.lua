local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local PlayerStateService = {}
PlayerStateService.__index = PlayerStateService

function PlayerStateService.new(_objectiveManager)
	local self = setmetatable({}, PlayerStateService)
	self._states = {}
	self._alivePlayers = {}
	self._runningPlayers = {}
	self._connections = {}
	self._roundActive = false
	self._warnedMissingHumanoid = {}
	self._warnedMissingCharacter = {}
	self._sendAccumulator = 0
	self._sprintDebugSeen = {}

	self._remotes = ReplicatedStorage:WaitForChild("Remotes")
	self._playerStateUpdated = self._remotes:WaitForChild("PlayerStateUpdated")
	self._spectateUpdated = self._remotes:WaitForChild("SpectateUpdated")
	self._sprintState = self._remotes:WaitForChild("SprintState")
	self._flashlightToggle = self._remotes:WaitForChild("FlashlightToggle")
	self._requestSpectate = self._remotes:WaitForChild("RequestSpectateTarget")

	local legacySprint = self._remotes:FindFirstChild("RequestSprint")
	local legacyFlashlight = self._remotes:FindFirstChild("ToggleFlashlight")

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
		self._warnedMissingHumanoid[player.UserId] = nil
		self._warnedMissingCharacter[player.UserId] = nil
	end))

	table.insert(self._connections, self._sprintState.OnServerEvent:Connect(function(player, wantsSprint)
		self:_handleSprintRequest(player, wantsSprint)
	end))
	if legacySprint and legacySprint:IsA("RemoteEvent") then
		table.insert(self._connections, legacySprint.OnServerEvent:Connect(function(player, wantsSprint)
			self:_handleSprintRequest(player, wantsSprint)
		end))
	end

	table.insert(self._connections, self._flashlightToggle.OnServerEvent:Connect(function(player, enabled)
		self:_handleFlashlightToggle(player, enabled)
	end))
	if legacyFlashlight and legacyFlashlight:IsA("RemoteEvent") then
		table.insert(self._connections, legacyFlashlight.OnServerEvent:Connect(function(player, enabled)
			self:_handleFlashlightToggle(player, enabled)
		end))
	end

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
		state.isHidden = false
		state.stamina = Config.Player.MaxStamina
		state.flashlightBattery = Config.Player.FlashlightBatteryMax
		state.flashlightOn = false
		state.spectateIndex = 1
		state.hideSpot = nil
		state.hint = ""
		self._alivePlayers[player] = true
		self._runningPlayers[player] = nil
		player:SetAttribute("Downed", false)
		player:SetAttribute("IsRunning", false)
		player:SetAttribute("FlashlightOn", false)
		player:SetAttribute("Hidden", false)
		player:SetAttribute("RevivesUsed", 0)
		self:_applyCharacterSpeed(player)
		self:_broadcastState(player)
	end
end

function PlayerStateService:IsDowned(player: Player): boolean
	local state = self._states[player]
	return state ~= nil and state.isDowned
end

function PlayerStateService:IsHidden(player: Player): boolean
	local state = self._states[player]
	return state ~= nil and state.isHidden
end

function PlayerStateService:SetHidden(player: Player, hidden: boolean, spot: BasePart?)
	local state = self._states[player]
	if not state then
		return
	end
	if state.isDowned then
		hidden = false
	end
	state.isHidden = hidden
	state.hideSpot = spot
	player:SetAttribute("Hidden", hidden)
	if hidden then
		self:_setRunning(player, false)
		self:SendHint(player, "HIDDEN - Press E to exit")
		if spot and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			(player.Character.HumanoidRootPart :: BasePart).CFrame = spot.CFrame
		end
	else
		if state.hideSpot then
			state.hideSpot:SetAttribute("Occupied", false)
		end
		state.hideSpot = nil
		self:SendHint(player, "")
	end
	self:_broadcastState(player)
end

function PlayerStateService:SendHint(player: Player, message: string)
	local state = self._states[player]
	if not state then
		return
	end
	state.hint = message
	self:_broadcastState(player)
end

function PlayerStateService:DownPlayer(player: Player)
	local state = self._states[player]
	if not state or state.isDowned then
		return
	end
	state.isDowned = true
	state.isRunning = false
	state.flashlightOn = false
	self:SetHidden(player, false)
	self._runningPlayers[player] = nil
	self._alivePlayers[player] = nil
	player:SetAttribute("Downed", true)
	player:SetAttribute("IsRunning", false)
	player:SetAttribute("FlashlightOn", false)
	self:_applyCharacterSpeed(player)
	self:_broadcastState(player)
	self:_pushSpectate(player)
end

function PlayerStateService:RevivePlayer(player: Player)
	local state = self._states[player]
	if not state or not state.isDowned then
		return
	end
	state.isDowned = false
	state.stamina = math.max(35, state.stamina)
	state.flashlightOn = false
	self._alivePlayers[player] = true
	player:SetAttribute("Downed", false)
	player:SetAttribute("FlashlightOn", false)
	self:_applyCharacterSpeed(player)
	self:_broadcastState(player)
end

function PlayerStateService:GetAlivePlayers(): { Player }
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
	if self._states[player] then
		return
	end
	self._states[player] = {
		stamina = Config.Player.MaxStamina,
		flashlightBattery = Config.Player.FlashlightBatteryMax,
		flashlightOn = false,
		isDowned = false,
		isRunning = false,
		isHidden = false,
		spectateIndex = 1,
		hideSpot = nil,
		hint = "",
	}
	player:SetAttribute("Downed", false)
	player:SetAttribute("IsRunning", false)
	player:SetAttribute("FlashlightOn", false)
	player:SetAttribute("Hidden", false)
	player:SetAttribute("RevivesUsed", 0)
	table.insert(self._connections, player.CharacterAdded:Connect(function()
		task.wait(0.1)
		self:_applyCharacterSpeed(player)
	end))
end

function PlayerStateService:_handleSprintRequest(player: Player, wantsSprint: boolean)
	if not self._sprintDebugSeen[player.UserId] then
		print(string.format("[MOTEL13] SprintState received from %s", player.Name)) -- debug, remove later
		self._sprintDebugSeen[player.UserId] = true
	end
	local state = self._states[player]
	if not state then
		return
	end
	if not self._roundActive or state.isDowned or state.isHidden then
		self:_setRunning(player, false)
		return
	end
	self:_setRunning(player, wantsSprint and state.stamina > 0)
end

function PlayerStateService:_handleFlashlightToggle(player: Player, enabled: boolean)
	local state = self._states[player]
	if not state then
		return
	end
	local allow = self._roundActive and not state.isDowned and state.flashlightBattery > 0
	state.flashlightOn = allow and enabled == true
	player:SetAttribute("FlashlightOn", state.flashlightOn)
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
	self._spectateUpdated:FireClient(player, alive[state.spectateIndex])
end

function PlayerStateService:_setRunning(player: Player, isRunning: boolean)
	local state = self._states[player]
	if not state or state.isRunning == isRunning then
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
	local state = self._states[player]
	if not state then
		return
	end
	local character = player.Character
	if not character then
		if not self._warnedMissingCharacter[player.UserId] then
			warn(string.format("[PlayerStateService] Missing character for %s", player.Name))
			self._warnedMissingCharacter[player.UserId] = true
		end
		return
	end
	self._warnedMissingCharacter[player.UserId] = nil
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		if not self._warnedMissingHumanoid[player.UserId] then
			warn(string.format("[PlayerStateService] Missing humanoid for %s", player.Name))
			self._warnedMissingHumanoid[player.UserId] = true
		end
		return
	end
	self._warnedMissingHumanoid[player.UserId] = nil
	if state.isDowned then
		humanoid.WalkSpeed = Config.Player.DownedWalkSpeed
	elseif state.isRunning then
		humanoid.WalkSpeed = Config.Player.SprintSpeed
	else
		humanoid.WalkSpeed = Config.Player.WalkSpeed
	end
end

function PlayerStateService:_tick(dt: number)
	self._sendAccumulator += dt
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
	end

	if self._sendAccumulator >= 0.2 then
		self._sendAccumulator = 0
	self._sprintDebugSeen = {}
		for player, _ in pairs(self._states) do
			self:_broadcastState(player)
		end
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
		isRunning = state.isRunning,
		flashlightOn = state.flashlightOn,
		hidden = state.isHidden,
		hint = state.hint,
	})
end

return PlayerStateService
