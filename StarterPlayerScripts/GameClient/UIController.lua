local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local UIController = {}
UIController.__index = UIController

function UIController.new(selectModeRemote: RemoteEvent)
	local self = setmetatable({}, UIController)
	self._player = Players.LocalPlayer
	self._selectModeRemote = selectModeRemote

	self._gui = Instance.new("ScreenGui")
	self._gui.Name = "Motel13HUD"
	self._gui.ResetOnSpawn = false
	self._gui.IgnoreGuiInset = true
	self._gui.Parent = self._player:WaitForChild("PlayerGui")

	self._objectiveLabel = self:_createObjectivePanel()
	self._staminaFill, self._batteryFill = self:_createBottomBars()
	self._spectateLabel = self:_createSpectateLabel()
	self._hintLabel = self:_createHintLabel()
	self._touchFrame, self._sprintButton, self._flashlightButton = self:_createTouchControls()
	self._menuFrame = self:_createStartMenu()
	self._touchFrame.Visible = UserInputService.TouchEnabled

	return self
end

function UIController:_applyPanelStyle(frame: Frame)
	frame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
	frame.BackgroundTransparency = 0.28
	frame.BorderSizePixel = 0
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.3
	stroke.Parent = frame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame
end

function UIController:_createStartMenu(): Frame
	local frame = Instance.new("Frame")
	frame.Name = "StartMenu"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(0.34, 0.3)
	frame.Parent = self._gui
	self:_applyPanelStyle(frame)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.25)
	title.Font = Enum.Font.GothamBold
	title.Text = "MOTEL 13"
	title.TextSize = 32
	title.TextColor3 = Color3.fromRGB(235, 235, 235)
	title.Parent = frame

	local function createButton(name: string, text: string, y: number, mode: string)
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.AnchorPoint = Vector2.new(0.5, 0)
		btn.Position = UDim2.fromScale(0.5, y)
		btn.Size = UDim2.fromScale(0.7, 0.22)
		btn.Text = text
		btn.Font = Enum.Font.GothamMedium
		btn.TextSize = 18
		btn.TextColor3 = Color3.fromRGB(245, 245, 245)
		btn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		btn.BackgroundTransparency = 0.2
		btn.Parent = frame
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Transparency = 0.2
		stroke.Parent = btn
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = btn
		btn.Activated:Connect(function()
			self._selectModeRemote:FireServer(mode)
		end)
	end

	createButton("SoloButton", "SOLO", 0.36, "Solo")
	createButton("MultiButton", "MULTIPLAYER", 0.64, "Multi")

	return frame
end

function UIController:_createObjectivePanel(): TextLabel
	local panel = Instance.new("Frame")
	panel.Name = "ObjectivePanel"
	panel.AnchorPoint = Vector2.new(0, 0)
	panel.Position = UDim2.fromScale(0.02, 0.03)
	panel.Size = UDim2.fromScale(0.23, 0.13)
	panel.Parent = self._gui
	self:_applyPanelStyle(panel)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(8, 6)
	label.Size = UDim2.new(1, -16, 1, -12)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 13
	label.TextColor3 = Color3.fromRGB(240, 240, 240)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = true
	label.Parent = panel
	return label
end

function UIController:_createBar(parent: Instance, yScale: number, title: string, fillColor: Color3): Frame
	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.AnchorPoint = Vector2.new(0.5, 1)
	titleLabel.Position = UDim2.fromScale(0.5, yScale - 0.012)
	titleLabel.Size = UDim2.fromScale(0.7, 0.02)
	titleLabel.Text = title
	titleLabel.Font = Enum.Font.GothamMedium
	titleLabel.TextSize = 11
	titleLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
	titleLabel.Parent = parent

	local back = Instance.new("Frame")
	back.AnchorPoint = Vector2.new(0.5, 0)
	back.Position = UDim2.fromScale(0.5, yScale)
	back.Size = UDim2.fromScale(0.36, 0.016)
	back.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
	back.BackgroundTransparency = 0.22
	back.BorderSizePixel = 0
	back.Parent = parent

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.15
	stroke.Parent = back

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.Parent = back

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = fill

	return fill
end

function UIController:_createBottomBars(): (Frame, Frame)
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.fromScale(0.5, 0.96)
	holder.Size = UDim2.fromScale(0.5, 0.14)
	holder.BackgroundTransparency = 1
	holder.Parent = self._gui
	local staminaFill = self:_createBar(holder, 0.48, "STAMINA", Color3.fromRGB(220, 220, 220))
	local batteryFill = self:_createBar(holder, 0.72, "FLASHLIGHT", Color3.fromRGB(180, 215, 255))
	return staminaFill, batteryFill
