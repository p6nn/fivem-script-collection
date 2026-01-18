
local QBX = exports.qbx_core

methStatus = {}
placedTables = {}

function DebugPrint(message)
    if Config.Debug then print('[PEN-METH] ' .. message) end
end

function ProcessCookingStep(tableId, step)
    local t = placedTables[tableId]
    local s = methStatus[tableId]
    if not t or not s or t.isActive or s.isWaiting then
        if s and s.isWaiting then lib.notify({ description = 'You must wait before the next step', type = 'error' }) end
        return
    end
    if step.requiredItem then
        TriggerServerEvent('pen-meth:server:checkAndRemoveItem', tableId, step.requiredItem, step.requiredAmount, step.id)
    else
        StartCookingAnimation(tableId, step)
    end
end

function StartCookingAnimation(tableId, step)
    local t = placedTables[tableId]
    if not t then return end
    t.isActive = true
    methStatus[tableId].isActive = true
    local p = PlayerPedId()
    if step.animation then
        RequestAnimDict(step.animation.dict)
        while not HasAnimDictLoaded(step.animation.dict) do Wait(5) end
        TaskPlayAnim(p, step.animation.dict, step.animation.anim, 8.0, -8.0, step.duration, 1, 0, false, false, false)
    end
    local ok = lib.progressBar({ duration = step.duration, label = step.progressLabel or step.label, useWhileDead = false, canCancel = false, disable = { car = true, move = true, combat = true } })
    ClearPedTasks(p)
    if ok then
        CompleteStep(tableId, step)
    else
        t.isActive = false
        methStatus[tableId].isActive = false
    end
end

function CompleteStep(tableId, step)
    local t = placedTables[tableId]
    local s = methStatus[tableId]
    if not t or not s then return end
    if step.reward then
        local amt = math.random(step.reward.minAmount, step.reward.maxAmount)
        local quality = nil
        if Config.MethQuality and Config.MethQuality.enabled then quality = GenerateMethQuality() end
        TriggerServerEvent('pen-meth:server:giveItem', step.reward.item, amt, quality)
        local qtxt = quality and (' ('..quality.name..' Quality)') or ''
        lib.notify({ description = 'You collected '..amt..'x '..step.reward.item..qtxt, type = 'success' })
        s.currentStep = 1
        s.isActive = false
        s.isWaiting = false
        t.isActive = false
        TriggerServerEvent('pen-meth:server:statusUpdate', tableId, s)
    else
        s.currentStep = s.currentStep + 1
        s.isActive = false
        t.isActive = false
        if Config.StepWait and Config.StepWait.enabled and s.currentStep <= #Config.CookingSteps then
            local waitDuration = Config.StepWait.useIndividualTimes and (step.waitAfter or Config.StepWait.defaultDuration) or Config.StepWait.defaultDuration
            if waitDuration > 0 then
                s.isWaiting = true
                s.waitEndTime = GetGameTimer() + waitDuration
                lib.notify({ description = step.label..' complete. Wait '..math.ceil(waitDuration/1000)..'s', type = 'success' })
                TriggerServerEvent('pen-meth:server:statusUpdate', tableId, s)
                CreateThread(function()
                    Wait(waitDuration)
                    if methStatus[tableId] then
                        methStatus[tableId].isWaiting = false
                        methStatus[tableId].waitEndTime = nil
                        lib.notify({ description = 'You can proceed to the next step', type = 'info' })
                        TriggerServerEvent('pen-meth:server:statusUpdate', tableId, methStatus[tableId])
                    end
                end)
            else
                lib.notify({ description = step.label..' completed', type = 'success' })
                TriggerServerEvent('pen-meth:server:statusUpdate', tableId, s)
            end
        else
            lib.notify({ description = step.label..' completed', type = 'success' })
            TriggerServerEvent('pen-meth:server:statusUpdate', tableId, s)
        end
    end
end

function GenerateMethQuality()
    if not Config.MethQuality or not Config.MethQuality.enabled then return nil end
    if not Config.MethQuality.qualities or #Config.MethQuality.qualities == 0 then return nil end
    local total = 0
    for _, q in ipairs(Config.MethQuality.qualities) do total = total + (q.chance or 0) end
    local roll = math.random(1, math.max(1,total))
    local acc = 0
    for _, q in ipairs(Config.MethQuality.qualities) do
        acc = acc + (q.chance or 0)
        if roll <= acc then
            return { name = q.name or 'Average', multiplier = q.multiplier or 1.0, purity = q.purity or 75, color = q.color or 'yellow' }
        end
    end
    local f = Config.MethQuality.qualities[1]
    return { name = f.name or 'Average', multiplier = f.multiplier or 1.0, purity = f.purity or 75, color = f.color or 'yellow' }
end

RegisterNetEvent('pen-meth:client:useMethTable', function()
    PlaceMethTable()
end)

RegisterNetEvent('pen-meth:client:itemCheckResponse', function(tableId, stepId, ok)
    if ok then
        local step = nil
        for _, s in ipairs(Config.CookingSteps) do if s.id == stepId then step = s break end end
        if step then StartCookingAnimation(tableId, step) end
    else
        lib.notify({ description = "You don't have the required items", type = 'error' })
    end
end)

AddEventHandler('onResourceStart', function(r) if GetCurrentResourceName() ~= r then return end CreateThread(function() local list = lib.callback.await('pen-meth:server:getTables'); if not list then return end for _, row in ipairs(list) do SpawnPersistentTable(row) end end) end)
