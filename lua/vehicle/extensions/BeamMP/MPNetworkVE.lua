-- Connection testing for direct VE sockets

local M = {}

local vehID = nil
local socket = require("socket")
local udp = nil
M.socketConnected = false

local notifiedLauncher

local function send(data)
    if udp then
        local sentDataLen = udp:send(data)
		return sentDataLen
    end
end

local function notifyLauncher()
    local sentDataLen = send("...:"..v.mpServerID.."")
	if sentDataLen and not M.socketConnected then
		M.socketConnected = true
	end
end

local function handleInput(rawData)
	local code, serverVehicleID, data = string.match(rawData, "^(%a)%:(%d+%-%d+)%:({.*})")
    if v.mpServerID ~= serverVehicleID then return end

	if code == 'i' then
		MPInputsVE.applyInputs(data)
	else
		log('W', 'handle', "Received unknown packet '"..tostring(code).."'! ".. rawData)
	end
end

local function handleElectrics(rawData)
	local code, serverVehicleID, data = string.match(rawData, "^(%a)%:(%d+%-%d+)%:({.*})")
    if v.mpServerID ~= serverVehicleID then return end

	if code == "e" then -- Electrics (indicators, lights etc...)
		MPElectricsVE.applyElectrics(data, serverVehicleID)
	else
		log('W', 'handle', "Received unknown packet '"..tostring(code).."'! ".. rawData)
	end
end

local function handleNodes(rawData)
	local code, serverVehicleID, data = string.match(rawData, "^(%a)%:(%d+%-%d+)%:(.*)")
    if v.mpServerID ~= serverVehicleID then return end

	if code == "n" then
		nodesVE.applyNodes(data)
	elseif code == "g" then
		nodesVE.applyBreakGroups(data)
	elseif code == "c" then
		controllerSyncVE.applyControllerData(data)
	else
		log('W', 'handle', "Received unknown packet '"..tostring(code).."'! ".. rawData)
	end
end

local function handlePowertrain(rawData)
	local code, serverVehicleID, data = string.match(rawData, "^(%a)%:(%d+%-%d+)%:({.*})")
    if v.mpServerID ~= serverVehicleID then return end

	if code == "l" then
		MPPowertrainVE.applyLivePowertrain(data)
	elseif code == "e" then
		MPPowertrainVE.applyEngineData(data)
	else
		log('W', 'handle', "Received unknown packet '"..tostring(code).."'! ".. rawData)
	end
end

local function handlePosPacket(rawData,dtSim,dtRaw)
	local code, serverVehicleID, data = string.match(rawData, "^(%a)%:(%d+%-%d+)%:({.*})")
    if v.mpServerID ~= serverVehicleID then return end
	if code == 'p' then
        positionVE.setVehiclePosRot(data,dtSim,dtRaw)
	else
		log('W', 'handle', "Received unknown packet '"..tostring(code).."'! ".. rawData)
	end
end

local HandleNetwork = {
	['V'] = function(params) handleInput(params) end, -- inputs and gears
	['W'] = function(params) handleElectrics(params) end,
	['X'] = function(params) handleNodes(params) end, -- currently disabled
	['Y'] = function(params) handlePowertrain(params) end, -- powertrain related things like diff locks and transfercases
	['Z'] = function(params,dtSim,dtRaw) handlePosPacket(params,dtSim,dtRaw) end, -- position and velocity
	--['R'] = function(params) MPControllerGE.handle(params) end, -- Controller data
}

local lastSimTime = obj:getSimTime()

local function onMPupdate(dtSim,dtRaw)
    if v.mpServerID and v.mpServerID ~= "" and not notifiedLauncher then
        notifiedLauncher = true
        notifyLauncher()
    end
    -- Print received data
	local receivedData = false
    if udp then
        while true do
            local received = udp:receive()
            if received then
					receivedData = true
    				-- break it up into code + data
    				local code = string.sub(received, 1, 1)
    				local data = string.sub(received, 2)
                    if HandleNetwork[code] then
    				    HandleNetwork[code](data,dtSim,dtRaw)
                    else
                        log('D', "updateGFX", "Vehicle " .. tostring(vehID) .. " received data: " .. tostring(data))
                    end
            else
                break
            end
        end
    end
	if receivedData and not M.socketConnected then
		M.socketConnected = true
	end
end

local function onInit()
    vehID = obj:getID()
    log('D', "onInit", "Setting up direct VE UDP socket for vehicle " .. tostring(vehID))

    udp = socket.udp()
    udp:settimeout(0)
    udp:setpeername((settings.getValue("launcherIp") or '127.0.0.1'), (settings.getValue("launcherPort") or 4444)+2)
end

local function onExtensionUnloaded()
    log('D', "onExtensionUnloaded", "Closing UDP socket for vehicle " .. tostring(vehID))

    if udp then
        udp:close()
        udp = nil
    end
end

M.send = send
M.onMPupdate = onMPupdate
M.onInit = onInit
M.onExtensionLoaded = onInit
M.onExtensionUnloaded = onExtensionUnloaded

return M