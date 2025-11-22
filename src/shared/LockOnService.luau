--!strict
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local LockOnService = {}

-- // CONSTANTS \\ --
local SMOOTHNESS = 8 -- Determines how fast the camera moves to its target. (Higher is faster).
local EXIT_SMOOTHNESS = 20 -- How fast the camera blends back to default.
local SIDE_DISPLACEMENT = 0 -- How far to the right the camera is.
local CAMERA_HEIGHT = 2.5 -- How high the camera is from the character's root part.
local CAMERA_DISTANCE = 8 -- How far back the camera is.
local AUTO_UNLOCK_DISTANCE = 50 -- The max distance in studs before automatically unlocking.
local MAX_TRANSITION_TIME = 0.1 -- Max time to wait for transition out to finish.

-- // STATE \\ --
local transitionStartTime: number = 0
local target: BasePart? = nil
local stepConnection: RBXScriptConnection? = nil
local savedRelativeCFrame: CFrame? = nil

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- // PRIVATE HELPERS \\ --

--- Handles the camera logic when locked onto a target.
--- @param rootPart BasePart The player's HumanoidRootPart.
--- @param currentTarget BasePart The part to lock onto.
--- @return CFrame The ideal CFrame for the camera to look at.
function LockOnService._handleLockOn(rootPart: BasePart, currentTarget: BasePart): CFrame
	return LockOnService._getIdealCFrame(rootPart, currentTarget)
end

--- Handles the camera logic when transitioning back to the default camera.
--- @param rootPart BasePart The player's HumanoidRootPart.
--- @return CFrame? The ideal CFrame, or nil if the transition is finished.
function LockOnService._handleTransitionOut(rootPart: BasePart): CFrame?
	local idealCFrame: CFrame

	-- Restore relative CFrame if it exists, otherwise use default offset
	if savedRelativeCFrame then
		idealCFrame = rootPart.CFrame:ToWorldSpace(savedRelativeCFrame)
	else
		local offset = CFrame.new(SIDE_DISPLACEMENT, CAMERA_HEIGHT, CAMERA_DISTANCE)
		idealCFrame = rootPart.CFrame * offset
	end

	local distance = (camera.CFrame.Position - idealCFrame.Position).Magnitude
	local timeElapsed = os.clock() - transitionStartTime

	-- checking if distance or if time has elapsed
	if distance < 0.5 or timeElapsed > MAX_TRANSITION_TIME then
		if stepConnection then
			stepConnection:Disconnect()
			stepConnection = nil
		end

		-- Clean up state
		savedRelativeCFrame = nil
		camera.CameraType = Enum.CameraType.Custom
		return nil
	end

	return idealCFrame
end

--- The main update function that runs every frame on RenderStepped.
--- Decides whether to handle locking on or transitioning out.
function LockOnService._updateCamera(dt: number)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")

	-- Disconnect and reset if player or camera is missing
	if not rootPart or not camera then
		if stepConnection then
			stepConnection:Disconnect()
			stepConnection = nil
		end
		if camera then
			camera.CameraType = Enum.CameraType.Custom
		end
		return
	end

	local idealCFrame: CFrame?
	local currentSmoothness = SMOOTHNESS -- DEFAULTS to normal smoothness

	-- Deciding which state we are going to handle based on if we have target ect.
	if target and target.Parent then
		-- Checking to make sure the rootpart is not far from the target
		local distance = (rootPart.Position - target.Position).Magnitude

		-- If distance is > then the max distance allowed we will stop the currnent lockOn and reset camera
		if distance > AUTO_UNLOCK_DISTANCE then
			LockOnService.stopLockOn()
			return
		end
		idealCFrame = LockOnService._handleLockOn(rootPart, target)
	else
		idealCFrame = LockOnService._handleTransitionOut(rootPart)
		currentSmoothness = EXIT_SMOOTHNESS
	end

	-- Moves camera if we have a CFrame
	if idealCFrame then
		local alpha = 1 - math.exp(-currentSmoothness * dt)
		camera.CFrame = camera.CFrame:Lerp(idealCFrame, alpha)
	end
end

--- Calculates the ideal world CFrame for the camera based on the target.
--- @param rootPart BasePart The player's HumanoidRootPart.
--- @param targetPart BasePart The target part to look at.
--- @return CFrame The calculated goal CFrame.
function LockOnService._getIdealCFrame(rootPart: BasePart, targetPart: BasePart): CFrame
	if not rootPart or not targetPart then
		return CFrame.new()
	end

	local rootPosition = rootPart.Position
	local targetPosition = targetPart.Position

	local lookAtCFrame = CFrame.lookAt(rootPosition, targetPosition)

	local offsetVector = Vector3.new(SIDE_DISPLACEMENT, CAMERA_HEIGHT, CAMERA_DISTANCE)

	local goalPosition = lookAtCFrame:PointToWorldSpace(offsetVector)

	return CFrame.lookAt(goalPosition, targetPosition)
end

-- // PUBLIC API \\ --

--- Locks the camera onto the given part.
--- @param part BasePart The target to lock onto.
--- @return boolean Whether the lock on succeeded or not.
function LockOnService.lockOn(part: BasePart): boolean
	if not part then
		warn("LockOnService.lockOn: received a nil part.")
		return false
	end

	if not camera then
		warn("LockOnService.lockOn: Camera is not available.")
		return false
	end

	-- Check if the character exists and is compatible
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")

	if not rootPart or not rootPart:IsA("BasePart") then
		return false
	end

	-- checking distance
	local distance = (rootPart.Position - part.Position).Magnitude
	if distance > AUTO_UNLOCK_DISTANCE then
		return false
	end

	target = part
	camera.CameraType = Enum.CameraType.Scriptable

	-- Only connecting if we aren't already running
	if not stepConnection then
		savedRelativeCFrame = rootPart.CFrame:ToObjectSpace(camera.CFrame)
		stepConnection = RunService.RenderStepped:Connect(LockOnService._updateCamera)
	end

	return true
end

--- Resets the current target and begins the camera transition out.
function LockOnService.stopLockOn()
	target = nil -- Signals the update loop to begin the transition.
	transitionStartTime = os.clock()
end

--- Gets the currently locked target
function LockOnService.getLockedOn(): BasePart?
	return target
end

return LockOnService
