
function OpenCookingMenu(tableId)
    local t = placedTables[tableId]
    if not t then DebugPrint('No table '..tostring(tableId)); return end
    local s = methStatus[tableId]
    local currentStep = s.currentStep
    local isWaiting = s.isWaiting or false
    local statusText, statusColor, progressPercent = 'Ready', 'green', 0
    if s.isActive then statusText, statusColor, progressPercent = 'Cooking...', 'orange', ((currentStep-1)/#Config.CookingSteps)*100
    elseif isWaiting then statusText, statusColor, progressPercent = 'Waiting...', 'yellow', ((currentStep-1)/#Config.CookingSteps)*100
    elseif currentStep > #Config.CookingSteps then statusText, statusColor, progressPercent = 'Complete', 'blue', 100
    elseif currentStep > 1 then statusText, statusColor, progressPercent = 'In Progress', 'cyan', ((currentStep-1)/#Config.CookingSteps)*100 end
    local ctx = {}
    table.insert(ctx, { title = 'Status: '..statusText, description = 'Progress: '..math.floor(progressPercent)..'% ('..math.max(0,currentStep-1)..'/'..#Config.CookingSteps..')', icon = 'fas fa-info-circle', iconColor = statusColor, disabled = false, progress = math.floor(progressPercent) })
    if isWaiting and s.waitEndTime then
        local left = math.max(0, s.waitEndTime - GetGameTimer())
        table.insert(ctx, { title = 'Wait Timer', description = math.ceil(left/1000)..' seconds remaining', icon = 'fas fa-clock', iconColor = 'yellow' })
    end
    table.insert(ctx, { title = 'Cooking Options', description = 'View steps', icon = 'fas fa-fire', iconColor = 'red', menu = 'meth_cooking_steps_'..tableId })
    lib.registerContext({ id = 'meth_cooking_menu_'..tableId, title = 'Meth Cooking Table', options = ctx })
    CreateCookingStepsSubmenu(tableId, s, currentStep, isWaiting)
    lib.showContext('meth_cooking_menu_'..tableId)
end

function CreateCookingStepsSubmenu(tableId, status, currentStep, isWaiting)
    local steps = {}
    if currentStep > #Config.CookingSteps then
        table.insert(steps, { title = 'Process Complete', description = 'Pick up the table to start again', icon = 'fas fa-check-circle', iconColor = 'green' })
    else
        for i = 1, #Config.CookingSteps do
            local step = Config.CookingSteps[i]
            local stepIcon, stepColor, stepTitle, stepDesc, disabled, onSelect = 'fas fa-flask', 'white', step.label, step.description, false, nil
            if step.requiredItem then stepDesc = stepDesc..' (Requires: '..step.requiredAmount..'x '..step.requiredItem..')' end
            if i < currentStep then stepIcon, stepColor, stepTitle, stepDesc = 'fas fa-check', 'green', 'Done: '..step.label, 'Completed'
            elseif i == currentStep then
                if isWaiting then stepIcon, stepColor, stepTitle, stepDesc = 'fas fa-clock', 'yellow', 'Waiting: '..step.label, 'Waiting to proceed - '..stepDesc
                elseif status.isActive then stepIcon, stepColor, stepTitle, stepDesc = 'fas fa-cog', 'orange', 'Processing: '..step.label, 'Currently processing...'
                else stepIcon, stepColor, stepTitle, stepDesc, onSelect = 'fas fa-play', 'cyan', 'Start: '..step.label, 'Ready - '..stepDesc, function() ProcessCookingStep(tableId, step) end end
            else stepIcon, stepColor, stepTitle, stepDesc = 'fas fa-lock', 'gray', 'Locked: '..step.label, 'Complete previous steps first' end
            table.insert(steps, { title = stepTitle, description = stepDesc, icon = stepIcon, iconColor = stepColor, disabled = disabled, onSelect = onSelect })
        end
    end
    lib.registerContext({ id = 'meth_cooking_steps_'..tableId, title = 'Cooking Steps', menu = 'meth_cooking_menu_'..tableId, options = steps })
end
