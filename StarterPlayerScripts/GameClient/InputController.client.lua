local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local sprintStateRemote = remotes:WaitForChild("SprintState")
local flashlightToggleRemote = remotes:WaitForChild("FlashlightToggle")
local requestSpectateTarget = remotes:WaitForChild("RequestSpectateTarget")

local wantsSprint = false
local flashlightEnabled = false

local function sendSprint(newState: boolean)
	if wantsSprint == newState then
		return
	end
	wantsSprint = newState
	sprintStateRemote:FireServer(newState)
end

local function toggleFlashlight()
	flashlightEnabled = not flashlightEnabled
	flashlightToggleRemote:FireServer(flashlightEnabled)
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.LeftShift then
		sendSprint(true)
	elseif input.KeyCode == Enum.KeyCode.F then
		toggleFlashlight()
	elseif input.KeyCode == Enum.KeyCode.Q then
		requestSpectateTarget:FireServer(-1)
	elseif input.KeyCode == Enum.KeyCode.E then
		requestSpectateTarget:FireServer(1)
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.LeftShift then
		sendSprint(false)
	end
end)

local function bindTouchControls()
	local playerGui = player:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("Motel13HUD", 10)
	if not hud then
		return
	end

	local controls = hud:FindFirstChild("TouchControls")
	if not controls then
		return
	end

	local sprintButton = controls:FindFirstChild("SprintButton")
	local flashlightButton = controls:FindFirstChild("FlashlightButton")

	if sprintButton and sprintButton:IsA("TextButton") then
		sprintButton.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				sendSprint(true)
			end
		end)
		sprintButton.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				sendSprint(false)
			end
		end)
	end

	if flashlightButton and flashlightButton:IsA("TextButton") then
		flashlightButton.Activated:Connect(toggleFlashlight)
	end
end

task.defer(bindTouchControls)

player:GetAttributeChangedSignal("FlashlightOn"):Connect(function()
	flashlightEnabled = player:GetAttribute("FlashlightOn") == true
end)

player:GetAttributeChangedSignal("Downed"):Connect(function()
	if player:GetAttribute("Downed") then
		sendSprint(false)
	end
end)
