local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = QBCore.Functions.GetPlayerData() -- Just for resource restart (same as event handler)
local radioMenu = false
local onRadio = false
local RadioChannel = 0
local RadioVolume = 50
local hasRadio = false
local radioProp = nil

--Function
local function LoadAnimDic(dict)
    if not HasAnimDictLoaded(dict) then
        RequestAnimDict(dict)
        while not HasAnimDictLoaded(dict) do
            Wait(0)
        end
    end
end

local function SplitStr(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        t[#t+1] = str
    end
    return t
end

local function connecttoradio(channel)
    RadioChannel = channel
    if onRadio then
        exports["pma-voice"]:setRadioChannel(0)
    else
        onRadio = true
        exports["pma-voice"]:setVoiceProperty("radioEnabled", true)
    end
    exports["pma-voice"]:setRadioChannel(channel)
    if SplitStr(tostring(channel), ".")[2] ~= nil and SplitStr(tostring(channel), ".")[2] ~= "" then
        QBCore.Functions.Notify(Config.messages['joined_to_radio'] ..channel.. ' MHz', 'success')
    else
        QBCore.Functions.Notify(Config.messages['joined_to_radio'] ..channel.. '.00 MHz', 'success')
    end
end

local function closeEvent()
	TriggerEvent("InteractSound_CL:PlayOnOne","click",0.6)
end

local function leaveradio()
    closeEvent()
    RadioChannel = 0
    onRadio = false
    exports["pma-voice"]:setRadioChannel(0)
    exports["pma-voice"]:setVoiceProperty("radioEnabled", false)
    QBCore.Functions.Notify(Config.messages['you_leave'] , 'error')
end

local function toggleRadioAnimation(pState)
	LoadAnimDic("cellphone@")
	if pState then
		TriggerEvent("attachItemRadio","radio01")
		TaskPlayAnim(PlayerPedId(), "cellphone@", "cellphone_text_read_base", 2.0, 3.0, -1, 49, 0, 0, 0, 0)
		radioProp = CreateObject(`prop_cs_hand_radio`, 1.0, 1.0, 1.0, 1, 1, 0)
		AttachEntityToEntity(radioProp, PlayerPedId(), GetPedBoneIndex(PlayerPedId(), 57005), 0.14, 0.01, -0.02, 110.0, 120.0, -15.0, 1, 0, 0, 0, 2, 1)
	else
		StopAnimTask(PlayerPedId(), "cellphone@", "cellphone_text_read_base", 1.0)
		ClearPedTasks(PlayerPedId())
		if radioProp ~= 0 then
			DeleteObject(radioProp)
			radioProp = 0
		end
	end
end

local function toggleRadio(toggle)
    radioMenu = toggle
    SetNuiFocus(radioMenu, radioMenu)
    if radioMenu then
        toggleRadioAnimation(true)
        SendNUIMessage({type = "open"})
    else
        toggleRadioAnimation(false)
        SendNUIMessage({type = "close"})
        DeleteObject(radioProp)
    end
end

local function IsRadioOn()
    return onRadio
end

local function DoRadioCheck(PlayerItems)
    local _hasRadio = false

    for _, item in pairs(PlayerItems) do
        if item.name == "radio" then
            _hasRadio = true
            break;
        end
    end

    hasRadio = _hasRadio
end

--Exports
exports("IsRadioOn", IsRadioOn)

--Events

-- Handles state right when the player selects their character and location.
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    DoRadioCheck(PlayerData.items)
end)

-- Resets state on logout, in case of character change.
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    DoRadioCheck({})
    PlayerData = {}
    leaveradio()
end)

-- Handles state when PlayerData is changed. We're just looking for inventory updates.
RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    PlayerData = val
    DoRadioCheck(PlayerData.items)
end)

-- Handles state if resource is restarted live.
AddEventHandler('onResourceStart', function(resource)
    if GetCurrentResourceName() == resource then
        PlayerData = QBCore.Functions.GetPlayerData()
        DoRadioCheck(PlayerData.items)
    end
end)

RegisterNetEvent('qb-radio:use', function()
    toggleRadio(not radioMenu)
end)

