--!strict
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local LockOnService = {}

-- // CONSTANTS \\ --
local SMOOTHNESS = 8 -- Determines how fast the camera moves to its target. (Higher is faster).
local SIDE_DISPLACEMENT = 0 -- How far to the right the camera is.
local CAMERA_HEIGHT = 2.5 -- How high the camera is from the character's root part.
local CAMERA_DISTANCE = 8 -- How far back the camera is.
local AUTO_UNLOCK_DISTANCE = 50 -- The max distance in studs before automatically unlocking.
local MAX_TRANSITION_TIME = 0.2 -- Max time to wait for transition out to finish.

-- // STATE \\ --
local transitionStartTime: number = 0
local target: BasePart? = nil
local stepConnection: RBXScriptConnection? = nil
local savedRelativeCFrame: CFrame? = nil

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- // PRIVATE HELPERS \\ --

--- Figures out where the camera should be while locked onto a target.
--- @param rootPart BasePart The player's HumanoidRootPart
--- @param targetPart BasePart The part the camera should focus on
--- @return CFrame The CFrame the camera should move toward
function LockOnService._computeLockedCFrame(rootPart: BasePart, targetPart: BasePart): CFrame
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

--- Figures out the camera position used when leaving lock on mode.
--- Uses the saved camera offset if available.
--- @param rootPart BasePart The player's HumanoidRootPart
--- @return CFrame The CFrame the camera should move toward during transitio
function LockOnService._computeResetCFrame(rootPart: BasePart): CFrame
	if savedRelativeCFrame then
		return rootPart.CFrame:ToWorldSpace(savedRelativeCFrame)
	end

	local offset = CFrame.new(SIDE_DISPLACEMENT, CAMERA_HEIGHT, CAMERA_DISTANCE)
	return rootPart.CFrame * offset
end

--- Runs every RenderStepped and updates the camera based on the current state.
--- This handles both lock on mode and the transition out.
--- @param dt number The delta time for the current frame
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
	local alpha: number

	-- Deciding which state we are going to handle based on if we have target ect.
	if target and target.Parent then
		-- Checking to make sure the rootpart is not far from the target
		local distance = (rootPart.Position - target.Position).Magnitude

		-- If distance is > then the max distance allowed we will stop the currnent lockOn and reset camera
		if distance > AUTO_UNLOCK_DISTANCE then
			LockOnService.stopLockOn()
			return
		end
		idealCFrame = LockOnService._computeLockedCFrame(rootPart, target)
		alpha = 1 - math.exp(-SMOOTHNESS * dt)
	else
		idealCFrame = LockOnService._computeResetCFrame(rootPart)

		local timeElapsed = os.clock() - transitionStartTime
		local remainingTime = MAX_TRANSITION_TIME - timeElapsed

		-- Checking if remaining time is <= dt
		if remainingTime <= dt then
			-- Setting alpha to 1 then disconnecting the connection and clearing saved values and reseting camera
			alpha = 1
			if stepConnection then
				stepConnection:Disconnect()
				stepConnection = nil
			end

			savedRelativeCFrame = nil
			camera.CameraType = Enum.CameraType.Custom
		else
			alpha = dt / remainingTime
		end
	end

	-- Moves camera if we have a CFrame
	if idealCFrame then
		camera.CFrame = camera.CFrame:Lerp(idealCFrame, alpha)
	end
end

-- // PUBLIC API \\ --

--- Locks the camera onto the given part.
--- Returns true if the lock on starts successfully.
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

--- Stops the current lock on and starts transitioning the camera back.
function LockOnService.stopLockOn()
	target = nil -- Signals the update loop to begin the transition.
	transitionStartTime = os.clock()
end

--- Gets the current lock on target if one exists.
--- @return BasePart? The part that is currently locked on or nil
function LockOnService.getLockedOn(): BasePart?
	return target
end

return LockOnService
