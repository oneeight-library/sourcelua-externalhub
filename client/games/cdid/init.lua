--[[
    OneEight External Hub - Car Driving Indonesia (CDID) Game Module
    Includes:
    1. SSOT Cash TextLabel Binding & Parser (OneEight Proven Method)
    2. East Java Truck Driver 6-State Farm Engine (Server-Synchronized)
    3. Low GPU Mode & Headquarters Teleportation
--]]

local CDIDModule = {}
CDIDModule.GameId = "cdid"
CDIDModule.GameName = "Car Driving Indonesia"
CDIDModule.CurrencyUnit = "Rp"
CDIDModule.MetricUnit = "Trips"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Context = nil
local activeCashLabel = nil

local State = {
    IsFarming = false,
    Status = "CONNECTED",
    CurrentRoute = "IDLE",
    TripCount = 0,
    TotalEarnings = 0,
    CurrentCash = 0,
    StartCash = 0,
    PreDeliveryCash = 0,
    LastSalary = 0,
    LowRender = false,
    MinDistance = 100000,
    CurrentTargetPos = nil,
    CurrentTargetName = nil,
    TRUCK_STARTER_POS = Vector3.new(34938.023, 135.125, -54577.938)
}

local function formatMoney(val)
    if not val then return "Rp 0" end
    local num = math.abs(math.floor(tonumber(val) or 0))
    local formatted = tostring(num):reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")
    return (tonumber(val) and tonumber(val) < 0 and "-Rp " or "Rp ") .. formatted
end

local function parseCashString(txt)
    if not txt then return 0 end
    local cleaned = tostring(txt):gsub("<[^<>]->", "")
    local numStr = cleaned:gsub("[^%d]", "")
    return tonumber(numStr) or 0
end

local function updateCash(txt)
    local val = parseCashString(txt)
    if val <= 0 then return end

    if not State.StartCash or State.StartCash == 0 then
        State.StartCash = val
        print(string.format("[OE-External CDID] Saldo Awal Terdeteksi: %s", formatMoney(val)))
    end

    State.CurrentCash = val
    if State.StartCash and State.StartCash > 0 then
        local netDiff = State.CurrentCash - State.StartCash
        if netDiff >= 0 and netDiff > State.TotalEarnings then
            State.TotalEarnings = netDiff
        end
    end
end

local function getCDIDCash()
    if activeCashLabel and activeCashLabel.Parent then
        local val = parseCashString(activeCashLabel.Text)
        if val > 0 then
            State.CurrentCash = val
            return val
        end
    end
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    if pGui then
        local ok, lbl = pcall(function()
            return pGui.Main.Container.Hub.CashFrame.Frame.TextLabel
        end)
        if ok and lbl then
            activeCashLabel = lbl
            local val = parseCashString(lbl.Text)
            if val > 0 then
                State.CurrentCash = val
                return val
            end
        end
    end
    return State.CurrentCash or 0
end

local function bindCashHUD()
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not pGui then return end

    local targetLabel = nil
    pcall(function()
        local main = pGui:WaitForChild("Main", 10)
        local container = main and main:WaitForChild("Container", 10)
        local hub = container and container:WaitForChild("Hub", 10)
        local cashFrame = hub and hub:WaitForChild("CashFrame", 10)
        local innerFrame = cashFrame and cashFrame:WaitForChild("Frame", 10)
        targetLabel = innerFrame and innerFrame:WaitForChild("TextLabel", 10)
    end)

    if targetLabel then
        activeCashLabel = targetLabel
        updateCash(targetLabel.Text)
        targetLabel:GetPropertyChangedSignal("Text"):Connect(function()
            updateCash(targetLabel.Text)
        end)
        print("[OE-External CDID] HUD Cash terhubung via Direct-Path TextLabel!")
    else
        task.spawn(function()
            local synced = false
            for _ = 1, 10 do
                if synced or not _G.OE_ExternalRunning then break end
                for _, desc in ipairs(pGui:GetDescendants()) do
                    if desc:IsA("TextLabel") and desc.Visible and not desc:GetFullName():find("cdid_hub") and not desc:GetFullName():find("Wind") then
                        local txt = desc.Text:gsub("<[^<>]->", "")
                        if txt:find("Rp") and not txt:find("%+") and not txt:find("%-") and not txt:lower():find("gaji") and not txt:lower():find("salary") and not txt:lower():find("delivery") and not txt:lower():find("trip") then
                            if txt:find("%d%d%d") or txt:find("%d%.%d") or txt:find("%d%,%d") then
                                activeCashLabel = desc
                                updateCash(desc.Text)
                                desc:GetPropertyChangedSignal("Text"):Connect(function()
                                    updateCash(desc.Text)
                                end)
                                synced = true
                                print("[OE-External CDID] HUD Cash terhubung via Fallback Scanning!")
                                break
                            end
                        end
                    end
                end
                task.wait(1.5)
            end
        end)
    end
