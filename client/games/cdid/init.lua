--[[
    OneEight External Hub - Car Driving Indonesia (CDID) Game Module
    Exact Clone of OneEight In-Game Truck Engine (CDID Farming Truck v1):
    - Full 4-Phase Tween Truck Engine (Fly 400 studs -> Adaptive Forward -> Sine Out Landing -> Release Trigger)
    - Waypoint & Destination Dynamic Detection (workspace.Etc.Waypoint & Destination)
    - Starter & Spawner ProximityPrompt Automation
    - Automatic Vehicle Seat Claim & ProximityPrompt firing
    - Disguised Reroll as "GET_BEST_DESTINATION"
    - Controlled 100% via WebSocket from Web Dashboard (Headless)
--]]

local CDIDModule = {}
CDIDModule.GameId = "cdid"
CDIDModule.GameName = "Car Driving Indonesia"
CDIDModule.CurrencyUnit = "Rp"
CDIDModule.MetricUnit = "Trips"

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local Context = nil

-- ============================================================================
-- 1. CORE ONEEIGHT LOGIC (100% CLONE FROM ONEEIGHT IN-GAME ENGINE)
-- ============================================================================
local Core = {}
Core.AutoFarm = false
Core.FarmSessionID = 0
Core.CurrentMoney = 0
Core.EarnedMoney = 0
Core.AverageEarning = 0
Core.SessionStartMoney = 0
Core.SessionStartTime = 0
Core.LastMoney = 0
Core.ActiveTweenConnections = {}
Core.CountdownTime = 0
Core.TripCount = 0
Core.LowRender = false
Core.CurrentRoute = "IDLE"
Core.CurrentStatus = "READY"

Core.Settings = {
    TweenDuration = 41.2,
    MinDistance = 100000
}

-- Utilities
function Core.parseMoney(text)
    if not text then return 0 end
    local cleanText = string.gsub(tostring(text), "[^%d]", "")
    return tonumber(cleanText) or 0
end

function Core.formatRupiah(amount)
    if not amount then return "Rp 0" end
    local formatted = tostring(math.floor(math.abs(tonumber(amount) or 0)))
    while true do  
        local k
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1.%2')
        if k == 0 then break end
    end
    return (tonumber(amount) and tonumber(amount) < 0 and "-Rp " or "Rp ") .. formatted
end

function Core.calculateDistance(posA, posB)
    if not posA or not posB then return 0 end
    return (posA - posB).Magnitude
end

-- Teleport Player Safe
function Core.teleportPlayerSafe(targetCFrame)
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.SeatPart then
            humanoid.Sit = false
            task.wait(0.1)
        end
        character:PivotTo(targetCFrame)
    end
end

-- Cleanup Truck Physics
function Core.cleanupTruckPhysics(car, originalStates)
    if not car then return end
    for part, states in pairs(originalStates) do
        if part and part.Parent and part:IsA("BasePart") then 
            pcall(function()
                part.CanCollide = states.CanCollide
                part.Anchored = states.Anchored
            end)
        end
    end
end

-- Waypoint & Destination Logic (OneEight exact functions)
function Core.getClosestWaypoint(referencePos)
    local wpFolder = Workspace:FindFirstChild("Etc") and Workspace.Etc:FindFirstChild("Waypoint")
    if wpFolder then
        local closestWP = nil
        local shortestDistance = math.huge
        if not referencePos and LocalPlayer.Character and LocalPlayer.Character.PrimaryPart then
            referencePos = LocalPlayer.Character.PrimaryPart.Position
        end
        for _, wp in ipairs(wpFolder:GetChildren()) do
            if wp.Name == "Waypoint" and wp:IsA("BasePart") then
                if referencePos then
                    local dist = (wp.Position - referencePos).Magnitude
                    if dist < shortestDistance then
                        shortestDistance = dist
                        closestWP = wp
                    end
                else
                    return wp
                end
            end
        end
        return closestWP
    end
    return nil
end

