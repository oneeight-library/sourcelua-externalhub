--[[
    OneEight External Hub - Master Modular Client Agent
    Version: 3.0.0 (Modular Game Contract & Kick Detection Engine)
    Automated Architecture with zero-overhead in-game execution.
--]]

if _G.OE_ExternalRunning then
    print("[OE-External] Instance sebelumnya terdeteksi, membersihkan...")
    _G.OE_ExternalRunning = false
    if _G.OE_ExternalSocket then
        pcall(function() _G.OE_ExternalSocket:Close() end)
    end
    task.wait(1)
end

_G.OE_ExternalRunning = true

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

-- ============================================================================
-- MODULAR INTERNAL VFS (ZERO NETWORK OVERHEAD)
-- ============================================================================
local Modules = {}

Modules["core/safety"] = function()
--[[
    OneEight External Hub - Core Safety & Kick Detection Engine
    Handles:
    1. Anti-AFK (20-minute idle bypass)
    2. Real-time Kick / Disconnect detection (GuiService & RobloxPromptGui)
    3. Auto-Rejoin subsystem with queue_on_teleport
--]]

local Safety = {}
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

Safety.AutoRejoin = true
Safety.RejoinDelay = 5
Safety.IsKicked = false
Safety.KickReason = nil
Safety.OnKickedCallback = nil

-- 1. Anti-AFK (Native VirtualUser simulation)
function Safety.StartAntiAFK()
    LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.zero)
        end)
    end)
end

-- 2. Trigger Kick Handler
local function handleKick(reason)
    if Safety.IsKicked then return end
    Safety.IsKicked = true
    Safety.KickReason = reason or "Roblox Disconnected"

    warn("[OE-External Safety] DISCONNECT / KICK DETECTED: " .. tostring(Safety.KickReason))

    if Safety.OnKickedCallback then
        pcall(Safety.OnKickedCallback, Safety.KickReason)
    end

    if Safety.AutoRejoin then
        task.spawn(function()
            print(string.format("[OE-External Safety] Auto-Rejoin aktif! Menghubungkan ulang dalam %d detik...", Safety.RejoinDelay))
            task.wait(Safety.RejoinDelay)
            Safety.RejoinNow()
        end)
    end
end

-- 3. Install Kick & Error Dialog Listeners
function Safety.InitKickDetector(onKickedCallback)
    Safety.OnKickedCallback = onKickedCallback

    -- Listener A: GuiService ErrorMessageChanged
    pcall(function()
        GuiService.ErrorMessageChanged:Connect(function(errMsg)
            if errMsg and #errMsg > 0 then
                handleKick(errMsg)
            end
        end)
    end)

    -- Listener B: CoreGui RobloxPromptGui promptOverlay
    pcall(function()
        local promptGui = CoreGui:WaitForChild("RobloxPromptGui", 10)
        local overlay = promptGui and promptGui:WaitForChild("promptOverlay", 10)
        if overlay then
            overlay.ChildAdded:Connect(function(child)
                if child.Name == "ErrorPrompt" then
                    local msgLabel = child:FindFirstChild("ErrorMessage", true)
                    local msg = msgLabel and msgLabel.Text or "Roblox Disconnected"
                    handleKick(msg)
                end
            end)
        end
    end)

    -- Listener C: Teleport Failures
    pcall(function()
        TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errMsg)
            if player == LocalPlayer then
                handleKick("Teleport Gagal: " .. tostring(errMsg or teleportResult))
            end
        end)
    end)
end

-- 4. Rejoin Server Now
function Safety.RejoinNow(loaderUrl)
    loaderUrl = loaderUrl or "https://externalhub.oneeight-project18.workers.dev/loader"
    local queue_teleport = (syn and syn.queue_on_teleport) or queue_on_teleport or (fluxus and fluxus.queue_on_teleport)
    if queue_teleport then
        pcall(function()
            queue_teleport(string.format([[
                task.wait(4)
                loadstring(game:HttpGet("%s"))()
            ]], loaderUrl))
        end)
    end

    pcall(function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)
end

return Safety

end