end

-- ============================================================================
-- HELPER SUBROUTINES
-- ============================================================================
local Helpers = {}

function Helpers.GetValidHumanoid()
    local char = LocalPlayer.Character
    if not char then return nil, nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hum and hum.Health > 0 and hrp then
        return hum, hrp
    end
    return nil, nil
end

function Helpers.TeleportPlayerToHQ()
    local _, hrp = Helpers.GetValidHumanoid()
    if hrp then
        hrp.CFrame = CFrame.new(State.TRUCK_STARTER_POS + Vector3.new(0, 3, 0))
        task.wait(0.5)
    end
end

function Helpers.GetPlayerVehicle()
    local pCars = workspace:FindFirstChild("Vehicles") or workspace:FindFirstChild("Car") or workspace:FindFirstChild("Cars")
    if pCars then
        for _, car in ipairs(pCars:GetChildren()) do
            if car:IsA("Model") and car.Name:find(LocalPlayer.Name) then
                return car
            end
        end
    end
    return nil
end

function Helpers.CheckExistingWaypoint()
    pcall(function()
        local TruckArea = require(ReplicatedStorage.Shared.TruckArea)
        local targetIndex = LocalPlayer:GetAttribute("JobLocationIndex") or LocalPlayer:GetAttribute("CurrentLocationIndex")
        if targetIndex and TruckArea[targetIndex] then
            State.CurrentTargetPos = TruckArea[targetIndex].Location
            State.CurrentTargetName = TruckArea[targetIndex].txt
        end
    end)
    return State.CurrentTargetPos ~= nil
end