function Core.getDestPart(referencePos)
    local destFolder = Workspace:FindFirstChild("Etc") and Workspace.Etc:FindFirstChild("Job") and Workspace.Etc.Job:FindFirstChild("Truck")
    if destFolder and destFolder:FindFirstChild("Destination") then
        local closestPart = nil
        local shortestDistance = math.huge
        if not referencePos and LocalPlayer.Character and LocalPlayer.Character.PrimaryPart then
            referencePos = LocalPlayer.Character.PrimaryPart.Position
        end
        for _, part in ipairs(destFolder.Destination:GetChildren()) do
            if part:IsA("BasePart") then
                if referencePos then
                    local dist = (part.Position - referencePos).Magnitude
                    if dist < shortestDistance then
                        shortestDistance = dist
                        closestPart = part
                    end
                else
                    return part
                end
            end
        end
        return closestPart
    end
    return nil
end

-- UI / Web Sync Callbacks
Core.UpdateStatusUI = function(text)
    Core.CurrentStatus = text
    if Context and Context.SendLog then
        Context.SendLog(text, "INFO")
    end
end

Core.StartCountdown = function(duration)
    Core.CountdownTime = math.floor(duration or 0)
    task.spawn(function()
        local endTime = tick() + (duration or 0)
        while tick() < endTime and Core.AutoFarm do
            local remaining = math.max(0, math.floor(endTime - tick()))
            Core.CountdownTime = remaining
            task.wait(0.5)
        end
        Core.CountdownTime = 0
    end)
end

-- ============================================================================
-- MAIN TWEEN LOGIC (ONE-EIGHT 4-PHASE ENGINE)
-- ============================================================================
function Core.tweenTruckSafe(car, initialTargetPart, totalTweenTime, currentSession)
    if not car or not car.PrimaryPart or not initialTargetPart then return nil end
    local startCF = car:GetPivot()
    local flightHeight = 400
    local truckOriginalStates = {}

    for _, part in ipairs(car:GetDescendants()) do
        if part:IsA("BasePart") then
            truckOriginalStates[part] = { CanCollide = part.CanCollide, Anchored = part.Anchored }
            pcall(function() part.Anchored = true end)
        end
    end

    local proxyValue = Instance.new("CFrameValue")
    proxyValue.Value = startCF
    
    local connNoClip = RunService.Stepped:Connect(function()
        for _, part in ipairs(car:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
        if LocalPlayer.Character then
            for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
    end)
    
    local connProxy = RunService.Heartbeat:Connect(function()
        car:PivotTo(proxyValue.Value)
    end)
    table.insert(Core.ActiveTweenConnections, connNoClip)
    table.insert(Core.ActiveTweenConnections, connProxy)

    local function abortTweenAndCleanup()
        connNoClip:Disconnect()
        connProxy:Disconnect()
        proxyValue:Destroy()
        Core.cleanupTruckPhysics(car, truckOriginalStates)
    end

    local currentTarget = initialTargetPart
    local isTrackingDest = false

    -- FASE 1: NAIK
    Core.UpdateStatusUI("Flying Up...")
    Core.StartCountdown(3)
    local upAirCF = startCF + Vector3.new(0, flightHeight, 0)
    local tweenUp = TweenService:Create(proxyValue, TweenInfo.new(3, Enum.EasingStyle.Linear), {Value = upAirCF})
    tweenUp:Play() 
    while tweenUp.PlaybackState == Enum.PlaybackState.Playing do
        if not Core.AutoFarm or Core.FarmSessionID ~= currentSession then
            tweenUp:Cancel()
            abortTweenAndCleanup()
            return
        end
        task.wait(0.1)
    end

    -- FASE 2: MAJU 
    local initialTargetAirCF = CFrame.new(currentTarget.Position.X, upAirCF.Position.Y, currentTarget.Position.Z) * startCF.Rotation
    local totalDistance = math.max(1, (upAirCF.Position - initialTargetAirCF.Position).Magnitude)
    local adaptiveSpeed = totalDistance / (totalTweenTime or 41.2)

    local function startForwardTween(targetAirCF)
        local distance = (proxyValue.Value.Position - targetAirCF.Position).Magnitude
        local tTime = math.max(0.5, distance / adaptiveSpeed)
        Core.UpdateStatusUI(string.format("DRIVING (%ds)", math.ceil(tTime)))
        Core.StartCountdown(tTime)
        local fwd = TweenService:Create(proxyValue, TweenInfo.new(tTime, Enum.EasingStyle.Linear), {Value = targetAirCF})
        fwd:Play()
        return fwd
    end

    local currentFwdTween = startForwardTween(initialTargetAirCF)

    while currentFwdTween.PlaybackState == Enum.PlaybackState.Playing do
        if not Core.AutoFarm or Core.FarmSessionID ~= currentSession then
            currentFwdTween:Cancel()
            abortTweenAndCleanup()
            return
        end

        if not isTrackingDest then
            if (proxyValue.Value.Position - currentTarget.Position).Magnitude < 200 then
                local destPart = Core.getDestPart(proxyValue.Value.Position)
                if destPart then
                    currentFwdTween:Cancel()
                    currentTarget = destPart
                    isTrackingDest = true
                    Core.UpdateStatusUI("Destination Found! Retargeting...")
                    task.wait(0.1)
                    local newTargetAirCF = CFrame.new(currentTarget.Position.X, upAirCF.Position.Y, currentTarget.Position.Z) * startCF.Rotation
                    currentFwdTween = startForwardTween(newTargetAirCF)
                end
            end
        end
        task.wait(0.2)
    end

    -- FASE 3: TURUN
    Core.UpdateStatusUI("Landing...")
    Core.StartCountdown(4)
    local targetGroundCF = currentTarget.CFrame * CFrame.new(0, (car:GetExtentsSize().Y / 2) - 4.5, 0)
    local tweenDown = TweenService:Create(proxyValue, TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Value = targetGroundCF})
    tweenDown:Play() 
    while tweenDown.PlaybackState == Enum.PlaybackState.Playing do
        if not Core.AutoFarm or Core.FarmSessionID ~= currentSession then
            tweenDown:Cancel()
            abortTweenAndCleanup()
            return
        end
        task.wait(0.1)
    end

    -- FASE 4: CLEANUP & TOUCH TRIGGER
    abortTweenAndCleanup()
    if car.PrimaryPart and Core.AutoFarm and Core.FarmSessionID == currentSession then
        Core.UpdateStatusUI("Releasing & Triggering...")
        task.wait(0.5)
        for i = 1, 3 do
            if not Core.AutoFarm or Core.FarmSessionID ~= currentSession then break end
            car:PivotTo(car:GetPivot() * CFrame.new(0, -0.3, 0))
            task.wait(0.2)
            car:PivotTo(car:GetPivot() * CFrame.new(0, 0.3, 0))
            task.wait(0.2)
        end
    end
    return currentTarget