Modules["games/base_game"] = function()
--[[
    OneEight External Hub - Base Game Module Contract
    All game modules (CDID, DDS, etc.) must adhere to this interface contract.
--]]

local BaseGame = {}
BaseGame.__index = BaseGame

function BaseGame.New(gameId, gameName, currencyUnit, metricUnit)
    local self = setmetatable({}, BaseGame)
    self.GameId = gameId or "generic"
    self.GameName = gameName or "Generic Game"
    self.CurrencyUnit = currencyUnit or "Cash"
    self.MetricUnit = metricUnit or "Trips"
    self.IsFarming = false
    self.CurrentStatus = "READY"
    return self
end

function BaseGame:Init(coreContext)
    -- Abstract method to be overridden
    self.Context = coreContext
end

function BaseGame:HandleCommand(action, payload)
    -- Abstract method to be overridden
    -- Return boolean indicating whether command was handled
    return false
end

function BaseGame:GetTelemetry()
    -- Abstract method returning table of telemetry data
    return {
        status = self.CurrentStatus,
        isFarming = self.IsFarming
    }
end

function BaseGame:Cleanup()
    -- Clean up running loops, hooks, connections
    self.IsFarming = false
end

return BaseGame

end

Modules["games/cdid"] = function()
--[[
    OneEight External Hub - Car Driving Indonesia (CDID) Game Module
    100% Exact Port of OneEight Hub East Java Truck Driver Engine:
    - Preload streaming chunk & Safe landing (Anti-void)
    - Dynamic findTruckFolder & ProximityPrompt firing
    - Server Network Ownership via PromptDriveSeat fireproximityprompt
    - ReplicatedStorage.NetworkContainer.RemoteEvents.Waypoint listener
    - Ground Raycasting for realistic landing on asphalt
    - SSOT Cash Delta payout verification (>= 15jt)
    - Smart Chaining from destination drop-off
--]]

local CDIDModule = {}
CDIDModule.GameId = "cdid"
CDIDModule.GameName = "Car Driving Indonesia"
CDIDModule.CurrencyUnit = "Rp"
CDIDModule.MetricUnit = "Trips"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
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
    TRUCK_STARTER_POS = Vector3.new(34938.023, 135.125, -54577.938),
    DriveMinDuration = 50
}

-- ============================================================================
-- FORMATTERS & SSOT CASH
-- ============================================================================
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
-- DRIVE ENGINE & CAR HELPERS
-- ============================================================================
local DriveEngine = {}

function DriveEngine.GetValidHumanoid()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health > 0 then
        return hum, char:FindFirstChild("HumanoidRootPart")
    end
    return nil, nil
end

function DriveEngine.GetPlayerCar()
    local vehicles = Workspace:FindFirstChild("Vehicles") or Workspace:FindFirstChild("Car") or Workspace:FindFirstChild("Cars")
    if not vehicles then return nil end
    for _, v in ipairs(vehicles:GetChildren()) do
        if v:IsA("Model") and v.Name:find(LocalPlayer.Name, 1, true) then
            return v
        end
    end
    return nil
end

function DriveEngine.FixCarReadOnly(car)
    if not car then return end
    if not car:FindFirstChild("ReadOnly") then
        local ro = Instance.new("Folder")
        ro.Name = "ReadOnly"
        ro.Parent = car
    end
    if not car:FindFirstChild("A-Chassis Tune") then
        local tune = Instance.new("ModuleScript")
        tune.Name = "A-Chassis Tune"
        tune.Parent = car
    end
end