local function runFarmLoop()
    while State.IsFarming and _G.OE_ExternalRunning do
        local loopOk, loopErr = pcall(function()
            State.Status = "CLEANUP_CAR"
            local existingCar = Helpers.GetPlayerVehicle()
            if existingCar then
                pcall(function()
                    ReplicatedStorage.NetworkContainer.RemoteEvents.Despawn:FireServer()
                end)
                task.wait(1.0)
            end

            State.Status = "MOVING_TO_HQ"
            Helpers.TeleportPlayerToHQ()
            task.wait(0.8)

            State.Status = "ACCEPTING_JOB"
            local minStuds = tonumber(State.MinDistance) or 100000
            local routeFound = false
            local attempts = 0

            while State.IsFarming and not routeFound and attempts < 15 do
                attempts = attempts + 1
                pcall(function()
                    ReplicatedStorage.NetworkContainer.RemoteEvents.Job:FireServer("Truck")
                end)
                task.wait(1.2)

                Helpers.CheckExistingWaypoint()

                if State.CurrentTargetPos then
                    local _, hrp = Helpers.GetValidHumanoid()
                    local dist = hrp and (State.CurrentTargetPos - hrp.Position).Magnitude or 0

                    if dist >= minStuds then
                        routeFound = true
                        State.CurrentRoute = string.format("%s (%.0f km)", State.CurrentTargetName or "Cargo", dist / 1000)
                        if Context and Context.SendLog then
                            Context.SendLog(string.format("[Rute Diterima] %s (%.1f km)!", State.CurrentTargetName, dist / 1000), "SUCCESS")
                        end
                        break
                    else
                        pcall(function()
                            ReplicatedStorage.NetworkContainer.RemoteEvents.Job:FireServer("Unemployee")
                        end)
                        State.CurrentTargetPos = nil
                        State.CurrentTargetName = nil
                        task.wait(0.6)
                    end
                end
            end

            if not routeFound or not State.IsFarming then return end

            State.Status = "SPAWNING_TRUCK"
            local car = nil
            for _ = 1, 10 do
                if not State.IsFarming then break end
                pcall(function()
                    local prompt = workspace.Dealership.EastJava.Truck.DealerPart:FindFirstChildOfClass("ProximityPrompt")
                    if prompt then fireproximityprompt(prompt) end
                end)
                task.wait(1.5)
                car = Helpers.GetPlayerVehicle()
                if car then break end
            end

            if not car or not State.IsFarming then return end

            State.Status = "BOARDING_TRUCK"
            local seat = car:FindFirstChildWhichIsA("VehicleSeat", true)
            local hum = Helpers.GetValidHumanoid()
            if seat and hum then
                pcall(function() seat:Sit(hum) end)
                task.wait(1.0)
            end

            -- DELIVERY CYCLE
            while State.IsFarming and State.CurrentTargetPos do
                State.Status = "DRIVING_50S"
                local driveStart = os.clock()
                local lastLoggedSec = 0

                while (os.clock() - driveStart < 50) and State.IsFarming do
                    local elapsed = math.floor(os.clock() - driveStart)
                    if elapsed % 10 == 0 and elapsed ~= lastLoggedSec then
                        lastLoggedSec = elapsed
                        if Context and Context.SendLog then
                            Context.SendLog(string.format("[State 5] Simulasi Perjalanan Aman: %d/50 detik...", elapsed), "INFO")
                        end
                    end
                    task.wait(0.5)
                end

                if not State.IsFarming then break end

                State.Status = "TELEPORT_DESTINATION"
                local dropPos = State.CurrentTargetPos
                local stopPos = dropPos + Vector3.new(0, 3.5, 0)
                local flatDir = Vector3.new(0, 0, 1)
                local targetCF = CFrame.new(stopPos, stopPos + flatDir)

                State.PreDeliveryCash = State.CurrentCash or 0
                car:PivotTo(targetCF)

                for _, p in ipairs(car:GetDescendants()) do
                    if p:IsA("BasePart") then
                        p.AssemblyLinearVelocity = Vector3.zero
                        p.AssemblyAngularVelocity = Vector3.zero
                    end
                end
                task.wait(1.2)

                -- SSOT CASH DELTA PAYOUT VERIFICATION
                State.Status = "WAIT_PAYOUT"
                local cashBefore = State.PreDeliveryCash > 0 and State.PreDeliveryCash or getCDIDCash()
                local waitPayoutStart = os.clock()
                local gained = 0

                while (os.clock() - waitPayoutStart < 7.0) and State.IsFarming do
                    local curCash = getCDIDCash()
                    if curCash > cashBefore then
                        local delta = curCash - cashBefore
                        if delta >= 15000000 then
                            gained = delta
                            State.CurrentCash = curCash
                            break
                        end
                    end
                    task.wait(0.1)
                end

                if gained == 0 then
                    local curCash = getCDIDCash()
                    if curCash > cashBefore then
                        gained = curCash - cashBefore
                        State.CurrentCash = curCash
                    end
                end

                if not State.IsFarming then break end

                State.TripCount = State.TripCount + 1
                if gained > 0 then
                    State.LastSalary = gained
                    State.TotalEarnings = (State.TotalEarnings or 0) + gained
                    if State.StartCash and State.StartCash > 0 and (State.CurrentCash - State.StartCash) > State.TotalEarnings then
                        State.TotalEarnings = State.CurrentCash - State.StartCash
                    end
                    if Context and Context.SendLog then
                        Context.SendLog(string.format("[State 6] Pengiriman #%d Berhasil! Gaji masuk (+%s)", State.TripCount, formatMoney(gained)), "SUCCESS")
                    end
                else
                    if Context and Context.SendLog then
                        Context.SendLog(string.format("[State 6] Pengiriman #%d Selesai!", State.TripCount), "SUCCESS")
                    end
                end

                -- SMART CHAINING
                local lastDeliveredPos = State.CurrentTargetPos
                State.CurrentTargetPos = nil
                State.CurrentTargetName = nil

                local chainWait = 0
                while chainWait < 2.0 and not State.CurrentTargetPos and State.IsFarming do
                    task.wait(0.1)
                    chainWait = chainWait + 0.1
                    Helpers.CheckExistingWaypoint()
                end

                if not State.IsFarming then break end

                local canChain = false
                if State.CurrentTargetPos then
                    local _, pHrp = Helpers.GetValidHumanoid()
                    local curPos = pHrp and pHrp.Position or (lastDeliveredPos or Vector3.zero)
                    local chainDist = (State.CurrentTargetPos - curPos).Magnitude

                    if chainDist >= minStuds then
                        canChain = true
                        State.CurrentRoute = string.format("%s (%.0f km)", State.CurrentTargetName or "Chain", chainDist / 1000)
                        if Context and Context.SendLog then
                            Context.SendLog(string.format("[Smart Chain] Rute Sambungan: %s (%.1f km)!", State.CurrentTargetName, chainDist / 1000), "SUCCESS")
                        end
                        task.wait(0.5)
                    end
                end

                if not canChain then break end
            end

            State.Status = "CYCLE_COMPLETE"
            pcall(function() ReplicatedStorage.NetworkContainer.RemoteEvents.Job:FireServer("Unemployee") end)
            State.CurrentTargetPos = nil
            State.CurrentTargetName = nil
            task.wait(0.5)
            Helpers.TeleportPlayerToHQ()
        end)

        if not loopOk then
            warn("[CDID Exception Caught]:", tostring(loopErr))
            if Context and Context.SendLog then
                Context.SendLog("[Recovering] Exception: " .. tostring(loopErr) .. ". Pulih dalam 1.5s...", "WARN")
            end
            State.Status = "RECOVERING"
            task.wait(1.5)
        end
    end

    State.Status = "STOPPED"
    State.CurrentRoute = "IDLE"