end

-- ============================================================================
-- AUTOFARM LOOP (ONE-EIGHT CLONE WITH DISGUISED REROLL)
-- ============================================================================
function Core.StartFarmLoop(sessionID)
    task.spawn(function()
        while Core.AutoFarm and Core.FarmSessionID == sessionID do
            local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
            local humanoid = character:WaitForChild("Humanoid", 10)
            if not humanoid then continue end

            Core.UpdateStatusUI("Taking Job...")
            pcall(function()
                ReplicatedStorage:WaitForChild("NetworkContainer"):WaitForChild("RemoteEvents"):WaitForChild("Job"):FireServer("Truck")
            end)
            task.wait(1)
            if not Core.AutoFarm or Core.FarmSessionID ~= sessionID then break end

            Core.UpdateStatusUI("Interacting Starter...")
            local starterFolder = Workspace:FindFirstChild("Etc") and Workspace.Etc:FindFirstChild("Job") and Workspace.Etc.Job:FindFirstChild("Truck") and Workspace.Etc.Job.Truck:FindFirstChild("Starter")
            if starterFolder then
                local starterPrompt = starterFolder:FindFirstChildWhichIsA("ProximityPrompt", true)
                if starterPrompt and starterPrompt.Parent then
                    starterPrompt.RequiresLineOfSight = false
                    starterPrompt.MaxActivationDistance = 50
                    Core.teleportPlayerSafe(starterPrompt.Parent:GetPivot() * CFrame.new(0, 5, 0))
                    task.wait(0.5)
                    if fireproximityprompt then
                        pcall(fireproximityprompt, starterPrompt)
                    else
                        starterPrompt:InputHoldBegin()
                        task.wait(0.2)
                        starterPrompt:InputHoldEnd()
                    end
                    task.wait(1.5)
                    if fireproximityprompt then
                        pcall(fireproximityprompt, starterPrompt)
                    else
                        starterPrompt:InputHoldBegin()
                        task.wait(0.2)
                        starterPrompt:InputHoldEnd()
                    end
                end
            end
            if not Core.AutoFarm or Core.FarmSessionID ~= sessionID then break end

            -- Hitung Jarak & Seleksi Rute Terbaik (Disguised Reroll)
            local rootPart = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
            task.wait(0.5) 
            local initialTarget = Core.getClosestWaypoint(rootPart and rootPart.Position) or Core.getDestPart(rootPart and rootPart.Position)
            if not initialTarget then
                task.wait(0.5)
                initialTarget = Core.getClosestWaypoint(rootPart and rootPart.Position) or Core.getDestPart(rootPart and rootPart.Position)
            end

            if initialTarget and rootPart then
                local initialDistance = Core.calculateDistance(rootPart.Position, initialTarget.Position)
                if initialDistance < Core.Settings.MinDistance then
                    -- Samarkan Reroll sebagai "GET_BEST_DESTINATION"
                    Core.CurrentStatus = "GET_BEST_DESTINATION"
                    if Context and Context.SendLog then
                        Context.SendLog("Menganalisis rute terbaik...", "INFO")
                    end
                    pcall(function()
                        ReplicatedStorage:WaitForChild("NetworkContainer"):WaitForChild("RemoteEvents"):WaitForChild("Job"):FireServer("Cancel")
                    end)
                    task.wait(1)
                    continue 
                end
            end
            if not Core.AutoFarm or Core.FarmSessionID ~= sessionID then break end

            -- Set Clean Route Name (Tanpa Tanda Kurung)
            local targetName = (initialTarget and initialTarget.Name ~= "Waypoint" and initialTarget.Name) or "PT CDID Cargo"
            Core.CurrentRoute = targetName
            if Context and Context.SendLog then
                Context.SendLog(string.format("Rute Terbaik: %s! Memunculkan truk...", targetName), "SUCCESS")
            end

            Core.UpdateStatusUI("Spawning Truck...")
            local spawnerFolder = Workspace:FindFirstChild("Etc") and Workspace.Etc:FindFirstChild("Job") and Workspace.Etc.Job:FindFirstChild("Truck") and Workspace.Etc.Job.Truck:FindFirstChild("Spawner")
            if spawnerFolder then
                local spawnerPrompt = spawnerFolder:FindFirstChildWhichIsA("ProximityPrompt", true)
                if spawnerPrompt and spawnerPrompt.Parent then
                    spawnerPrompt.RequiresLineOfSight = false
                    spawnerPrompt.MaxActivationDistance = 50
                    Core.teleportPlayerSafe(spawnerPrompt.Parent:GetPivot() * CFrame.new(0, 5, 0))
                    task.wait(1)
                    if fireproximityprompt then
                        pcall(fireproximityprompt, spawnerPrompt)
                    else
                        spawnerPrompt:InputHoldBegin()
                        task.wait(0.2)
                        spawnerPrompt:InputHoldEnd()
                    end
                    task.wait(1)
                end
            end
            if not Core.AutoFarm or Core.FarmSessionID ~= sessionID then break end

            Core.UpdateStatusUI("Entering Truck...")
            local truckName = LocalPlayer.Name .. "sCar" 
            local truck = Workspace:WaitForChild("Vehicles", 10) and Workspace.Vehicles:WaitForChild(truckName, 10)
            local driveSeat = truck and truck:WaitForChild("DriveSeat", 5)

            if driveSeat then
                local drivePrompt = driveSeat:FindFirstChildWhichIsA("ProximityPrompt", true)
                if drivePrompt then
                    drivePrompt.RequiresLineOfSight = false
                    drivePrompt.MaxActivationDistance = 50
                    Core.teleportPlayerSafe(driveSeat:GetPivot() * CFrame.new(0, 5, 0))
                    task.wait(1)
                    if fireproximityprompt then
                        pcall(fireproximityprompt, drivePrompt)
                    else
                        drivePrompt:InputHoldBegin()
                        task.wait(0.2)
                        drivePrompt:InputHoldEnd()
                    end
                    task.wait(0.3)
                end
            end
            if not Core.AutoFarm or Core.FarmSessionID ~= sessionID then break end

            if driveSeat and (driveSeat.Occupant ~= nil or humanoid.Sit == true) then
                local jobCancelled = false
                while Core.AutoFarm and Core.FarmSessionID == sessionID and (driveSeat.Occupant ~= nil or humanoid.Sit == true) do
                    local truckPos = truck.PrimaryPart and truck.PrimaryPart.Position
                    local currentTarget = Core.getClosestWaypoint(truckPos) or Core.getDestPart(truckPos)
                    if not currentTarget then
                        task.wait(1)
                        currentTarget = Core.getClosestWaypoint(truckPos) or Core.getDestPart(truckPos)
                    end

                    if currentTarget then
                        local currentDistance = Core.calculateDistance(truckPos, currentTarget.Position)
                        if currentDistance < Core.Settings.MinDistance then
                            Core.CurrentStatus = "GET_BEST_DESTINATION"
                            if Context and Context.SendLog then
                                Context.SendLog("Menganalisis rute terbaik...", "INFO")
                            end
                            pcall(function()
                                ReplicatedStorage:WaitForChild("NetworkContainer"):WaitForChild("RemoteEvents"):WaitForChild("Job"):FireServer("Cancel")
                            end)
                            if humanoid then humanoid.Sit = false end
                            jobCancelled = true
                            task.wait(1.2)
                            break 
                        end

                        local finalPartReached = Core.tweenTruckSafe(truck, currentTarget, Core.Settings.TweenDuration, sessionID)
                        local isDestination = finalPartReached and finalPartReached.Parent and finalPartReached.Parent.Name == "Destination"
                        if isDestination then
                            Core.TripCount = Core.TripCount + 1
                            if Context and Context.SendLog then
                                Context.SendLog(string.format("Pengiriman #%d Selesai! Menunggu pembayaran...", Core.TripCount), "SUCCESS")
                            end
                            Core.UpdateStatusUI("Reached Destination! Waiting 3s...")
                            task.wait(3)
                        else
                            local waitTimeout, originalPos = 0, currentTarget.Position
                            while currentTarget and currentTarget.Parent and (currentTarget.Position - originalPos).Magnitude < 2 and waitTimeout < 5 do
                                task.wait(0.5)
                                waitTimeout = waitTimeout + 0.5
                            end
                        end
                    else
                        break
                    end
                end

                if Core.AutoFarm and Core.FarmSessionID == sessionID and not jobCancelled then
                    Core.UpdateStatusUI("Job Complete!")
                    task.wait(2)
                end
            end
        end
    end)