RegisterNetEvent('qb-radio:onRadioDrop', function()
    if RadioChannel ~= 0 then
        leaveradio()
    end
end)

-- NUI
RegisterNUICallback('joinRadio', function(data, cb)
    local rchannel = tonumber(data.channel)
    if rchannel ~= nil then
        if rchannel <= Config.MaxFrequency and rchannel ~= 0 then
            if rchannel ~= RadioChannel then
                if Config.RestrictedChannels[rchannel] ~= nil then
                    if Config.RestrictedChannels[rchannel][PlayerData.job.name] and PlayerData.job.onduty then
                        connecttoradio(rchannel)
                    else
                        QBCore.Functions.Notify(Config.messages['restricted_channel_error'], 'error')
                    end
                else
                    connecttoradio(rchannel)
                end
            else
                QBCore.Functions.Notify(Config.messages['you_on_radio'] , 'error')
            end
        else
            QBCore.Functions.Notify(Config.messages['invalid_radio'] , 'error')
        end
    else
        QBCore.Functions.Notify(Config.messages['invalid_radio'] , 'error')
    end
    cb("ok")
end)

RegisterNUICallback('leaveRadio', function(_, cb)
    if RadioChannel == 0 then
        QBCore.Functions.Notify(Config.messages['not_on_radio'], 'error')
    else
        leaveradio()
    end
    cb("ok")
end)

RegisterNUICallback("volumeUp", function(_, cb)
	if RadioVolume <= 95 then
		RadioVolume = RadioVolume + 5
		QBCore.Functions.Notify(Config.messages["volume_radio"] .. RadioVolume, "success")
		exports["pma-voice"]:setRadioVolume(RadioVolume)
	else
		QBCore.Functions.Notify(Config.messages["decrease_radio_volume"], "error")
	end
    cb('ok')
end)

RegisterNUICallback("volumeDown", function(_, cb)
	if RadioVolume >= 10 then
		RadioVolume = RadioVolume - 5
		QBCore.Functions.Notify(Config.messages["volume_radio"] .. RadioVolume, "success")
		exports["pma-voice"]:setRadioVolume(RadioVolume)
	else
		QBCore.Functions.Notify(Config.messages["increase_radio_volume"], "error")
	end
    cb('ok')
end)

RegisterNUICallback("increaseradiochannel", function(_, cb)
    local newChannel = RadioChannel + 1
    exports["pma-voice"]:setRadioChannel(newChannel)
    QBCore.Functions.Notify(Config.messages["increase_decrease_radio_channel"] .. newChannel, "success")
    cb("ok")
end)

RegisterNUICallback("decreaseradiochannel", function(_, cb)
    if not onRadio then return end
    local newChannel = RadioChannel - 1
    if newChannel >= 1 then
        exports["pma-voice"]:setRadioChannel(newChannel)
        QBCore.Functions.Notify(Config.messages["increase_decrease_radio_channel"] .. newChannel, "success")
        cb("ok")
    end
end)

RegisterNUICallback('poweredOff', function(_, cb)
    leaveradio()
    cb("ok")
end)

RegisterNUICallback('escape', function(_, cb)
    toggleRadio(false)
    cb("ok")
end)

--Main Thread
-- CreateThread(function()
--     while true do
--         Wait(1000)
--         if LocalPlayer.state.isLoggedIn and onRadio then
--             if not hasRadio or PlayerData.metadata.isdead or PlayerData.metadata.inlaststand then
--                 if RadioChannel ~= 0 then
--                     leaveradio()
--                 end
--             end
--         end
--     end
-- end)

CreateThread(function()
    while true do
        Wait(1000)
        if LocalPlayer.state.isLoggedIn and onRadio then
            if not hasRadio or PlayerData.metadata.isdead or PlayerData.metadata.inlaststand then
                if RadioChannel ~= 0 then
                    exports["pma-voice"]:setVoiceProperty("radioEnabled", false)
                end
            else
                exports["pma-voice"]:setVoiceProperty("radioEnabled", true)
            end
        end
    end
end)