end

-- ============================================================================
-- INTERFACE CONTRACT IMPLEMENTATION
-- ============================================================================
function CDIDModule.Init(coreContext)
    Context = coreContext
    task.spawn(function()
        LocalPlayer:WaitForChild("PlayerGui", 15)
        bindCashHUD()
    end)
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(2.0)
        bindCashHUD()
    end)
    print("[OE-External CDID] Modul Car Driving Indonesia siap!")
end

function CDIDModule.HandleCommand(action, payload)
    if action == "START_FARM" then
        if not State.IsFarming then
            State.IsFarming = true
            local curC = getCDIDCash()
            if curC > 0 and (not State.StartCash or State.StartCash == 0) then
                State.StartCash = curC
                State.CurrentCash = curC
            end
            if Context and Context.SendLog then
                Context.SendLog("Memulai State-Driven CDID Truck Farm", "SUCCESS")
            end
            task.spawn(runFarmLoop)
        end
        return true

    elseif action == "STOP_FARM" then
        State.IsFarming = false
        State.Status = "STOPPED"
        if Context and Context.SendLog then
            Context.SendLog("Menghentikan CDID AutoFarm...", "WARN")
        end
        return true

    elseif action == "TOGGLE_LOW_RENDER" then
        State.LowRender = not State.LowRender
        pcall(function()
            if typeof(RunService.Set3dRenderingEnabled) == "function" then
                RunService:Set3dRenderingEnabled(not State.LowRender)
            end
        end)
        if Context and Context.SendLog then
            Context.SendLog("Low GPU Mode: " .. (State.LowRender and "AKTIF (3D Off)" or "NONAKTIF (3D On)"), "INFO")
        end
        return true

    elseif action == "TELEPORT_HQ" then
        if Context and Context.SendLog then
            Context.SendLog("Teleportasi manual ke Depo HQ...", "INFO")
        end
        Helpers.TeleportPlayerToHQ()
        return true

    elseif action == "SET_MIN_DISTANCE" then
        if payload and payload.minDistance then
            State.MinDistance = tonumber(payload.minDistance) or 100000
            if Context and Context.SendLog then
                Context.SendLog("Batas jarak minimum diubah ke: " .. State.MinDistance .. " studs", "INFO")
            end
        end
        return true
    end

    return false
end

function CDIDModule.GetTelemetry()
    return {
        status = State.Status,
        currentRoute = State.CurrentRoute,
        tripCount = State.TripCount,
        totalEarnings = State.TotalEarnings,
        currentCash = State.CurrentCash,
        startCash = State.StartCash,
        isFarming = State.IsFarming,
        lowRender = State.LowRender,
        minDistance = State.MinDistance
    }
end

function CDIDModule.Cleanup()
    State.IsFarming = false
    State.Status = "STOPPED"
end

return CDIDModule
