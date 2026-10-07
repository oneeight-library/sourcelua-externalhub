--[[
    OneEight External Hub - Car Driving Indonesia (CDID) Game Module
    100% Exact Faithful Clone of Official OneEight Hub Truck Engine:
    - Settle Wait: Exactly 50 Seconds (DriveMinDuration = 50)
    - Anti-Stream Pause: GuiService.GameplayPausedNotificationEnabled = false
    - Preload Streaming: RequestStreamAroundAsync 3s before teleport
    - Exact DriveEngine with A-Chassis ReadOnly Fix, PromptDriveSeat & 3s confirm loop
    - 0.6s Network Ownership buffer before State 6 driving
    - Raycast asphalt detection with 120 studs limit and clean flat CFrame landing
    - SSOT Cash Delta payout detection (>= 15,000,000)
    - Smart Chaining with minStuds evaluation
    - Disguised reroll as GET_BEST_DESTINATION
    - Headless Web Dashboard WebSocket Control
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
local GuiService = game:GetService("GuiService")
local LocalPlayer = Players.LocalPlayer

local Context = nil
local activeCashLabel = nil

-- Anti Stream Pause (Bypass Gameplay Paused overlay dari Roblox)
pcall(function()
    GuiService.GameplayPausedNotificationEnabled = false
end)

pcall(function()
    local carData = ReplicatedStorage:FindFirstChild("CarData")
    if carData and not carData:FindFirstChild("TruckJob") then
        local dummy = Instance.new("Folder")
        dummy.Name = "TruckJob"
        dummy.Parent = carData
    end
end)

local function cleanRoute(name)
    if not name then return "Cargo" end
    local s = tostring(name):gsub("%b()", ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return (s ~= "" and s) or "Cargo"
end

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
    DriveMinDuration = 50, -- 100% Persis OneEight Settle Duration (50 Detik)
    FarmStartTime = 0,
    Safety = {
        PlayerDetectorEnabled = false,
        EmergencyAction = "Warn Only",
        IgnoreFriends = true,
        ServerLocked = false
    },
    Lighting = {
        Fullbright = false,
        NoFog = false
    }
}

-- ============================================================================
-- FORMATTERS & SSOT CASH (100% PERSIS ONEEIGHT HELPERS & UI)
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

local function bindCashHUD()
    task.spawn(function()
        local pGui = LocalPlayer:WaitForChild("PlayerGui", 15)
        if pGui then
            local main = pGui:WaitForChild("Main", 15)
            local container = main and main:WaitForChild("Container", 15)
            local hub = container and container:WaitForChild("Hub", 15)
            local cashFrame = hub and hub:WaitForChild("CashFrame", 15)
            local innerFrame = cashFrame and cashFrame:WaitForChild("Frame", 15)
            local targetLabel = innerFrame and innerFrame:WaitForChild("TextLabel", 15)

            if not targetLabel then
                for _, desc in ipairs(pGui:GetDescendants()) do
                    if desc:IsA("TextLabel") and desc.Name == "TextLabel" and desc.Parent and desc.Parent.Name == "Frame" and desc.Parent.Parent and desc.Parent.Parent.Name == "CashFrame" then
                        targetLabel = desc
                        break
                    end
                end
            end

            if targetLabel then
                activeCashLabel = targetLabel
                updateCash(targetLabel.Text)
                targetLabel:GetPropertyChangedSignal("Text"):Connect(function()
                    updateCash(targetLabel.Text)
                end)
                print("[OE-External CDID] Berhasil mengaitkan HUD saldo pemain (SSOT)!")
            end
        end
    end)
end

-- ============================================================================
-- DRIVE ENGINE (100% EXACT ONEEIGHT IMPLEMENTATION)
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
    local vehicles = Workspace:FindFirstChild("Vehicles")
    if not vehicles then return nil end
    for _, v in ipairs(vehicles:GetChildren()) do
        if v.Name:find(LocalPlayer.Name, 1, true) then
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

    task.delay(1.0, function()
        if hum and not hum.Sit and seat then
            pcall(function() seat:Sit(hum) end)
        end
    end)

    local timeout = os.clock()
    while not hum.Sit and (os.clock() - timeout < 3.0) do
        task.wait(0.1)
    end
    return hum.Sit
end

-- ============================================================================
-- TRUCK FARM HELPERS (100% EXACT ONEEIGHT METHODS)
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
        hrp.Anchored = false
        hrp.CFrame = CFrame.new(hqPos + Vector3.new(0, 3.5, 0))
        hrp.AssemblyLinearVelocity = Vector3.zero
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

-- ============================================================================
-- VEHICLE TELEPORT (100% PERSIS METODE ONEEIGHT TANPA JITTER/TOUCHINTEREST)
-- ============================================================================
local function teleportVehicleToDestination(car, targetPos, waitDuration)
    local waitTime = (waitDuration ~= nil) and waitDuration or (State.DriveMinDuration or 50)
    local primary = car and (car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart"))
    local seat = car and car:FindFirstChildWhichIsA("VehicleSeat", true)
    if not car or not primary then return false end

    DriveEngine.EnsureSeated(car)

    local startTime = os.clock()
    local streamRequested = false

    print(string.format("[CDID Truck] ⏳ Menunggu estimasi perjalanan %d detik (kendaraan diam murni, no movement)...", waitTime))

    while State.IsFarming and (os.clock() - startTime < waitTime) do
        local elapsed = os.clock() - startTime
        local remaining = math.max(0, math.ceil(waitTime - elapsed))
        State.Status = string.format("DRIVING (%ds)", remaining)

        -- 🌐 Preload Streaming Non-Blocking 3 Detik Sebelum Selesai (Persis OneEight)
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
    if workspace:FindFirstChild("Etc") then
        table.insert(ignoreList, workspace.Etc)
    end
    rayParams.FilterDescendantsInstances = ignoreList

    local rayOrigin = Vector3.new(targetPos.X, targetPos.Y + 40, targetPos.Z)
    local groundRay = workspace:Raycast(rayOrigin, Vector3.new(0, -120, 0), rayParams)
    local landY = (groundRay and groundRay.Position.Y + 2.0) or targetPos.Y

    local startCF = car:GetPivot()
    local dirToTarget = (targetPos - startCF.Position).Unit
    local flatDir = Vector3.new(dirToTarget.X, 0, dirToTarget.Z).Unit
    local stopPos = Vector3.new(targetPos.X, landY, targetPos.Z)
    local targetCF = CFrame.new(stopPos, stopPos + flatDir)

    -- Pastikan karakter tetap duduk saat teleportasi
    local hum = DriveEngine.GetValidHumanoid()
    if hum and not hum.Sit and seat then
        pcall(function() seat:Sit(hum) end)
    end

    -- Snapshot saldo tepat sebelum mendarat di dropoff kargo tujuan
    State.PreDeliveryCash = State.CurrentCash or 0

    -- Teleportasi instan seluruh model mobil + karakter langsung ke aspal jalanan tujuan
    car:PivotTo(targetCF)

    -- Netralkan gaya inersia pasca teleport
    for _, p in ipairs(car:GetDescendants()) do
        if p:IsA("BasePart") then
            p.AssemblyLinearVelocity = Vector3.zero
            p.AssemblyAngularVelocity = Vector3.zero
        end
    end

    -- Jeda settle pasca teleportasi (1.2s) murni fisik alami agar validasi server selesai
    task.wait(1.2)
    return true
end

-- ============================================================================
-- 6-STATE TRUCK AUTO FARM ENGINE (100% EXACT ONEEIGHT STATE-DRIVEN LOOP)
-- ============================================================================
local function runFarmLoop()
    while State.IsFarming and _G.OE_ExternalRunning do
        local loopOk, loopErr = pcall(function()
            -- ================================================================
            -- STATE 1: BERSIHKAN STATUS & KENDARAAN LAMA (Despawn Sync)
            -- ================================================================
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

            -- Tutup sisa popup dialog CDID
            pcall(function()
                local pgui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
                if pgui then
                    local jobGui = pgui:FindFirstChild("Job")
                    if jobGui and jobGui:FindFirstChild("Components") then
                        jobGui.Components.Visible = false
                    end
                end
            end)

            if not State.IsFarming then return end

            -- ================================================================
            -- STATE 2: DAFTAR JOB TRUCK & TELEPORT KE DEPO HQ
            -- ================================================================
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

            -- ================================================================
            -- STATE 3: AMBIL MUATAN & SINKRONISASI WAYPOINT RUTE
            -- ================================================================
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

            -- Evaluasi Jarak Minimum (Disguised Reroll)
            local minStuds = tonumber(State.MinDistance) or 100000
            local routeDist = (State.CurrentTargetPos - State.TRUCK_STARTER_POS).Magnitude

            if routeDist < minStuds then
                State.Status = "GET_BEST_DESTINATION"
                if Context and Context.SendLog then
                    Context.SendLog(string.format("Menganalisis rute terbaik: %s...", cleanRoute(State.CurrentTargetName)), "INFO")
                end
                pcall(function() ReplicatedStorage.NetworkContainer.RemoteEvents.Job:FireServer("Unemployee") end)
                State.CurrentTargetPos = nil
                State.CurrentTargetName = nil
                task.wait(0.5)
                return
            end

            -- ================================================================
            -- STATE 4: MUNCULKAN ARMADA TRUK (Spawner Sync)
            -- ================================================================
            State.Status = "SPAWN_TRUCK"
            State.CurrentRoute = cleanRoute(State.CurrentTargetName)
            if Context and Context.SendLog then
                Context.SendLog(string.format("Rute Cocok: %s! Memunculkan armada...", cleanRoute(State.CurrentTargetName)), "SUCCESS")
            end

            tf = Helpers.findTruckFolder()
            local spawnerObj = tf and (tf:FindFirstChild("Spawner") or tf:FindFirstChild("spawner"))
            autoFirePrompt(spawnerObj, 0.3)

            local car = nil
            local carWait = 0
            while not car and carWait < 8.0 and State.IsFarming do
                car = DriveEngine.GetPlayerCar()
                if car then break end
                task.wait(0.4)
                carWait = carWait + 0.4
                if carWait == 3.2 and spawnerObj then
                    autoFirePrompt(spawnerObj, 0.25)
                end
            end

            if not car or not State.IsFarming then
                if Context and Context.SendLog then
                    Context.SendLog("Truk gagal terdeteksi di Workspace, mereset...", "WARN")
                end
                pcall(function() ReplicatedStorage.NetworkContainer.RemoteEvents.Job:FireServer("Unemployee") end)
                State.CurrentTargetPos = nil
                State.CurrentTargetName = nil
                task.wait(0.8)
                return
            end

            -- ================================================================
            -- STATE 5: DUDUK DI KURSI DRIVER & BUFFER NETWORK OWNERSHIP (Persis OneEight)
            -- ================================================================
            State.Status = "BOARDING"
            task.wait(0.3)

            local seated = false
            local seatWait = 0
            while not seated and seatWait < 5.0 and State.IsFarming do
                seated = DriveEngine.EnsureSeated(car)
                if seated then break end
                task.wait(0.5)
                seatWait = seatWait + 0.5
            end

            if not State.IsFarming then return end

            if not seated then
                if Context and Context.SendLog then
                    Context.SendLog("Gagal menaiki kursi supir. Mereset armada...", "WARN")
                end
                pcall(function() ReplicatedStorage.NetworkContainer.RemoteEvents.Job:FireServer("Unemployee") end)
                State.CurrentTargetPos = nil
                State.CurrentTargetName = nil
                task.wait(0.8)
                return
            end

            -- Buffer validasi network ownership server (100% Persis OneEight)
            task.wait(0.6)

            -- ================================================================
            -- STATE 6: PERJALANAN, GAJI, & SMART CHAINING
            -- ================================================================
            while State.IsFarming and State.CurrentTargetPos do
                local driveOk = teleportVehicleToDestination(car, State.CurrentTargetPos, State.DriveMinDuration)
                if not driveOk or not State.IsFarming then break end

                -- Tunggu konfirmasi penerimaan gaji kargo dari server (Single Source of Truth)
                State.Status = "WAIT_PAYOUT"
                local cashBefore = State.PreDeliveryCash or State.CurrentCash or 0
                local waitPayoutStart = os.clock()
                local cargoGained = 0

                while (os.clock() - waitPayoutStart < 7.0) and State.IsFarming do
                    local curCash = State.CurrentCash or 0
                    if curCash > cashBefore then
                        local delta = curCash - cashBefore
                        if delta >= 15000000 then
                            cargoGained = delta
                            break
                        end
                    end
                    task.wait(0.1)
                end

                if not State.IsFarming then break end

                if cargoGained > 0 then
                    State.TripCount = State.TripCount + 1
                    State.LastSalary = cargoGained
                    State.TotalEarnings = (State.TotalEarnings or 0) + cargoGained
                    if State.StartCash and State.StartCash > 0 and (State.CurrentCash - State.StartCash) > State.TotalEarnings then
                        State.TotalEarnings = State.CurrentCash - State.StartCash
                    end
                    if Context and Context.SendLog then
                        Context.SendLog(string.format("Pengiriman #%d Berhasil! Gaji masuk (+%s)", State.TripCount, formatMoney(cargoGained)), "SUCCESS")
                    end
                else
                    if Context and Context.SendLog then
                        Context.SendLog(string.format("Pengiriman belum terhitung server (gaji tidak terdeteksi). Tidak menambah trip.", State.TripCount), "WARN")
                    end
                end

                task.wait(0.3)

                -- SMART CHAINING: Cek apakah ada rute sambungan baru dari server
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

                    print(string.format("[CDID Smart Chain] Rute Sambungan: %s | Jarak: %.2f studs | Min: %.2f", tostring(State.CurrentTargetName), chainDist, minStuds))

                    if chainDist >= minStuds then
                        canChain = true
                        State.CurrentRoute = cleanRoute(State.CurrentTargetName)
                        if Context and Context.SendLog then
                            Context.SendLog(string.format("[Smart Chain] Rute Sambungan: %s (%.0f km)!", cleanRoute(State.CurrentTargetName), chainDist / 1000), "SUCCESS")
                        end
                        DriveEngine.EnsureSeated(car)
                        task.wait(0.5)
                    end
                end

                if not canChain then
                    State.CurrentTargetPos = nil
                    State.CurrentTargetName = nil
                    break
                end
            end

            -- SIKLUS SELESAI -> RESIGN & KEMBALI KE HQ
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
-- INTERFACE CONTRACT IMPLEMENTATION FOR EXTERNAL WEB CONTROL
-- ============================================================================
function CDIDModule.Init(coreContext)
    Context = coreContext

    bindCashHUD()
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1.5)
        bindCashHUD()
    end)

    -- Dynamic Waypoint listener dari server (Persis OneEight ui.lua)
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

    print("[OE-External CDID] Modul OneEight State-Driven Truck Engine (50s) siap 100%!")
end


-- ============================================================================
-- EXTRA UTILITIES & SAFETY (PORTED FROM ONEEIGHT SOURCELUA-DEV)
-- ============================================================================
local SafetyEngine = {
    PlayerDetectorEnabled = false,
    EmergencyAction = "Warn Only",
    IgnoreFriends = true,
    ServerLocked = false,
    Connection = nil
}

function SafetyEngine.IsFriend(player)
    if not SafetyEngine.IgnoreFriends then return false end
    local ok, friend = pcall(function()
        return LocalPlayer:IsFriendsWith(player.UserId)
    end)
    return ok and friend
end

function SafetyEngine.TriggerPanic(intruder)
    if not SafetyEngine.PlayerDetectorEnabled then return end
    local msg = string.format("🚨 [Safety Alert] Stranger detected: %s (@%s)", intruder.DisplayName, intruder.Name)
    if Context and Context.SendLog then
        Context.SendLog(msg, "WARN")
    end

    if SafetyEngine.EmergencyAction == "Kick" then
        task.wait(0.2)
        LocalPlayer:Kick(string.format("[OneEight Safety Alert]\nStranger joined: %s (@%s)\nAuto-disconnected for account safety.", intruder.DisplayName, intruder.Name))
    elseif SafetyEngine.EmergencyAction == "Server Hop" then
        task.wait(0.2)
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end
end

function SafetyEngine.InitDetector()
    if SafetyEngine.Connection then return end
    SafetyEngine.Connection = Players.PlayerAdded:Connect(function(player)
        if player == LocalPlayer then return end
        task.wait(0.5)
        if not SafetyEngine.IsFriend(player) then
            SafetyEngine.TriggerPanic(player)
        end
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and not SafetyEngine.IsFriend(player) then
            task.spawn(function()
                SafetyEngine.TriggerPanic(player)
            end)
            break
        end
    end
end

function SafetyEngine.SetServerLock(enable)
    SafetyEngine.ServerLocked = enable
    pcall(function()
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        local panel = pGui and pGui:FindFirstChild("PrivateServerPanel")
        local serverFrame = panel and panel:FindFirstChild("MainFrame") and panel.MainFrame:FindFirstChild("Main") and panel.MainFrame.Main:FindFirstChild("Server")
        if serverFrame then
            for _, c in ipairs(serverFrame:GetChildren()) do
                local title = c:FindFirstChild("OptionTitle")
                if title and title.Text == "Server Lock" then
                    local toggleBtn = c:FindFirstChild("ToggleButton")
                    local conns = (typeof(getconnections) == "function" and getconnections(toggleBtn.MouseButton1Down)) or {}
                    if #conns > 0 and conns[1].Function then
                        pcall(conns[1].Function)
                    end
                end
            end
        end

        local net = ReplicatedStorage:FindFirstChild("NetworkContainer")
        local remotes = net and net:FindFirstChild("RemoteEvents")
        local ps = remotes and (remotes:FindFirstChild("Private Server") or remotes:FindFirstChild("PrivateServer"))
        if ps then
            ps:FireServer("serverlock", {})
        end
    end)

    if Context and Context.SendLog then
        Context.SendLog(string.format("Private Server Lock: %s", enable and "TERKUNCI 🔒" or "TERBUKA 🔓"), "INFO")
    end
end

local DealershipEngine = {}
function DealershipEngine.Open(dealerName)
    dealerName = dealerName or "Dealer Utama"
    pcall(function()
        local etc = Workspace:FindFirstChild("Etc") or Instance.new("Folder", Workspace)
        etc.Name = "Etc"
        local dealershipFolder = etc:FindFirstChild("Dealership") or Instance.new("Folder", etc)
        dealershipFolder.Name = "Dealership"

        local oldFake = dealershipFolder:FindFirstChild("Fake_" .. dealerName)
        if oldFake then oldFake:Destroy() end

        local fakeModel = Instance.new("Model")
        fakeModel.Name = dealerName
        fakeModel.Parent = dealershipFolder

        local fakePrompt = Instance.new("ProximityPrompt")
        fakePrompt.Parent = fakeModel

        if typeof(firesignal) == "function" then
            firesignal(game:GetService("ProximityPromptService").PromptTriggered, fakePrompt)
            if Context and Context.SendLog then
                Context.SendLog(string.format("UI Dealership '%s' berhasil dibuka via remote prompt.", dealerName), "SUCCESS")
            end
        elseif Context and Context.SendLog then
            Context.SendLog("Executor tidak mendukung firesignal untuk membuka UI dealer.", "WARN")
        end

        task.delay(1.5, function()
            if fakeModel then fakeModel:Destroy() end
        end)
    end)
end

function DealershipEngine.Teleport(dealerName)
    pcall(function()
        local dealershipFolder = Workspace:FindFirstChild("Etc") and Workspace.Etc:FindFirstChild("Dealership")
        local targetModel = dealershipFolder and dealershipFolder:FindFirstChild(dealerName)
        local char = LocalPlayer.Character
        local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
        if hrp and targetModel then
            hrp.CFrame = targetModel:GetPivot() * CFrame.new(0, 0, 3.5)
            if Context and Context.SendLog then
                Context.SendLog(string.format("Teleport ke showroom '%s' berhasil.", dealerName), "SUCCESS")
            end
        elseif hrp then
            hrp.CFrame = CFrame.new(Vector3.new(34800, 140, -54200))
            if Context and Context.SendLog then
                Context.SendLog("Teleport ke area dealer utama.", "INFO")
            end
        end
    end)
end

local TeleportEngine = {
    Locations = {
        bengkel = Vector3.new(35210, 135, -53980),
        dealer = Vector3.new(34800, 140, -54200),
        rest_area = Vector3.new(33650, 138, -52100)
    }
}

function TeleportEngine.Quick(targetKey)
    local pos = TeleportEngine.Locations[targetKey]
    if not pos then return end
    pcall(function()
        local char = LocalPlayer.Character
        local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
        if hrp then
            hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
            if Context and Context.SendLog then
                Context.SendLog(string.format("Teleportasi karakter ke %s berhasil.", targetKey:upper()), "SUCCESS")
            end
        end
    end)
end

local LightingEngine = {
    Fullbright = false,
    NoFog = false,
    Connection = nil,
    SavedFog = Lighting.FogEnd
}

function LightingEngine.SetFullbright(enable)
    LightingEngine.Fullbright = enable
    if enable then
        if not LightingEngine.Connection then
            LightingEngine.Connection = RunService.RenderStepped:Connect(function()
                if LightingEngine.Fullbright then
                    Lighting.Brightness = 2
                    Lighting.ClockTime = 14
                    Lighting.Ambient = Color3.fromRGB(255, 255, 255)
                    Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
                end
            end)
        end
    else
        if LightingEngine.Connection then
            LightingEngine.Connection:Disconnect()
            LightingEngine.Connection = nil
        end
        Lighting.Brightness = 1
        Lighting.ClockTime = 14
        Lighting.Ambient = Color3.fromRGB(128, 128, 128)
        Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
    end
    if Context and Context.SendLog then
        Context.SendLog(string.format("Fullbright Mode: %s", enable and "AKTIF ☀️" or "NONAKTIF 🌑"), "INFO")
    end
end

function LightingEngine.SetNoFog(enable)
    LightingEngine.NoFog = enable
    if enable then
        Lighting.FogEnd = 1000000
    else
        Lighting.FogEnd = LightingEngine.SavedFog or 1000
    end
    if Context and Context.SendLog then
        Context.SendLog(string.format("No Fog Mode: %s", enable and "AKTIF (Jernih)" or "NONAKTIF"), "INFO")
    end
end


function CDIDModule.HandleCommand(action, payload)
    if action == "START_FARM" then
        if not State.IsFarming then
            State.IsFarming = true
            State.FarmStartTime = os.clock()
            if Context and Context.SendLog then
                Context.SendLog("Memulai OneEight State-Driven CDID Truck Farm (50s)", "SUCCESS")
            end
            task.spawn(runFarmLoop)
        end
        return true

    elseif action == "STOP_FARM" then
        State.IsFarming = false
        State.FarmStartTime = 0
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
                Context.SendLog("Konfigurasi Best Destination diperbarui: " .. tostring(State.MinDistance), "INFO")
            end
        end
        return true

    elseif action == "SET_SAFETY_CONFIG" then
        if payload then
            if payload.playerDetector ~= nil then
                State.Safety.PlayerDetectorEnabled = payload.playerDetector
                SafetyEngine.PlayerDetectorEnabled = payload.playerDetector
                if payload.playerDetector then SafetyEngine.InitDetector() end
            end
            if payload.emergencyAction ~= nil then
                State.Safety.EmergencyAction = payload.emergencyAction
                SafetyEngine.EmergencyAction = payload.emergencyAction
            end
            if payload.ignoreFriends ~= nil then
                State.Safety.IgnoreFriends = payload.ignoreFriends
                SafetyEngine.IgnoreFriends = payload.ignoreFriends
            end
            if Context and Context.SendLog then
                Context.SendLog(string.format("Safety Config diperbarui: Detector=%s, Action=%s, IgnoreFriends=%s",
                    tostring(State.Safety.PlayerDetectorEnabled), State.Safety.EmergencyAction, tostring(State.Safety.IgnoreFriends)), "INFO")
            end
        end
        return true

    elseif action == "TOGGLE_SERVER_LOCK" then
        local enable = (payload and payload.locked ~= nil) and payload.locked or not State.Safety.ServerLocked
        State.Safety.ServerLocked = enable
        SafetyEngine.SetServerLock(enable)
        return true

    elseif action == "OPEN_DEALERSHIP" then
        local dealer = (payload and payload.dealer) or "Dealer Utama"
        DealershipEngine.Open(dealer)
        return true

    elseif action == "TELEPORT_DEALERSHIP" then
        local dealer = (payload and payload.dealer) or "Dealer Utama"
        DealershipEngine.Teleport(dealer)
        return true

    elseif action == "QUICK_TELEPORT" then
        local target = payload and payload.target
        if target then TeleportEngine.Quick(target) end
        return true

    elseif action == "TOGGLE_FULLBRIGHT" then
        local enable = (payload and payload.enabled ~= nil) and payload.enabled or not State.Lighting.Fullbright
        State.Lighting.Fullbright = enable
        LightingEngine.SetFullbright(enable)
        return true

    elseif action == "TOGGLE_NO_FOG" then
        local enable = (payload and payload.enabled ~= nil) and payload.enabled or not State.Lighting.NoFog
        State.Lighting.NoFog = enable
        LightingEngine.SetNoFog(enable)
        return true
    end

    return false
end

function CDIDModule.GetTelemetry()
    local elapsedSec = (State.IsFarming and State.FarmStartTime and State.FarmStartTime > 0) and math.floor(os.clock() - State.FarmStartTime) or 0
    return {
        status = State.Status,
        currentRoute = State.CurrentRoute,
        tripCount = State.TripCount,
        totalEarnings = State.TotalEarnings,
        currentCash = State.CurrentCash,
        startCash = State.StartCash,
        isFarming = State.IsFarming,
        lowRender = State.LowRender,
        minDistance = State.MinDistance,
        farmDuration = elapsedSec,
        safety = State.Safety,
        lighting = State.Lighting
    }
end

function CDIDModule.Cleanup()
    State.IsFarming = false
    State.Status = "STOPPED"
end

return CDIDModule