RegisterNetEvent('qb-radio:client:JoinRadioChannel1', function(channel)
    QBCore.Functions.TriggerCallback('qb-radio:radiocheck', function(radio)
        if radio then
            local channel = 1
            RadioChannel = channel
            exports["pma-voice"]:setRadioChannel(channel)
            SendNUIMessage({type = "radiochannel", radiochannel = tostring(RadioChannel)})
            if SplitStr(tostring(channel), ".")[2] ~= nil and SplitStr(tostring(channel), ".")[2] ~= "" then
                QBCore.Functions.Notify(Config.messages['joined_to_radio'] ..channel.. ' MHz', 'success')
            else
                QBCore.Functions.Notify(Config.messages['joined_to_radio'] ..channel.. '.00 MHz', 'success')
            end
        elseif not radio then
            QBCore.Functions.Notify(Config.messages['invalid_radio'], 'error')
        end
    end)
end)

RegisterNetEvent('qb-radio:client:JoinRadioChannel2', function(channel)
    QBCore.Functions.TriggerCallback('qb-radio:radiocheck', function(radio)
        if radio then
            local channel = 2
            RadioChannel = channel
            exports["pma-voice"]:setRadioChannel(channel)
            SendNUIMessage({type = "radiochannel", radiochannel = tostring(RadioChannel)})
            if SplitStr(tostring(channel), ".")[2] ~= nil and SplitStr(tostring(channel), ".")[2] ~= "" then
                QBCore.Functions.Notify(Config.messages['joined_to_radio'] ..channel.. ' MHz', 'success')
            else
                QBCore.Functions.Notify(Config.messages['joined_to_radio'] ..channel.. '.00 MHz', 'success')
            end
        elseif not radio then
            QBCore.Functions.Notify(Config.messages['invalid_radio'], 'error')
        end
    end)
end)


RegisterNetEvent('qb-radio:client:JoinRadioChannel3', function(channel)
    QBCore.Functions.TriggerCallback('qb-radio:radiocheck', function(radio)
        if radio then
            local channel = 3
            RadioChannel = channel
            exports["pma-voice"]:setRadioChannel(channel)
            SendNUIMessage({type = "radiochannel", radiochannel = tostring(RadioChannel)})
            if SplitStr(tostring(channel), ".")[2] ~= nil and SplitStr(tostring(channel), ".")[2] ~= "" then
                QBCore.Functions.Notify(Config.messages['joined_to_radio'] ..channel.. ' MHz', 'success')
            else
                QBCore.Functions.Notify(Config.messages['joined_to_radio'] ..channel.. '.00 MHz', 'success')
            end
        elseif not radio then
            QBCore.Functions.Notify(Config.messages['invalid_radio'], 'error')
        end
    end)
end)

RegisterNetEvent('qb-radio:client:JoinRadioChannel4', function(channel)
    QBCore.Functions.TriggerCallback('qb-radio:radiocheck', function(radio)
        if radio then
            local channel = 4
            RadioChannel = channel
            exports["pma-voice"]:setRadioChannel(channel)
            SendNUIMessage({type = "radiochannel", radiochannel = tostring(RadioChannel)})
            if SplitStr(tostring(channel), ".")[2] ~= nil and SplitStr(tostring(channel), ".")[2] ~= "" then
                QBCore.Functions.Notify(Config.messages['joined_to_radio'] ..channel.. ' MHz', 'success')
            else
                QBCore.Functions.Notify(Config.messages['joined_to_radio'] ..channel.. '.00 MHz', 'success')
            end
        elseif not radio then
            QBCore.Functions.Notify(Config.messages['invalid_radio'], 'error')
        end
    end)
end)

RegisterNetEvent('qb-radio:client:JoinRadioChannel5', function(channel)
    QBCore.Functions.TriggerCallback('qb-radio:radiocheck', function(radio)
        if radio then
            local channel = 5
            RadioChannel = channel
            exports["pma-voice"]:setRadioChannel(channel)
            SendNUIMessage({type = "radiochannel", radiochannel = tostring(RadioChannel)})
            if SplitStr(tostring(channel), ".")[2] ~= nil and SplitStr(tostring(channel), ".")[2] ~= "" then
                QBCore.Functions.Notify(Config.messages['joined_to_radio'] ..channel.. ' MHz', 'success')
            else
                QBCore.Functions.Notify(Config.messages['joined_to_radio'] ..channel.. '.00 MHz', 'success')
            end
        elseif not radio then
            QBCore.Functions.Notify(Config.messages['invalid_radio'], 'error')
        end
    end)
end)