end

function Core.ToggleFarm(state)
    Core.AutoFarm = state
    Core.FarmSessionID = Core.FarmSessionID + 1 
    
    if Core.AutoFarm then
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        local moneyLabel = playerGui and playerGui:FindFirstChild("Main") and 
                           playerGui.Main:FindFirstChild("Container") and 
                           playerGui.Main.Container:FindFirstChild("Hub") and 
                           playerGui.Main.Container.Hub:FindFirstChild("CashFrame") and 
                           playerGui.Main.Container.Hub.CashFrame:FindFirstChild("Frame") and 
                           playerGui.Main.Container.Hub.CashFrame.Frame:FindFirstChild("TextLabel")
                           
        if moneyLabel and moneyLabel.Text then
            Core.SessionStartMoney = Core.parseMoney(moneyLabel.Text)
            Core.LastMoney = Core.SessionStartMoney 
            Core.CurrentMoney = Core.SessionStartMoney
        end
        Core.SessionStartTime = tick()
        Core.CurrentStatus = "STARTING"
        if Context and Context.SendLog then
            Context.SendLog("Memulai OneEight Truck Auto Farm (Tween Mode)", "SUCCESS")
        end
        Core.StartFarmLoop(Core.FarmSessionID)
    else
        Core.CurrentStatus = "STOPPED"
        Core.CurrentRoute = "IDLE"
        Core.CountdownTime = 0
        if Context and Context.SendLog then
            Context.SendLog("Menghentikan OneEight Auto Farm...", "WARN")
        end
        for _, conn in ipairs(Core.ActiveTweenConnections) do
            pcall(function() conn:Disconnect() end)
        end
        table.clear(Core.ActiveTweenConnections)
    end