function DriveEngine.EnsureSeated(car)
    local hum, hrp = DriveEngine.GetValidHumanoid()
    if not hum or not hrp or not car then return false end

    DriveEngine.FixCarReadOnly(car)

    local seat = car:FindFirstChildWhichIsA("VehicleSeat", true)
        or car:FindFirstChild("DriveSeat", true)
        or car:FindFirstChild("DriverSeat", true)

    if not seat then return false end
    if hum.SeatPart == seat or hum.Sit then return true end

    local primary = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
    if primary then primary.Anchored = false end

    hrp.CFrame = seat.CFrame * CFrame.new(0, 0.5, 1.5)
    task.wait(0.2)

    -- Dapatkan Server Network Ownership via PromptDriveSeat
    local drivePrompt = seat:FindFirstChild("PromptDriveSeat", true)
        or seat:FindFirstChildWhichIsA("ProximityPrompt", true)
        or car:FindFirstChild("PromptDriveSeat", true)

    if drivePrompt then
        drivePrompt.RequiresLineOfSight = false
        drivePrompt.MaxActivationDistance = 35
        if fireproximityprompt then
            pcall(fireproximityprompt, drivePrompt)
        else
            drivePrompt:InputHoldBegin()
            task.wait((drivePrompt.HoldDuration or 0) + 0.1)
            drivePrompt:InputHoldEnd()
        end
    else
        pcall(function() seat:Sit(hum) end)
    end
    task.wait(0.5)
    return hum.Sit
end

-- ============================================================================
-- TRUCK FARM HELPERS (EXACT ONEEIGHT METHODS)
-- ============================================================================
local Helpers = {}

function Helpers.PreloadStream(targetPos)
    if not targetPos then return end
    task.spawn(function()
        pcall(function()
            local lp = Players.LocalPlayer
            if lp and typeof(lp.RequestStreamAroundAsync) == "function" then
                lp:RequestStreamAroundAsync(targetPos)
            elseif typeof(workspace.RequestStreamAroundAsync) == "function" then
                workspace:RequestStreamAroundAsync(targetPos)
            end
        end)
    end)
end

function Helpers.TeleportPlayerToHQ()
    local _, hrp = DriveEngine.GetValidHumanoid()
    if not hrp then return false end
    local hqPos = State.TRUCK_STARTER_POS
    local dist = (hrp.Position - hqPos).Magnitude

    if dist > 200 then
        Helpers.PreloadStream(hqPos)
        hrp.Anchored = true
        hrp.CFrame = CFrame.new(hqPos + Vector3.new(0, 3.5, 0))
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        task.wait(0.5)
        hrp.Anchored = false
    else
        hrp.CFrame = CFrame.new(hqPos + Vector3.new(0, 3.5, 0))
    end
    return true
end

function Helpers.findTruckFolder()
    local etcJob = workspace:FindFirstChild("Etc") and workspace.Etc:FindFirstChild("Job")
    if etcJob then
        local truck = etcJob:FindFirstChild("Truck")
        if truck then return truck end
    end

    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc.Name == "Truck" and (desc:FindFirstChild("Starter") or desc:FindFirstChild("Spawner")) then
            return desc
        end
    end
    return nil
end

function Helpers.checkExistingWaypoint()
    local waypointFolder = workspace:FindFirstChild("Etc") and workspace.Etc:FindFirstChild("Waypoint")
    if waypointFolder then
        local startPos = State.TRUCK_STARTER_POS
        for _, child in ipairs(waypointFolder:GetChildren()) do
            if child:IsA("BasePart") then
                local billboard = child:FindFirstChildWhichIsA("BillboardGui")
                local label = billboard and billboard:FindFirstChildWhichIsA("TextLabel")
                local txt = label and label.Text or child.Name
                local pos = child.Position
                local distFromHq = (pos - startPos).Magnitude

                if txt ~= "Truck" and distFromHq > 1000 then
                    State.CurrentTargetPos = pos
                    State.CurrentTargetName = txt
                    return true
                end
            end
        end
    end
    return false
end

