local M = {}

-- Tickrate - how often data is being sent from the client, in seconds
local nodesTimer = 0
local nodesTickrate = 1/15

local positionTimer = 0
local positionTickrate = 1/60

local inputsTimer = 0
local inputsTickrate = 1/60

local electricsTimer = 0
local electricsTickrate = 1/15

local powertrainTimer = 0
local powertrainTickrate = 1/10

local controllerTimer = 0
local controllerTickrate = 1/15

local function tick(dt)
	nodesTimer = nodesTimer + dt
	if nodesTimer >= nodesTickrate then
		nodesTimer = (nodesTimer - nodesTickrate) % nodesTickrate
		nodesVE.getBreakGroups() -- Comment this line to disable nodes synchronization
	end
	positionTimer = positionTimer + dt
	if positionTimer >= positionTickrate then
		positionTimer = (positionTimer - positionTickrate) % positionTickrate
        positionVE.getVehicleRotation() -- Comment this line to disable position synchronization
	end
	inputsTimer = inputsTimer + dt
	if inputsTimer >= inputsTickrate then
		inputsTimer = (inputsTimer - inputsTickrate) % inputsTickrate
		MPInputsVE.getInputs() -- Comment this line to disable inputs synchronization
	end
	electricsTimer = electricsTimer + dt
	if electricsTimer >= electricsTickrate then
		electricsTimer = (electricsTimer - electricsTickrate) % electricsTickrate
		MPElectricsVE.check() -- Comment this line to disable electrics synchronization
	end
	powertrainTimer = powertrainTimer + dt
	if powertrainTimer >= powertrainTickrate then
		powertrainTimer = (powertrainTimer - powertrainTickrate) % powertrainTickrate
		MPPowertrainVE.check() -- Comment this line to disable powertrain synchronization
	end
	controllerTimer = controllerTimer + dt
	if controllerTimer >= controllerTickrate then
		controllerTimer = (controllerTimer - controllerTickrate) % controllerTickrate
		controllerSyncVE.getControllerData() -- Comment this line to disable controller synchronization
	end
end

local simSpeedSmooth = newTemporalSmoothingNonLinear(0.8)
simSpeedSmooth:set(1)

local lastSimTime = obj:getSimTime()
local lastCPUTime = os:clockhp()
local function onDebugDraw()
    local simTime = obj:getSimTime()
    local cpuTIme = os:clockhp()

	local dtSim = simTime - lastSimTime
	local dtRaw = cpuTIme - lastCPUTime
    local simSpeed = 1

    if simTime ~= 0 then -- when in slowmotion getSimTime can return 0, this makes dtSim the dt between 0 and now which can be in the thousands
	    lastSimTime = simTime
        simSpeed = dtSim/dtRaw
        else
        dtSim = 0
    end
	lastCPUTime = cpuTIme

    positionVE.setGameSpeed(simSpeedSmooth:get(simSpeed,dtRaw))
    tick(dtRaw)

    MPNetworkVE.onMPupdate(dtSim,dtRaw)

	controllerSyncVE.onBeamMPupdateGFX(dtSim)
	MPInputsVE.onBeamMPupdateGFX(dtSim)
	MPPowertrainVE.onBeamMPupdateGFX(dtSim)
	positionVE.onBeamMPupdateGFX(dtSim,dtRaw)
end


M.onDebugDraw = onDebugDraw

return M