local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestSprint = remotes:WaitForChild("RequestSprint")
local toggleFlashlight = remotes:WaitForChild("ToggleFlashlight")
local requestSpectateTarget = remotes:WaitForChild("RequestSpectateTarget")

local flashlightEnabled = false

local function sprintAction(_name: string, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		requestSprint:FireServer(true)
	elseif inputState == Enum.UserInputState.End then
		requestSprint:FireServer(false)
	end
	return Enum.ContextActionResult.Pass
end

local function flashlightAction(_name: string, inputState: Enum.UserInputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	flashlightEnabled = not flashlightEnabled
	toggleFlashlight:FireServer(flashlightEnabled)
	return Enum.ContextActionResult.Sink
end

local function spectatePrev(_name: string, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		requestSpectateTarget:FireServer(-1)
	end
	return Enum.ContextActionResult.Pass
end

local function spectateNext(_name: string, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		requestSpectateTarget:FireServer(1)
	end
	return Enum.ContextActionResult.Pass
end

ContextActionService:BindAction("M13_Sprint", sprintAction, false, Enum.KeyCode.LeftShift)
ContextActionService:BindAction("M13_Flashlight", flashlightAction, false, Enum.KeyCode.F)
ContextActionService:BindAction("M13_SpecPrev", spectatePrev, false, Enum.KeyCode.Q)
ContextActionService:BindAction("M13_SpecNext", spectateNext, false, Enum.KeyCode.E)