local function autoFirePrompt(obj, preDelay)
    local _, hrp = DriveEngine.GetValidHumanoid()
    if not hrp then return end

    if not obj then
        Helpers.TeleportPlayerToHQ()
        local tf = Helpers.findTruckFolder()
        obj = tf and (tf:FindFirstChild("Starter") or tf:FindFirstChild("starter") or tf:FindFirstChild("Spawner"))
    end
    if not obj then return end

    local targetPivot = obj:GetPivot()
    local targetPos = targetPivot.Position
    local dist = (hrp.Position - targetPos).Magnitude

    if dist > 200 then
        Helpers.PreloadStream(targetPos)
        hrp.Anchored = true
        hrp.CFrame = targetPivot * CFrame.new(0, 0.5, 2)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        task.wait(0.4)
        hrp.Anchored = false
    else
        hrp.Anchored = false
        hrp.CFrame = targetPivot * CFrame.new(0, 0.5, 2)
        hrp.AssemblyLinearVelocity = Vector3.zero
    end
    task.wait(preDelay or 0.25)

    local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
    if not prompt then
        local waitT = 0
        while not prompt and waitT < 1.5 do
            task.wait(0.1)
            waitT = waitT + 0.1
            prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
        end
    end
    if not prompt then return end

    prompt.Enabled = true
    prompt.RequiresLineOfSight = false
    prompt.MaxActivationDistance = 35
    if fireproximityprompt then
        pcall(fireproximityprompt, prompt)
    else
        prompt:InputHoldBegin()
        task.wait((prompt.HoldDuration or 0) + 0.1)
        prompt:InputHoldEnd()
    end
end