RegisterNetEvent('qb-radio:client:JoinRadioChannel6', function(channel)
    QBCore.Functions.TriggerCallback('qb-radio:radiocheck', function(radio)
        if radio then
            local channel = 6
            RadioChannel = channel
            exports["pma-voice"]:setRadioChannel(channel)
            SendNUIMessage({type = "radiochannel", radiochannel = tostring(RadioChannel)})
            if SplitStr(tostring(channel), ".")[2] ~= nil and SplitStr(tostring(channel), ".")[2] ~= "" then
                QBCore.Functions.Notify(Config.messages['joined_to_radio'] ..channel.. ' MHz', 'success')
            else
                QBCore.Functions.Notify(Config.messages['joined_to_radio'] ..channel.. '.00 MHz', 'success')
            end
        elseif not radio then
            QBCore.Functions.Notify(Config.messages['invalid_radio'], 'error')
        end
    end)
end)

RegisterNetEvent('qb-radio:client:JoinRadioChannel7', function(channel)
    QBCore.Functions.TriggerCallback('qb-radio:radiocheck', function(radio)
        if radio then
            local channel = 7
            RadioChannel = channel
            exports["pma-voice"]:setRadioChannel(channel)
            SendNUIMessage({type = "radiochannel", radiochannel = tostring(RadioChannel)})
            if SplitStr(tostring(channel), ".")[2] ~= nil and SplitStr(tostring(channel), ".")[2] ~= "" then
                QBCore.Functions.Notify(Config.messages['joined_to_radio'] ..channel.. ' MHz', 'success')
            else
                QBCore.Functions.Notify(Config.messages['joined_to_radio'] ..channel.. '.00 MHz', 'success')
            end
        elseif not radio then
            QBCore.Functions.Notify(Config.messages['invalid_radio'], 'error')
        end
    end)
end)

RegisterNetEvent('qb-radio:client:JoinRadioChannel8', function(channel)
    QBCore.Functions.TriggerCallback('qb-radio:radiocheck', function(radio)
        if radio then
            local channel = 8
            RadioChannel = channel
            exports["pma-voice"]:setRadioChannel(channel)
            SendNUIMessage({type = "radiochannel", radiochannel = tostring(RadioChannel)})
            if SplitStr(tostring(channel), ".")[2] ~= nil and SplitStr(tostring(channel), ".")[2] ~= "" then
                QBCore.Functions.Notify(Config.messages['joined_to_radio'] ..channel.. ' MHz', 'success')
            else
                QBCore.Functions.Notify(Config.messages['joined_to_radio'] ..channel.. '.00 MHz', 'success')
            end
        elseif not radio then
            QBCore.Functions.Notify(Config.messages['invalid_radio'], 'error')
        end
    end)
end)

RegisterNetEvent('qb-radio:client:JoinRadioChannel9', function(channel)
    QBCore.Functions.TriggerCallback('qb-radio:radiocheck', function(radio)
        if radio then
            local channel = 9
            RadioChannel = channel
            exports["pma-voice"]:setRadioChannel(channel)
            SendNUIMessage({type = "radiochannel", radiochannel = tostring(RadioChannel)})
            if SplitStr(tostring(channel), ".")[2] ~= nil and SplitStr(tostring(channel), ".")[2] ~= "" then
                QBCore.Functions.Notify(Config.messages['joined_to_radio'] ..channel.. ' MHz', 'success')
            else
                QBCore.Functions.Notify(Config.messages['joined_to_radio'] ..channel.. '.00 MHz', 'success')
            end
        elseif not radio then
            QBCore.Functions.Notify(Config.messages['invalid_radio'], 'error')
        end
    end)
end)