end

-- Tracker Saldo Real-Time
task.spawn(function()
    while true do
        task.wait(1)
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        local moneyLabel = playerGui and playerGui:FindFirstChild("Main") and 
                           playerGui.Main:FindFirstChild("Container") and 
                           playerGui.Main.Container:FindFirstChild("Hub") and 
                           playerGui.Main.Container.Hub:FindFirstChild("CashFrame") and 
                           playerGui.Main.Container.Hub.CashFrame:FindFirstChild("Frame") and 
                           playerGui.Main.Container.Hub.CashFrame.Frame:FindFirstChild("TextLabel")

        if moneyLabel and moneyLabel.Text then
            Core.CurrentMoney = Core.parseMoney(moneyLabel.Text)
            
            if Core.AutoFarm then
                if Core.SessionStartMoney == 0 then
                    Core.SessionStartMoney = Core.CurrentMoney
                    Core.LastMoney = Core.CurrentMoney
                end
                if Core.CurrentMoney ~= Core.LastMoney then
                    Core.EarnedMoney = Core.CurrentMoney - Core.SessionStartMoney
                    local runningHours = (tick() - Core.SessionStartTime) / 3600
                    if runningHours > 0 then
                        Core.AverageEarning = math.floor(Core.EarnedMoney / runningHours)
                    end
                    Core.LastMoney = Core.CurrentMoney
                end
            else
                Core.LastMoney = Core.CurrentMoney
            end
        end
    end
end)

