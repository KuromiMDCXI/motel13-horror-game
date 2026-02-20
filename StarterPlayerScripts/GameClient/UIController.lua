local Players = game:GetService("Players")

local UIController = {}
UIController.__index = UIController

function UIController.new()
	local self = setmetatable({}, UIController)
	self._player = Players.LocalPlayer
	self._gui = Instance.new("ScreenGui")
	self._gui.Name = "Motel13UI"
	self._gui.ResetOnSpawn = false
	self._gui.Parent = self._player:WaitForChild("PlayerGui")

	self._objectiveLabel = Instance.new("TextLabel")
	self._objectiveLabel.Size = UDim2.fromOffset(420, 80)
	self._objectiveLabel.Position = UDim2.fromOffset(20, 20)
	self._objectiveLabel.BackgroundTransparency = 0.3
	self._objectiveLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	self._objectiveLabel.TextColor3 = Color3.fromRGB(224, 224, 224)
	self._objectiveLabel.Font = Enum.Font.GothamBold
	self._objectiveLabel.TextXAlignment = Enum.TextXAlignment.Left
	self._objectiveLabel.TextYAlignment = Enum.TextYAlignment.Top
	self._objectiveLabel.TextSize = 16
	self._objectiveLabel.TextWrapped = true
	self._objectiveLabel.Parent = self._gui

	self._staminaBar = self:_makeBar("Stamina", 20, 110, Color3.fromRGB(87, 220, 140))
	self._batteryBar = self:_makeBar("Battery", 20, 150, Color3.fromRGB(233, 225, 95))

	self._roundLabel = Instance.new("TextLabel")
	self._roundLabel.Size = UDim2.fromOffset(300, 40)
	self._roundLabel.Position = UDim2.new(0.5, -150, 0, 20)
	self._roundLabel.BackgroundTransparency = 0.4
	self._roundLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	self._roundLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
	self._roundLabel.Font = Enum.Font.GothamSemibold
	self._roundLabel.TextSize = 18
	self._roundLabel.Parent = self._gui

	self._spectateLabel = Instance.new("TextLabel")
	self._spectateLabel.Size = UDim2.fromOffset(380, 45)
	self._spectateLabel.Position = UDim2.new(0.5, -190, 1, -60)
	self._spectateLabel.BackgroundTransparency = 0.4
	self._spectateLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	self._spectateLabel.TextColor3 = Color3.fromRGB(255, 122, 122)
	self._spectateLabel.Font = Enum.Font.GothamBold
	self._spectateLabel.TextSize = 17
	self._spectateLabel.Visible = false
	self._spectateLabel.Parent = self._gui

	return self
end

function UIController:_makeBar(title: string, x: number, y: number, color: Color3)
	local container = Instance.new("Frame")
	container.Size = UDim2.fromOffset(220, 28)
	container.Position = UDim2.fromOffset(x, y)
	container.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
	container.BackgroundTransparency = 0.25
	container.Parent = self._gui

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = container

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamSemibold
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Text = title
	label.Parent = container

	return container
end

function UIController:UpdateObjectives(state)
	self._objectiveLabel.Text = string.format(
		"OBJECTIVES\nKeys: %d/6\nFuses: %d/3\nPower: %s\nExit: %s",
		state.keysFound,
		state.fusesInserted,
		state.powerRestored and "ONLINE" or "OFFLINE",
		state.exitUnlocked and "UNLOCKED" or "LOCKED"
	)
end

function UIController:UpdateRound(roundData)
	self._roundLabel.Text = string.format("%s - %ds", roundData.state, roundData.timeRemaining)
end

function UIController:UpdatePlayerState(playerState)
	self._staminaBar.Fill.Size = UDim2.fromScale(playerState.stamina / playerState.staminaMax, 1)
	self._batteryBar.Fill.Size = UDim2.fromScale(playerState.flashlightBattery / playerState.flashlightBatteryMax, 1)
	self._spectateLabel.Visible = playerState.isDowned
	if playerState.isDowned then
		self._spectateLabel.Text = "YOU ARE DOWNED - [Q/E] to cycle spectate"
	end
end

function UIController:SetSpectateTarget(target: Player?)
	if target then
		self._spectateLabel.Text = "SPECTATING: " .. target.Name .. " [Q/E to switch]"
	elseif self._spectateLabel.Visible then
		self._spectateLabel.Text = "No alive players to spectate"
	end
end

function UIController:FlashJumpscare()
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	flash.BackgroundTransparency = 0.65
	flash.Parent = self._gui
	task.delay(0.12, function()
		flash:Destroy()
	end)
end

return UIController
