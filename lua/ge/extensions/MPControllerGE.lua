-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}

local function sendControllerData(data, gameVehicleID)
	if MPGameNetwork.launcherConnected() then
		local serverVehicleID = MPVehicleGE.getServerVehicleID(gameVehicleID)
		if serverVehicleID and MPVehicleGE.isOwn(gameVehicleID) then
			MPGameNetwork.send(MPNetworkHelpers.generatePacketBuffer('Rc',serverVehicleID,data))
		end
	end
end

local function applyControllerData(data, serverVehicleID)
	local gameVehicleID = MPVehicleGE.getGameVehicleID(serverVehicleID) or -1
	local veh = getObjectByID(gameVehicleID)
	if veh then
		veh:queueLuaCommand("controllerSyncVE.applyControllerData(mime.unb64(\'".. MPHelpers.b64encode(data) .."\'))")
	end
end

local function handle(rawData)
	local code, serverVehicleID, data = string.match(rawData, "^(%a)%:(%d+%-%d+)%:(.*)")

	local veh = MPVehicleGE.getVehicles()[serverVehicleID]

	if not veh or veh.isLocal then
		return
	end

	if code == "c" then
		applyControllerData(data, serverVehicleID)
	else
		log('W', 'handle', "Received unknown packet '"..tostring(code).."'! ".. rawData)
	end
end

M.handle                 = handle
M.sendControllerData	 = sendControllerData

M.applyControllerData	 = applyControllerData

M.onInit = function() setExtensionUnloadMode(M, "manual") end


return M