RegisterNetEvent('qb-radio:client:JoinRadioChannel10', function(channel)
    QBCore.Functions.TriggerCallback('qb-radio:radiocheck', function(radio)
        if radio then
            local channel = 10
            RadioChannel = channel
            exports["pma-voice"]:setRadioChannel(channel)
            SendNUIMessage({type = "radiochannel", radiochannel = tostring(RadioChannel)})
            if SplitStr(tostring(channel), ".")[2] ~= nil and SplitStr(tostring(channel), ".")[2] ~= "" then
                QBCore.Functions.Notify(Config.messages['joined_to_radio'] ..channel.. ' MHz', 'success')
            else
                QBCore.Functions.Notify(Config.messages['joined_to_radio'] ..channel.. '.00 MHz', 'success')
            end
        elseif not radio then
            QBCore.Functions.Notify(Config.messages['invalid_radio'], 'error')
        end
    end)
end)

-- Added 08/17/2023 -rikmyr
RegisterCommand('increaseradiochannel', function()
    if not onRadio then return end
    if RadioChannel < Config.MaxFrequency then
        RadioChannel = RadioChannel + 1
        if Config.Debug then print(string.format('^5Debug^7: Increased Radio Channel to %s', RadioChannel)) end
        exports["pma-voice"]:setRadioChannel(RadioChannel)
        SendNUIMessage({type = "radiochannel", radiochannel = tostring(RadioChannel)})
        QBCore.Functions.Notify(Config.messages["increase_decrease_radio_channel"] .. RadioChannel, "success")
    end
end, false)

RegisterKeyMapping('increaseradiochannel', 'Radio Increase Channel', 'keyboard', Config.KeyMapping.IncreaseRadioChannel)


RegisterCommand('decreaseradiochannel', function()
    if not onRadio then return end
    if RadioChannel > 1 then
        RadioChannel = RadioChannel - 1
        if Config.Debug then print(string.format('^5Debug^7: Decreased Radio Channel to %s', RadioChannel)) end
        exports["pma-voice"]:setRadioChannel(RadioChannel)
        SendNUIMessage({type = "radiochannel", radiochannel = tostring(RadioChannel)})
        QBCore.Functions.Notify(Config.messages["increase_decrease_radio_channel"] .. RadioChannel, "success")
    end
end, false)

RegisterKeyMapping('decreaseradiochannel', 'Radio Decrease Channel', 'keyboard', Config.KeyMapping.DecreaseRadioChannel)


RegisterCommand('increaseradiochanneldecimal', function()
    if not onRadio then return end
    if RadioChannel < Config.MaxFrequency then
        RadioChannel = RadioChannel + 0.1
        if Config.Debug then print(string.format('^5Debug^7: Increased Radio Channel Decimal to %s', RadioChannel)) end
        exports["pma-voice"]:setRadioChannel(RadioChannel)
        SendNUIMessage({type = "radiochannel", radiochannel = tostring(RadioChannel)})
        QBCore.Functions.Notify(Config.messages["increase_decrease_radio_channel"] .. RadioChannel, "success")
    end
end, false)

RegisterKeyMapping('increaseradiochanneldecimal', 'Radio Increase Channel Decimal', 'keyboard', Config.KeyMapping.IncreaseRadioChannelDecimal)


RegisterCommand('decreaseradiochanneldecimal', function()
    if not onRadio then return end
    if RadioChannel > 0.1 then
        RadioChannel = RadioChannel - 0.1
        if Config.Debug then print(string.format('^5Debug^7: Decreased Radio Channel Decimal to %s', RadioChannel)) end
        exports["pma-voice"]:setRadioChannel(RadioChannel)
        SendNUIMessage({type = "radiochannel", radiochannel = tostring(RadioChannel)})
        QBCore.Functions.Notify(Config.messages["increase_decrease_radio_channel"] .. RadioChannel, "success")
    end
end, false)

RegisterKeyMapping('decreaseradiochanneldecimal', 'Radio Decrease Channel Decimal', 'keyboard', Config.KeyMapping.DecreaseRadioChannelDecimal)