-- Teleportasi Kendaraan Murni Settle 50 Detik & Raycast Aspal
local function teleportVehicleToDestination(car, targetPos, waitDuration)
    local waitTime = waitDuration or State.DriveMinDuration or 50
    local primary = car and (car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart"))
    local seat = car and car:FindFirstChildWhichIsA("VehicleSeat", true)
    if not car or not primary then return false end

    DriveEngine.EnsureSeated(car)

    local startTime = os.clock()
    local streamRequested = false
    print(string.format("[CDID Truck] Menunggu estimasi perjalanan %d detik (kendaraan diam murni)...", waitTime))

    while State.IsFarming and (os.clock() - startTime < waitTime) do
        local elapsed = os.clock() - startTime
        local remaining = math.max(0, math.ceil(waitTime - elapsed))
        State.Status = string.format("DRIVING (%ds)", remaining)

        if remaining <= 3 and not streamRequested then
            streamRequested = true
            Helpers.PreloadStream(targetPos)
        end
        task.wait(1.0)
    end

    if not State.IsFarming then return false end

    State.Status = "TELEPORT_DESTINATION"
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local ignoreList = { car, LocalPlayer.Character }
    if workspace:FindFirstChild("Etc") then table.insert(ignoreList, workspace.Etc) end
    rayParams.FilterDescendantsInstances = ignoreList

    local rayOrigin = Vector3.new(targetPos.X, targetPos.Y + 40, targetPos.Z)
    local groundRay = workspace:Raycast(rayOrigin, Vector3.new(0, -120, 0), rayParams)
    local landY = (groundRay and groundRay.Position.Y + 2.0) or targetPos.Y

    local startCF = car:GetPivot()
    local dirToTarget = (targetPos - startCF.Position).Unit
    local flatDir = Vector3.new(dirToTarget.X, 0, dirToTarget.Z).Unit
    local stopPos = Vector3.new(targetPos.X, landY, targetPos.Z)
    local targetCF = CFrame.new(stopPos, stopPos + flatDir)

    local hum = DriveEngine.GetValidHumanoid()
    if hum and not hum.Sit and seat then
        pcall(function() seat:Sit(hum) end)
    end

    State.PreDeliveryCash = State.CurrentCash or 0
    car:PivotTo(targetCF)

    for _, p in ipairs(car:GetDescendants()) do
        if p:IsA("BasePart") then
            p.AssemblyLinearVelocity = Vector3.zero
            p.AssemblyAngularVelocity = Vector3.zero
        end
    end
    task.wait(1.2)
    return true
end

-- ============================================================================
-- 6-STATE TRUCK AUTO FARM ENGINE
-- ============================================================================
local function runFarmLoop()
    while State.IsFarming and _G.OE_ExternalRunning do
        local loopOk, loopErr = pcall(function()
            -- STATE 1: DESPAWN OLD CAR
            local oldCar = DriveEngine.GetPlayerCar()
            if oldCar then
                State.Status = "DESPAWN_OLD"
                pcall(function()
                    ReplicatedStorage.NetworkContainer.RemoteEvents.Job:FireServer("Unemployee")
                end)
                local despawnWait = 0
                while DriveEngine.GetPlayerCar() and despawnWait < 3.0 and State.IsFarming do
                    task.wait(0.2)
                    despawnWait = despawnWait + 0.2
                end
            end

            if not State.IsFarming then return end

            -- STATE 2: ENROLL JOB & TELEPORT HQ
            State.Status = "ENROLL_JOB"
            pcall(function()
                ReplicatedStorage.NetworkContainer.RemoteEvents.Job:FireServer("Truck")
            end)
            task.wait(0.3)
            Helpers.TeleportPlayerToHQ()

            local _, hrp = DriveEngine.GetValidHumanoid()
            local hqWait = 0
            while hqWait < 3.0 and State.IsFarming do
                local currentDist = hrp and (hrp.Position - State.TRUCK_STARTER_POS).Magnitude or 999
                local tf = Helpers.findTruckFolder()
                if currentDist < 50 and tf and tf:FindFirstChild("Starter") then break end
                task.wait(0.2)
                hqWait = hqWait + 0.2
            end

            if not State.IsFarming then return end

            -- STATE 3: PICK CARGO (STARTER PROMPT)
            State.Status = "PICKING_CARGO"
            State.CurrentTargetPos = nil
            State.CurrentTargetName = nil

            local tf = Helpers.findTruckFolder()
            local starterObj = tf and (tf:FindFirstChild("Starter") or tf:FindFirstChild("starter"))
            autoFirePrompt(starterObj, 0.2)

            local waitedRoute = 0
            local starterRetried = false
            while not State.CurrentTargetPos and waitedRoute < 6.0 and State.IsFarming do
                Helpers.checkExistingWaypoint()
                if State.CurrentTargetPos then break end

                if waitedRoute >= 2.0 and not starterRetried then
                    starterRetried = true
                    if starterObj then autoFirePrompt(starterObj, 0.2) end
                end
                task.wait(0.15)
                waitedRoute = waitedRoute + 0.15
            end

            if not State.IsFarming then return end

            if not State.CurrentTargetPos then
                if Context and Context.SendLog then
                    Context.SendLog("Rute belum diterima server, mengulang pendaftaran...", "WARN")
                end
                pcall(function() ReplicatedStorage.NetworkContainer.RemoteEvents.Job:FireServer("Unemployee") end)
                task.wait(0.5)
                return
            end

            -- Evaluasi Jarak Minimum
            local minStuds = tonumber(State.MinDistance) or 100000
            local routeDist = (State.CurrentTargetPos - State.TRUCK_STARTER_POS).Magnitude

            if routeDist < minStuds then
                if Context and Context.SendLog then
                    Context.SendLog(string.format("Rute %s ditolak (%.0f < %.0f studs). Reroll...", State.CurrentTargetName or "?", routeDist, minStuds), "INFO")
                end
                pcall(function() ReplicatedStorage.NetworkContainer.RemoteEvents.Job:FireServer("Unemployee") end)
                State.CurrentTargetPos = nil
                State.CurrentTargetName = nil
                task.wait(0.5)
                return
            end

            -- STATE 4: SPAWN TRUCK
            State.Status = "SPAWN_TRUCK"
            State.CurrentRoute = string.format("%s (%.0f km)", State.CurrentTargetName or "Cargo", routeDist / 1000)
            if Context and Context.SendLog then
                Context.SendLog(string.format("Rute Cocok: %s (%.1f km)! Memunculkan truk...", State.CurrentTargetName, routeDist / 1000), "SUCCESS")
            end

            tf = Helpers.findTruckFolder()
            local spawnerObj = tf and (tf:FindFirstChild("Spawner") or tf:FindFirstChild("spawner"))
            autoFirePrompt(spawnerObj, 0.3)

            local car = nil
            for _ = 1, 15 do
                if not State.IsFarming then break end
                car = DriveEngine.GetPlayerCar()
                if car then break end
                task.wait(0.2)
            end

            if not car or not State.IsFarming then
                if Context and Context.SendLog then
                    Context.SendLog("Truk gagal terdeteksi di Workspace, retry...", "WARN")
                end
                return
            end

            -- STATE 5: BOARD TRUCK & DRIVE ESTIMATE (50S)
            State.Status = "BOARDING"
            DriveEngine.EnsureSeated(car)

            while State.IsFarming and State.CurrentTargetPos do
                local driveOk = teleportVehicleToDestination(car, State.CurrentTargetPos, State.DriveMinDuration)
                if not driveOk or not State.IsFarming then break end

                -- STATE 6: WAIT PAYOUT (SSOT CASH DELTA >= 15JT)
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
                        Context.SendLog(string.format("Pengiriman #%d Berhasil! Gaji masuk (+%s)", State.TripCount, formatMoney(gained)), "SUCCESS")
                    end
                else
                    if Context and Context.SendLog then
                        Context.SendLog(string.format("Pengiriman #%d Selesai!", State.TripCount), "SUCCESS")
                    end
                end

                -- SMART CHAINING: CEK RUTE SAMBUNGAN DARI DROPOFF
                local lastDeliveredPos = State.CurrentTargetPos
                State.CurrentTargetPos = nil
                State.CurrentTargetName = nil

                local chainWait = 0
                while chainWait < 2.0 and not State.CurrentTargetPos and State.IsFarming do
                    task.wait(0.1)
                    chainWait = chainWait + 0.1
                    Helpers.checkExistingWaypoint()
                end

                if not State.IsFarming then break end

                local canChain = false
                if State.CurrentTargetPos then
                    local _, pRoot = DriveEngine.GetValidHumanoid()
                    local curPos = pRoot and pRoot.Position or (lastDeliveredPos or Vector3.zero)
                    local chainDist = (State.CurrentTargetPos - curPos).Magnitude

                    if chainDist >= minStuds then
                        canChain = true
                        State.CurrentRoute = string.format("%s (%.0f km)", State.CurrentTargetName or "Chain", chainDist / 1000)
                        if Context and Context.SendLog then
                            Context.SendLog(string.format("[Smart Chain] Rute Sambungan Ditemukan: %s (%.1f km)!", State.CurrentTargetName, chainDist / 1000), "SUCCESS")
                        end
                        DriveEngine.EnsureSeated(car)
                        task.wait(0.5)
                    end
                end

                if not canChain then break end
            end

            -- SIKLUS SELESAI -> KEMBALI KE HQ
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

    -- Dynamic Waypoint listener dari server
    task.spawn(function()
        local TruckArea = nil
        local waypointEvent = nil
        for _ = 1, 15 do
            pcall(function()
                if not TruckArea and ReplicatedStorage:FindFirstChild("Shared") and ReplicatedStorage.Shared:FindFirstChild("TruckArea") then
                    TruckArea = require(ReplicatedStorage.Shared.TruckArea)
                end
                if not waypointEvent and ReplicatedStorage:FindFirstChild("NetworkContainer") and ReplicatedStorage.NetworkContainer:FindFirstChild("RemoteEvents") then
                    waypointEvent = ReplicatedStorage.NetworkContainer.RemoteEvents:FindFirstChild("Waypoint")
                end
            end)
            if TruckArea and waypointEvent then break end
            task.wait(1.0)
        end

        if waypointEvent and TruckArea then
            waypointEvent.OnClientEvent:Connect(function(jobType, locationIndex)
                if jobType == "Truck" and TruckArea[locationIndex] then
                    State.CurrentTargetPos = TruckArea[locationIndex].Location
                    State.CurrentTargetName = TruckArea[locationIndex].txt
                    print("🎯 [CDID Waypoint Event] Rute baru diterima: " .. tostring(State.CurrentTargetName))
                end
            end)
        end
    end)

    print("[OE-External CDID] Modul Car Driving Indonesia (Truck Driver) siap 100%!")
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

end

Modules["games/dds"] = function()
--[[
    OneEight External Hub - Drag Drive Simulator (DDS) Game Module
    Placeholder & Template for Drag Race, Taxi & Barista farming in DDS
--]]

local DDSModule = {}
DDSModule.GameId = "dds"
DDSModule.GameName = "Drag Drive Simulator"
DDSModule.CurrencyUnit = "Coins"
DDSModule.MetricUnit = "Races"

local Context = nil
local State = {
    IsFarming = false,
    Status = "STANDBY",
    RaceCount = 0,
    TotalEarnings = 0,
    CurrentCoins = 0,
    CurrentTrack = "201m"
}

function DDSModule.Init(coreContext)
    Context = coreContext
    print("[OE-External DDS] Modul Drag Drive Simulator diinisialisasi!")
end

function DDSModule.HandleCommand(action, payload)
    if action == "START_FARM" then
        State.IsFarming = true
        State.Status = "RACING"
        if Context and Context.SendLog then
            Context.SendLog("DDS Auto Race Dimulai!", "SUCCESS")
        end
        return true

    elseif action == "STOP_FARM" then
        State.IsFarming = false
        State.Status = "STOPPED"
        if Context and Context.SendLog then
            Context.SendLog("DDS Auto Race Dihentikan.", "WARN")
        end
        return true
    end
    return false
end

function DDSModule.GetTelemetry()
    return {
        status = State.Status,
        isFarming = State.IsFarming,
        tripCount = State.RaceCount,
        totalEarnings = State.TotalEarnings,
        currentCash = State.CurrentCoins,
        currentRoute = State.CurrentTrack
    }
end

function DDSModule.Cleanup()
    State.IsFarming = false
    State.Status = "STOPPED"
end

return DDSModule

end

local function requireModule(name)
    if Modules[name] then
        return Modules[name]()
    end
    error("[OE-External] Modul tidak ditemukan: " .. tostring(name))
end

-- ============================================================================
-- LOAD CORE SAFETY & KICK DETECTOR
-- ============================================================================
local Safety = requireModule("core/safety")
Safety.StartAntiAFK()

-- ============================================================================
-- DETECT ACTIVE GAME MODULE
-- ============================================================================
local placeId = game.PlaceId
local activeGameModule = nil

-- CDID Places: East Java (110369730911937), Jakarta (14005966837), etc.
if placeId == 110369730911937 or placeId == 14005966837 or placeId == 9233343468 or placeId == 9508940498 or placeId == 79488788685813 then
    activeGameModule = requireModule("games/cdid")
else
    -- Default / fallback to CDID for compatibility
    activeGameModule = requireModule("games/cdid")
end

-- ============================================================================
-- STATE & WEBSOCKET NETWORKING
-- ============================================================================
local WS_BASE_URL = "wss://externalhub.oneeight-project18.workers.dev/ws"
local WS_URL = string.format("%s?role=bot&name=%s&gameId=%s&gameName=%s&placeId=%s",
    WS_BASE_URL,
    HttpService:UrlEncode(LocalPlayer.Name),
    HttpService:UrlEncode(activeGameModule.GameId or "generic"),
    HttpService:UrlEncode(activeGameModule.GameName or "Roblox"),
    tostring(placeId)
)

local CoreState = {
    Socket = nil,
    BotId = nil,
    SessionStartTime = os.clock(),
    AutoRejoin = true
}

local function sendPacket(packetType, payload)
    if not CoreState.Socket then return end
    pcall(function()
        local data = HttpService:JSONEncode({
            type = packetType,
            payload = payload
        })
        CoreState.Socket:Send(data)
    end)
end

local function sendLog(msg, level)
    if not CoreState.Socket then return end
    pcall(function()
        local data = HttpService:JSONEncode({
            type = "LOG",
            message = tostring(msg),
            level = level or "INFO"
        })
        CoreState.Socket:Send(data)
    end)
end

-- Setup Kick Detector Listener
Safety.InitKickDetector(function(reason)
    sendLog("ROBLOX KICK / DISCONNECT: " .. tostring(reason), "ERROR")
    sendPacket("CLIENT_KICKED", {
        reason = reason,
        placeId = game.PlaceId,
        autoRejoin = Safety.AutoRejoin,
        rejoinDelay = Safety.RejoinDelay
    })
end)

-- Initialize Active Game Module with Core Context
activeGameModule.Init({
    SendPacket = sendPacket,
    SendLog = sendLog,
    Safety = Safety
})

-- ============================================================================
-- WEBSOCKET CONNECTION & COMMAND ROUTING
-- ============================================================================
local function connectWebSocket()
    print("[OE-External] Menghubungkan ke Hub: " .. WS_URL)
    local ok, ws = pcall(function()
        if WebSocket and typeof(WebSocket.connect) == "function" then
            return WebSocket.connect(WS_URL)
        elseif syn and syn.websocket and typeof(syn.websocket.connect) == "function" then
            return syn.websocket.connect(WS_URL)
        end
        error("Executor tidak mendukung WebSocket API")
    end)

    if not ok or not ws then
        warn("[OE-External] Gagal membuka WebSocket: " .. tostring(ws))
        task.wait(5)
        if _G.OE_ExternalRunning then return connectWebSocket() end
        return
    end

    CoreState.Socket = ws
    _G.OE_ExternalSocket = ws
    print("[OE-External] WebSocket terhubung sukses!")

    ws.OnMessage:Connect(function(msgRaw)
        local okParse, data = pcall(function() return HttpService:JSONDecode(msgRaw) end)
        if not okParse or not data then return end

        if data.type == "INIT_ACK" then
            CoreState.BotId = data.botId
            print("[OE-External] Terdaftar dengan Bot ID: " .. tostring(CoreState.BotId))
            sendLog(string.format("Akun aktif di %s (%s) & terhubung ke Web Hub!", activeGameModule.GameName, tostring(game.PlaceId)), "SUCCESS")

        elseif data.type == "EXECUTE_COMMAND" then
            local action = data.action
            local payload = data.payload or {}
            print("[OE-External] Menerima Perintah: " .. tostring(action))

            -- Universal Commands
            if action == "REJOIN_SERVER" then
                sendLog("Menerima perintah Rejoin Server...", "WARN")
                Safety.RejoinNow()

            elseif action == "TOGGLE_AUTO_REJOIN" then
                Safety.AutoRejoin = not Safety.AutoRejoin
                sendLog("Auto-Rejoin saat kick: " .. (Safety.AutoRejoin and "AKTIF" or "NONAKTIF"), "INFO")

            else
                -- Forward to Active Game Module
                local handled = activeGameModule.HandleCommand(action, payload)
                if not handled then
                    sendLog("Perintah tidak dikenali oleh modul game: " .. tostring(action), "WARN")
                end
            end
        end
    end)

    ws.OnClose:Connect(function()
        warn("[OE-External] WebSocket terputus! Mencoba rekoneksi dalam 3 detik...")
        CoreState.Socket = nil
        task.wait(3)
        if _G.OE_ExternalRunning and not Safety.IsKicked then
            connectWebSocket()
        end
    end)
end

-- ============================================================================
-- TELEMETRY STREAM LOOP (1 Detik Sekali)
-- ============================================================================
task.spawn(function()
    while _G.OE_ExternalRunning do
        local sessionSeconds = math.floor(os.clock() - CoreState.SessionStartTime)
        local h = math.floor(sessionSeconds / 3600)
        local m = math.floor((sessionSeconds % 3600) / 60)
        local s = math.floor(sessionSeconds % 60)
        local sessionTimeFormatted = string.format("%02d:%02d:%02d", h, m, s)

        local gameTelem = activeGameModule.GetTelemetry() or {}
        local combinedPayload = {
            sessionTime = sessionTimeFormatted,
            sessionSeconds = sessionSeconds,
            isKicked = Safety.IsKicked,
            kickReason = Safety.KickReason,
            autoRejoin = Safety.AutoRejoin,
            gameId = activeGameModule.GameId,
            gameName = activeGameModule.GameName,
            currencyUnit = activeGameModule.CurrencyUnit,
            metricUnit = activeGameModule.MetricUnit
        }

        for k, v in pairs(gameTelem) do
            combinedPayload[k] = v
        end

        sendPacket("TELEMETRY", combinedPayload)
        task.wait(1.0)
    end
end)

connectWebSocket()
