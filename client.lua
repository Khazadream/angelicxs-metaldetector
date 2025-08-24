ESX = nil
QBCore = nil
PlayerData = nil
PlayerJob = nil
PlayerGrade = nil

--local DetectorSpawn = false
local DetectorSpawn = {}
local DetectorEntity = {}
local CooldownTimer = false
local searchOnCoolDown = false

CreateThread(function()
	if Config.UseESX then
		ESX = exports["es_extended"]:getSharedObject()
	
		while not ESX.IsPlayerLoaded() do
			Wait(100)
		end
	
		PlayerData = ESX.GetPlayerData()
		PlayerJob = PlayerData.job.name
		PlayerGrade = PlayerData.job.grade

		RegisterNetEvent("esx:setJob", function(job)
			PlayerJob = job.name
			PlayerGrade = job.grade
		end)

	elseif Config.UseQBCore then

		QBCore = exports["qb-core"]:GetCoreObject()
			
		CreateThread(function ()
			while true do
				PlayerData = QBCore.Functions.GetPlayerData()
				if PlayerData.citizenid ~= nil then
					PlayerJob = PlayerData.job.name
					PlayerGrade = PlayerData.job.grade.level
					break
				end
				Wait(100)
			end
		end)


		RegisterNetEvent("QBCore:Client:OnJobUpdate", function(job)
			PlayerJob = job.name
			PlayerGrade = job.grade.level
		end)
	end
end)

CreateThread(function()
    local sleep
    while true do
        sleep = 3000
        local nearDetector = false
        local playerCoords = GetEntityCoords(PlayerPedId())
        for detectorName, detectorLocation in pairs(Config.Detectors) do
            for index, detector in pairs(detectorLocation) do
                local distance = #(playerCoords - vector3(detector.coords[1],detector.coords[2],detector.coords[3]))
                if distance <= 10 then
                    if detector.entity and not DetectorSpawn[detector.id] then
                        DetectorSpawn[detector.id] = true
                        CreateMetalDetector(detector)
                    end
                    sleep = 1000
                    if distance <= (detector.detectRadius*8) then
                        sleep = 5
                        if distance <= detector.detectRadius and not searchOnCoolDown then
                            sleep = detector.timer
                            Search(detector)
                            break
                        end
                    end
                elseif detector.entity and DoesEntityExist(DetectorEntity[detector.id]) and DetectorSpawn[detector.id] then
                    if distance > 30 then
                        DeleteObject(DetectorEntity[detector.id])
                        DeleteEntity(DetectorEntity[detector.id])
                        DetectorSpawn[detector.id] = false
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

function CreateMetalDetector(detector)
    local hash = GetHashKey('ch_prop_ch_metal_detector_01a')
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(10)
    end
    DetectorEntity[detector.id] = CreateObject(hash, detector.coords[1], detector.coords[2], (detector.coords[3]-1), 0, 0, 0)
    SetEntityHeading(DetectorEntity[detector.id], detector.heading)
    FreezeEntityPosition(DetectorEntity[detector.id], true)
    SetEntityInvincible(DetectorEntity[detector.id], true)
    SetModelAsNoLongerNeeded(hash)
end

function Search(detector)
    if not Exempt(detector.jobsExempt) then 
        local hasItem = false
        if detector.UseMainList ~= nil  and detector.UseMainList then 
            if Config.UseESX then
                PlayerData = ESX.GetPlayerData()
                for i = 1, #Config.MetalItems, 1 do
                    for k, v in ipairs(PlayerData.inventory) do
                        if v.name == Config.MetalItems[i] and v.count > 0 then
                            hasItem = true
                            break
                        end
                    end
                end
            elseif Config.UseQBCore then
                PlayerData = QBCore.Functions.GetPlayerData()
                for i = 1, #Config.MetalItems, 1 do
                    for slot, item in pairs(PlayerData.items) do
                        if PlayerData.items[slot] then
                            if item.name == Config.MetalItems[i] then
                                hasItem = true
                                break
                            end
                        end
                    end
                end
            end
        end
        if detector.items ~=nil and next(detector.items) then
            if Config.UseESX then
                PlayerData = ESX.GetPlayerData()
                for i = 1, #detector.items, 1 do
                    for k, v in ipairs(PlayerData.inventory) do
                        if v.name == detector.items[i] and v.count > 0 then
                            hasItem = true
                            break
                        end
                    end
                end
            elseif Config.UseQBCore then
                PlayerData = QBCore.Functions.GetPlayerData()
                for i = 1, #detector.items, 1 do
                    for slot, item in pairs(PlayerData.items) do
                        if PlayerData.items[slot] then
                            if item.name == detector.items[i] then
                                hasItem = true
                                break
                            end
                        end
                    end
                end
            end
        end
        if hasItem then
            searchOnCoolDown = true
            TriggerServerEvent('angelicxs-MDetector:Server:SoundPlayer', detector)
            if not CooldownTimer then
                PoliceAlert()
            end
        end
    end
end

function Exempt(data)
    if data == nil then return false end 
	local hasJob = false
	if data ~= nil and next(data) then
		for jobName, gradeLevel in pairs(data) do
			if PlayerJob == jobName and PlayerGrade >= gradeLevel then
				hasJob = true
				break
			end
		end
	end
	return hasJob
end

function PoliceAlert()
    CooldownTimer = true
    local time = Config.PoliceAlertCooldown
    TriggerEvent('angelicxs-MDetector:CustomDisptach')
    CreateThread(function()
        while true do
            Wait(1000)
            time = time-1
            if time <= 0 then
                break
            end
        end
        CooldownTimer = false
    end)
    -- while true do
    --     Wait(1000)
    --     time = time-1
    --     if time <= 0 then
    --         break
    --     end
    -- end
    -- CooldownTimer = false
end

RegisterNetEvent('angelicxs-MDetector:SoundPlayer', function(detector)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local distance = #(playerCoords - vector3(detector.coords[1],detector.coords[2],detector.coords[3]))
    local soundId = GetSoundId()
    local hearing = false
    if distance <= detector.soundRadious then
        hearing = true
        PlaySoundFromCoord(soundId, detector.sound, detector.coords[1], detector.coords[2], detector.coords[3])
        
        if detector.entity then
            -- SetEntityDrawOutlineColor(10, 170, 210, 200) -- set color
            SetEntityDrawOutlineColor(255, 50, 50, 0)    -- set redish color
            SetEntityDrawOutlineShader(0)                -- set shader
            SetEntityDrawOutline(DetectorEntity[detector.id], true)   -- toggle it on the entity (not inside loop, just once)
        end
    end
    if hearing then
        Wait(detector.timer)
        StopSound(soundId)
        searchOnCoolDown = false
        if detector.entity then
            SetEntityDrawOutline(DetectorEntity[detector.id], false)
        end
    end
end)
