local M = {}

-- Tickrate - how often data is being sent from the client, 1 is 60hz, 2 is 30hz or half frame rate 4 is 15hz or 1/4 the frame rate
local nodesTickI = 0
local nodesTickrate = 4

local positionTickI = 0
local positionTickrate = 1

local inputsTickI = 0
local inputsTickrate = 2

local electricsTickI = 0
local electricsTickrate = 4

local powertrainTickI = 0
local powertrainTickrate = 6

local controllerTickI = 0
local controllerTickrate = 4

local function tick(dtRaw) -- called 60 times per second
	nodesTickI = nodesTickI + 1
	if nodesTickI >= nodesTickrate then
		nodesTickI = 0
		nodesVE.getBreakGroups() -- Comment this line to disable nodes synchronization
	end
	positionTickI = positionTickI + 1
	if positionTickI >= positionTickrate then
		positionTickI = 0
        positionVE.getVehicleRotation() -- Comment this line to disable position synchronization
	end
	inputsTickI = inputsTickI + 1
	if inputsTickI >= inputsTickrate then
		inputsTickI = inputsTickI
		MPInputsVE.getInputs() -- Comment this line to disable inputs synchronization
	end
	electricsTickI = electricsTickI + 1
	if electricsTickI >= electricsTickrate then
		electricsTickI = electricsTickI
		MPElectricsVE.check() -- Comment this line to disable electrics synchronization
	end
	powertrainTickI = powertrainTickI + 1
	if powertrainTickI >= powertrainTickrate then
		powertrainTickI = powertrainTickI
		MPPowertrainVE.check() -- Comment this line to disable powertrain synchronization
	end
	controllerTickI = controllerTickI + 1
	if controllerTickI >= controllerTickrate then
		controllerTickI = controllerTickI
		controllerSyncVE.getControllerData() -- Comment this line to disable controller synchronization
	end
end

local simSpeedSmooth = newTemporalSmoothingNonLinear(0.8)
simSpeedSmooth:set(1)

local lastSimTime = obj:getSimTime()
local lastCPUTime = os:clockhp()
local lastTick = math.floor(lastCPUTime)

local function onMPupdate()
    local simTime = obj:getSimTime()
    local cpuTime = os:clockhp()

	local dtSim = simTime - lastSimTime
	local dtRaw = cpuTime - lastCPUTime
    local simSpeed = 1

    if simTime ~= 0 then -- when in slow motion getSimTime can return 0, this makes dtSim the dt between 0 and now which can be in the thousands
	    lastSimTime = simTime
        simSpeed = dtSim/dtRaw
    else
        dtSim = 0
    end
	lastCPUTime = cpuTime
    positionVE.setGameSpeed(simSpeedSmooth:get(simSpeed,dtRaw)) -- TODO find a more stable solution for syncing, simulation speed is very inconsistent

	local tickTime = math.floor(cpuTime*60)
	if tickTime ~= lastTick and v.mpVehicleType == "L" then -- ticking by using CPU time should mean all vehicle packets gets sent at the same time, we could potentially use that to merge them all into one packet
    	tick(dtRaw)
	end
	lastTick = tickTime
    MPNetworkVE.onMPupdate(dtSim,dtRaw)

	return dtSim, dtRaw
end

local simUpdated = true

local function onDebugDraw()
	if not simUpdated then
		onMPupdate()
	end
	--extensions.hook("onBeamMPPreRender",dt)
	simUpdated = false
end

local frameCount = 0

local function updateGFX(dt)
	local dtSim, dtRaw = onMPupdate()
	frameCount = frameCount + 1
	extensions.hook("onBeamMPupdateGFX",dt ,dtRaw)
	simUpdated = true
end

M.onDebugDraw = onDebugDraw
M.updateGFX = updateGFX

return M