end

function UIController:_createSpectateLabel(): TextLabel
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.fromScale(0.5, 0.9)
	label.Size = UDim2.fromScale(0.5, 0.04)
	label.BackgroundTransparency = 0.5
	label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	label.TextColor3 = Color3.fromRGB(255, 130, 130)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 12
	label.Visible = false
	label.Parent = self._gui
	return label
end

function UIController:_createHintLabel(): TextLabel
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.fromScale(0.5, 0.84)
	label.Size = UDim2.fromScale(0.45, 0.038)
	label.BackgroundTransparency = 0.45
	label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	label.TextColor3 = Color3.fromRGB(230, 230, 230)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 12
	label.Visible = false
	label.Parent = self._gui
	return label
end

function UIController:_createTouchButton(parent: Instance, name: string, text: string, position: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.fromScale(0.42, 0.42)
	button.Position = position
	button.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
	button.BackgroundTransparency = 0.3
	button.TextColor3 = Color3.fromRGB(250, 250, 250)
	button.Font = Enum.Font.GothamMedium
	button.TextSize = 13
	button.Text = text
	button.AutoButtonColor = false
	button.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Transparency = 0.2
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Parent = button
	return button
end

function UIController:_createTouchControls(): (Frame, TextButton, TextButton)
	local frame = Instance.new("Frame")
	frame.Name = "TouchControls"
	frame.AnchorPoint = Vector2.new(1, 1)
	frame.Position = UDim2.fromScale(0.97, 0.92)
	frame.Size = UDim2.fromScale(0.23, 0.2)
	frame.BackgroundTransparency = 1
	frame.Parent = self._gui
	local sprint = self:_createTouchButton(frame, "SprintButton", "SPRINT", UDim2.fromScale(0, 0))
	local flashlight = self:_createTouchButton(frame, "FlashlightButton", "LIGHT", UDim2.fromScale(0.5, 0.5))
	return frame, sprint, flashlight
end

function UIController:UpdateRound(roundData)
	local inLobby = roundData.state == "Lobby"
	self._menuFrame.Visible = inLobby
end

function UIController:UpdateObjectives(state)
	self._objectiveLabel.Text = string.format(
		"KEYS %d/6\nFUSES %d/3\nPOWER %s\nEXIT %s",
		state.keysFound,
		state.fusesInserted,
		state.powerRestored and "ON" or "OFF",
		state.exitUnlocked and "UNLOCKED" or "LOCKED"
	)
end

function UIController:UpdatePlayerState(playerState)
	self._staminaFill.Size = UDim2.fromScale(playerState.stamina / playerState.staminaMax, 1)
	self._batteryFill.Size = UDim2.fromScale(playerState.flashlightBattery / playerState.flashlightBatteryMax, 1)
	self._spectateLabel.Visible = playerState.isDowned
	if playerState.isDowned then
		self._spectateLabel.Text = "DOWNED - Q / E TO SPECTATE"
	end
	local hasHint = playerState.hint and playerState.hint ~= ""
	self._hintLabel.Visible = hasHint
	if hasHint then
		self._hintLabel.Text = playerState.hint
	end
end

function UIController:SetSpectateTarget(target: Player?)
	if target then
		self._spectateLabel.Text = "SPECTATING: " .. target.Name .. " (Q/E)"
	elseif self._spectateLabel.Visible then
		self._spectateLabel.Text = "NO ALIVE PLAYERS"
	end
end

function UIController:SetSprintButtonActive(active: boolean)
	self._sprintButton.BackgroundColor3 = active and Color3.fromRGB(45, 45, 45) or Color3.fromRGB(14, 14, 14)
end

function UIController:SetFlashlightButtonActive(active: boolean)
	self._flashlightButton.BackgroundColor3 = active and Color3.fromRGB(60, 85, 110) or Color3.fromRGB(14, 14, 14)
end

function UIController:FlashJumpscare()
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	flash.BackgroundTransparency = 0.68
	flash.Parent = self._gui
	task.delay(0.1, function()
		flash:Destroy()
	end)
end

function UIController:PlayStaticBurst()
	self._hintLabel.Visible = true
	self._hintLabel.Text = "..."
	task.delay(0.2, function()
		if self._hintLabel.Text == "..." then
			self._hintLabel.Visible = false
			self._hintLabel.Text = ""
		end
	end)
end

return UIController