-- ============================================================================
-- INTERFACE CONTRACT IMPLEMENTATION FOR EXTERNAL WEB CONTROL
-- ============================================================================
function CDIDModule.Init(coreContext)
    Context = coreContext
    print("[OE-External CDID] Modul OneEight Truck Engine resmi dimuat & terhubung ke Web!")
end

function CDIDModule.HandleCommand(action, payload)
    if action == "START_FARM" then
        if not Core.AutoFarm then
            Core.ToggleFarm(true)
        end
        return true

    elseif action == "STOP_FARM" then
        if Core.AutoFarm then
            Core.ToggleFarm(false)
        end
        return true

    elseif action == "TOGGLE_LOW_RENDER" then
        Core.LowRender = not Core.LowRender
        pcall(function()
            if typeof(RunService.Set3dRenderingEnabled) == "function" then
                RunService:Set3dRenderingEnabled(not Core.LowRender)
            end
        end)
        if Context and Context.SendLog then
            Context.SendLog("Low GPU Mode: " .. (Core.LowRender and "AKTIF (3D Off)" or "NONAKTIF (3D On)"), "INFO")
        end
        return true

    elseif action == "TELEPORT_HQ" then
        if Context and Context.SendLog then
            Context.SendLog("Teleportasi manual ke Depo HQ...", "INFO")
        end
        Core.teleportPlayerSafe(CFrame.new(34938, 138, -54578))
        return true

    elseif action == "SET_MIN_DISTANCE" then
        if payload and payload.minDistance then
            Core.Settings.MinDistance = tonumber(payload.minDistance) or 100000
            if Context and Context.SendLog then
                Context.SendLog("Konfigurasi Best Destination diperbarui: " .. tostring(Core.Settings.MinDistance), "INFO")
            end
        end
        return true
    end

    return false
end

function CDIDModule.GetTelemetry()
    local elapsedSec = (Core.AutoFarm and Core.SessionStartTime > 0) and math.floor(tick() - Core.SessionStartTime) or 0
    return {
        status = Core.CurrentStatus,
        currentRoute = Core.CurrentRoute,
        tripCount = Core.TripCount,
        totalEarnings = Core.EarnedMoney,
        currentCash = Core.CurrentMoney,
        startCash = Core.SessionStartMoney,
        isFarming = Core.AutoFarm,
        lowRender = Core.LowRender,
        minDistance = Core.Settings.MinDistance,
        farmDuration = elapsedSec
    }
end

function CDIDModule.Cleanup()
    Core.ToggleFarm(false)
end

return CDIDModule
