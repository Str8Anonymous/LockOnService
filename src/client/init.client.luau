--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- Change "Live" to whatever folder your NPCs are in
local Live = Workspace:WaitForChild("Live")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local LockOnService = require(Shared.LockOnService)

local currentTargetIndex = 1
local isLockedOn = false

-- // Helper Functions \\ --

local function getValidTargets(): { Model }
	local targets = {}
	for _, character in ipairs(Live:GetChildren()) do
		if
			character:IsA("Model")
			and character:FindFirstChild("Humanoid")
			and character:FindFirstChild("HumanoidRootPart")
		then
			table.insert(targets, character)
		end
	end
	return targets
end

local function toggleLockOn()
	local targets = getValidTargets()
	if #targets == 0 then
		warn("No targets found in folder")
		return
	end

	-- If we exceeded the list resets and unlocks camera
	if currentTargetIndex > #targets then
		LockOnService.stopLockOn()
		currentTargetIndex = 1
		isLockedOn = false
		return
	end

	local targetModel = targets[currentTargetIndex]

	if not targetModel then
		LockOnService.stopLockOn()
		currentTargetIndex = 1
		isLockedOn = false
		return
	end

	local rootPart = targetModel:FindFirstChild("HumanoidRootPart") :: BasePart

	if rootPart then
		local success = LockOnService.lockOn(rootPart)
		if success then
			isLockedOn = true
			currentTargetIndex += 1
		else
			-- If lock failed (distance etc) we will reset
			LockOnService.stopLockOn()
			currentTargetIndex = 0
		end
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	-- Using Middle Mouse OR F because idk if your middle mouse broken lol
	if input.UserInputType == Enum.UserInputType.MouseButton3 or input.KeyCode == Enum.KeyCode.F then
		toggleLockOn()
	end
end)
