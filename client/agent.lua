--[[
    OneEight External Hub - Full State-Driven CDID Truck Client Agent
    Version: 2.0.0 (Event & State-Driven with Real-Time WebSocket Telemetry)
--]]

if _G.OE_ExternalAgentLoaded then
    warn("[OE-External] Agent sudah aktif, merefresh koneksi...")
    if _G.OE_ExternalSocket and typeof(_G.OE_ExternalSocket.Close) == "function" then
        pcall(function() _G.OE_ExternalSocket:Close() end)
    end
    _G.OE_ExternalRunning = false
    task.wait(0.5)
end
_G.OE_ExternalAgentLoaded = true
_G.OE_ExternalRunning = true

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

-- ============================================================================
-- ANTI-AFK ENGINE NATIVE
-- ============================================================================
pcall(function()
    LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.zero)
        end)
    end)
end)

-- ============================================================================
-- STATE MANAGEMENT
-- ============================================================================
local WS_BASE_URL = "wss://externalhub.oneeight-project18.workers.dev/ws"
local WS_URL = WS_BASE_URL .. "?role=bot&name=" .. HttpService:UrlEncode(LocalPlayer.Name) .. "&job=Truck&placeId=" .. tostring(game.PlaceId)

local State = {
    Socket = nil,
    BotId = nil,
    IsFarming = false,
    TripCount = 0,
    TotalEarnings = 0,
    CurrentCash = 0,
    PreDeliveryCash = 0,
    Status = "CONNECTED",
    CurrentRoute = "IDLE",
    CurrentTargetPos = nil,
    CurrentTargetName = nil,
    LowRender = false,
    MinDistance = 100000,
    TRUCK_STARTER_POS = Vector3.new(34938.023, 135.125, -54577.938)
}

-- ============================================================================
-- WEBSOCKET HELPERS
-- ============================================================================
local function sendPacket(packetType, payload)
    if not State.Socket then return end
    pcall(function()
        local data = HttpService:JSONEncode({
            type = packetType,
            payload = payload
        })
        State.Socket:Send(data)
    end)
end

local function sendLog(msg, level)
    if not State.Socket then return end
    pcall(function()
        local data = HttpService:JSONEncode({
            type = "LOG",
            message = tostring(msg),
            level = level or "INFO"
        })
        State.Socket:Send(data)
    end)
end

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

local function getCDIDCash()
    local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:FindFirstChild("PlayerGui")
    if pGui then
        for _, desc in ipairs(pGui:GetDescendants()) do
            if desc:IsA("TextLabel") and desc.Visible and not desc:GetFullName():find("cdid_hub") and not desc:GetFullName():find("Wind") then
                local txt = desc.Text:gsub("<[^<>]->", "")
                if txt:find("Rp") and not txt:find("%+") and not txt:find("%-") and not txt:find("/km") then
                    local val = parseCashString(txt)
                    if val > 1000 then
                        return val
                    end
                end
            end
        end
    end
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    local cash = leaderstats and (leaderstats:FindFirstChild("Cash") or leaderstats:FindFirstChild("Uang"))
    if cash then
        return tonumber(cash.Value) or 0
    end
    return 0
end

-- Telemetry Heartbeat (1 detik sekali)
task.spawn(function()
    while _G.OE_ExternalRunning do
        pcall(function()
            local c = getCDIDCash()
            if c > 0 then
                if not State.StartCash or State.StartCash == 0 then
                    State.StartCash = c
                end
                State.CurrentCash = c
                if State.StartCash and State.CurrentCash >= State.StartCash then
                    State.TotalEarnings = State.CurrentCash - State.StartCash
                end
            end
        end)

        local sessionSeconds = 0
        local sessionTimeFormatted = "00:00:00"
        if State.SessionStartTime then
            sessionSeconds = math.floor(os.clock() - State.SessionStartTime)
            local h = math.floor(sessionSeconds / 3600)
            local m = math.floor((sessionSeconds % 3600) / 60)
            local s = math.floor(sessionSeconds % 60)
            sessionTimeFormatted = string.format("%02d:%02d:%02d", h, m, s)
        end

        if State.Socket then
            sendPacket("TELEMETRY", {
                status = State.Status,
                currentRoute = State.CurrentRoute,
                tripCount = State.TripCount,
                totalEarnings = State.TotalEarnings,
                currentCash = State.CurrentCash,
                startCash = State.StartCash,
                sessionTime = sessionTimeFormatted,
                sessionSeconds = sessionSeconds,
                isFarming = State.IsFarming,
                lowRender = State.LowRender,
                minDistance = State.MinDistance
            })
        end
        task.wait(1.0)
    end
end)

-- ============================================================================
-- CDID TRUCK CORE HELPERS
-- ============================================================================
local Helpers = {}

function Helpers.GetValidHumanoid()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health > 0 then
        return hum, char:FindFirstChild("HumanoidRootPart")
    end
    return nil, nil
end

function Helpers.findTruckFolder()
    local etcJob = workspace:FindFirstChild("Etc") and workspace.Etc:FindFirstChild("Job")
    if etcJob then
        return etcJob:FindFirstChild("Truck")
    end
    return nil
end

function Helpers.PreloadStream(targetPos)
    if not targetPos then return end
    task.spawn(function()
        pcall(function()
            if typeof(LocalPlayer.RequestStreamAroundAsync) == "function" then
                LocalPlayer:RequestStreamAroundAsync(targetPos)
            elseif typeof(workspace.RequestStreamAroundAsync) == "function" then
                workspace:RequestStreamAroundAsync(targetPos)
            end
        end)
    end)
end

function Helpers.TeleportPlayerToHQ()
    local _, hrp = Helpers.GetValidHumanoid()
    if not hrp then return false end
    local hqPos = State.TRUCK_STARTER_POS
    local dist = (hrp.Position - hqPos).Magnitude

    if dist > 200 then
        Helpers.PreloadStream(hqPos)
        hrp.Anchored = true
        hrp.CFrame = CFrame.new(hqPos.X, hqPos.Y + 3.0, hqPos.Z)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        task.wait(0.4)
        hrp.Anchored = false
    else
        hrp.Anchored = false
        hrp.CFrame = CFrame.new(hqPos.X, hqPos.Y + 3.0, hqPos.Z)
        hrp.AssemblyLinearVelocity = Vector3.zero
    end
    return true
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
    local _, hrp = Helpers.GetValidHumanoid()
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
-- DRIVE ENGINE (CAR & SEAT RESOLVER)
-- ============================================================================
local DriveEngine = {}

function DriveEngine.GetPlayerCar()
    local vehicles = workspace:FindFirstChild("Vehicles")
    if not vehicles then return nil end

    local carName = LocalPlayer.Name .. "sCar"
    local directCar = vehicles:FindFirstChild(carName)
    if directCar then return directCar end

    for _, car in ipairs(vehicles:GetChildren()) do
        if car:IsA("Model") and car.Name:find(LocalPlayer.Name) then
            return car
        end
    end
    return nil
end

function DriveEngine.EnsureSeated(car)
    local hum = Helpers.GetValidHumanoid()
    if not hum then return false end

    local driveSeat = car and car:FindFirstChildWhichIsA("VehicleSeat", true)
    if not driveSeat then return false end

    if hum.Sit and hum.SeatPart == driveSeat then
        return true
    end

    local drivePrompt = driveSeat:FindFirstChildWhichIsA("ProximityPrompt", true)
        or car:FindFirstChild("DrivePrompt", true)
        or car:FindFirstChild("Prompt", true)

    if drivePrompt and fireproximityprompt then
        pcall(function()
            drivePrompt.RequiresLineOfSight = false
            drivePrompt.MaxActivationDistance = 50
            fireproximityprompt(drivePrompt)
        end)
    end

    task.delay(0.6, function()
        pcall(function()
            if not hum.Sit or hum.SeatPart ~= driveSeat then
                driveSeat:Sit(hum)
            end
        end)
    end)

    local waitTime = 0
    while waitTime < 2.0 do
        if hum.Sit and hum.SeatPart == driveSeat then return true end
        task.wait(0.1)
        waitTime = waitTime + 0.1
    end

    pcall(function() driveSeat:Sit(hum) end)
    return (hum.Sit and hum.SeatPart == driveSeat)
end

-- ============================================================================
-- STATE-DRIVEN FARM CYCLE (6 SERVER-SYNCHRONIZED STATES)
-- ============================================================================
local function runFarmLoop()
    while State.IsFarming and _G.OE_ExternalRunning do
        local loopOk, loopErr = pcall(function()
            -- ----------------------------------------------------------------
            -- STATE 1: DESPAWN SYNC (Bersihkan Mobil Lama)
            -- ----------------------------------------------------------------
            local oldCar = DriveEngine.GetPlayerCar()
            if oldCar then
                State.Status = "STATE 1: DESPAWN_SYNC"
                sendLog("[State 1] Membersihkan kendaraan lama...", "INFO")
                pcall(function()
                    ReplicatedStorage.NetworkContainer.RemoteEvents.Job:FireServer("Unemployee")
                end)
                local despawnWait = 0
                while DriveEngine.GetPlayerCar() and despawnWait < 3.0 and State.IsFarming do
                    task.wait(0.2)
                    despawnWait = despawnWait + 0.2
                end
            end

            -- Tutup sisa popup game yang menghalangi
            pcall(function()
                local pgui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
                if pgui then
                    if pgui:FindFirstChild("Job") and pgui.Job:FindFirstChild("Components") then
                        pgui.Job.Components.Visible = false
                    end
                    if pgui:FindFirstChild("Race") and pgui.Race:FindFirstChild("Container") then
                        pgui.Race.Container.Visible = false
                    end
                end
            end)

            if not State.IsFarming then return end

            -- ----------------------------------------------------------------
            -- STATE 2: RE-JOB & HQ TELEPORT SYNC
            -- ----------------------------------------------------------------
            State.Status = "STATE 2: REJOB_HQ"
            sendLog("[State 2] Mendaftar supir truk & menuju HQ Depo...", "INFO")
            pcall(function()
                ReplicatedStorage.NetworkContainer.RemoteEvents.Job:FireServer("Truck")
            end)
            task.wait(0.3)
            Helpers.TeleportPlayerToHQ()

            local _, hrp = Helpers.GetValidHumanoid()
            local hqPos = State.TRUCK_STARTER_POS
            local hqWait = 0
            while hqWait < 3.5 and State.IsFarming do
                local curDist = hrp and (hrp.Position - hqPos).Magnitude or 999
                local tf = Helpers.findTruckFolder()
                if curDist < 50 and tf and tf:FindFirstChild("Starter") then
                    break
                end
                task.wait(0.2)
                hqWait = hqWait + 0.2
            end

            if not State.IsFarming then return end

            -- ----------------------------------------------------------------
            -- STATE 3: CARGO ROUTE SYNC (>100k studs filter)
            -- ----------------------------------------------------------------
            State.Status = "STATE 3: CARGO_SYNC"
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
                sendLog("[State 3] Waypoint kargo belum muncul. Re-roll job...", "WARN")
                pcall(function() ReplicatedStorage.NetworkContainer.RemoteEvents.Job:FireServer("Unemployee") end)
                task.wait(0.5)
                return
            end

            local minStuds = State.MinDistance or 100000
            local routeDist = (State.CurrentTargetPos - hqPos).Magnitude
            State.CurrentRoute = string.format("%s (%.0f km)", State.CurrentTargetName or "Dropoff", routeDist / 1000)

            if routeDist < minStuds then
                sendLog(string.format("[State 3] Rute ditolak: %s (%.0f < %.0f studs). Reroll cepat...", State.CurrentTargetName, routeDist, minStuds), "WARN")
                pcall(function() ReplicatedStorage.NetworkContainer.RemoteEvents.Job:FireServer("Unemployee") end)
                State.CurrentTargetPos = nil
                State.CurrentTargetName = nil
                task.wait(0.5)
                return
            end

            sendLog(string.format("[State 3] Rute diterima: %s (%.1f km)!", State.CurrentTargetName, routeDist / 1000), "SUCCESS")

            -- ----------------------------------------------------------------
            -- STATE 4: VEHICLE SPAWNER SYNC
            -- ----------------------------------------------------------------
            State.Status = "STATE 4: SPAWNING"
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

            if not State.IsFarming then return end

            if not car then
                sendLog("[State 4] Armada tidak terdeteksi di workspace. Resetting...", "WARN")
                pcall(function() ReplicatedStorage.NetworkContainer.RemoteEvents.Job:FireServer("Unemployee") end)
                task.wait(0.8)
                return
            end

            -- ----------------------------------------------------------------
            -- STATE 5: DUAL SEAT CONFIRMATION
            -- ----------------------------------------------------------------
            State.Status = "STATE 5: SEAT_CONFIRM"
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
                sendLog("[State 5] Gagal menduduki armada truk. Resetting...", "WARN")
                pcall(function() ReplicatedStorage.NetworkContainer.RemoteEvents.Job:FireServer("Unemployee") end)
                task.wait(0.8)
                return
            end

            task.wait(0.6) -- Network ownership settling buffer

            -- ----------------------------------------------------------------
            -- STATE 6: ESTIMASI 50s, PAYOUT VERIFICATION & SMART CHAINING
            -- ----------------------------------------------------------------
            while State.IsFarming do
                local targetPos = State.CurrentTargetPos
                local routeTitle = State.CurrentTargetName or "Tujuan"
                sendLog("[State 6] Memulai estimasi perjalanan ke " .. routeTitle .. " (50 detik)...", "INFO")

                local waitTime = 50
                local startTime = os.clock()
                local streamSent = false

                while State.IsFarming and (os.clock() - startTime < waitTime) do
                    local elapsed = os.clock() - startTime
                    local rem = math.max(0, math.ceil(waitTime - elapsed))
                    State.Status = string.format("ESTIMASI %ds", rem)

                    -- Preload streaming di detik ke-3 terakhir
                    if rem <= 3 and not streamSent then
                        streamSent = true
                        Helpers.PreloadStream(targetPos)
                    end
                    task.wait(1.0)
                end

                if not State.IsFarming then break end

                -- Teleportasi langsung ke aspal tujuan
                State.Status = "TELEPORTING"
                sendLog("[State 6] Waktu estimasi selesai! Teleport ke " .. routeTitle, "INFO")

                local rayParams = RaycastParams.new()
                rayParams.FilterType = Enum.RaycastFilterType.Exclude
                rayParams.FilterDescendantsInstances = { car, LocalPlayer.Character, workspace:FindFirstChild("Etc") }

                local rayOrigin = Vector3.new(targetPos.X, targetPos.Y + 40, targetPos.Z)
                local groundRay = workspace:Raycast(rayOrigin, Vector3.new(0, -120, 0), rayParams)
                local landY = (groundRay and groundRay.Position.Y + 2.0) or targetPos.Y

                local startCF = car:GetPivot()
                local dir = (targetPos - startCF.Position).Unit
                local flatDir = Vector3.new(dir.X, 0, dir.Z).Unit
                local stopPos = Vector3.new(targetPos.X, landY, targetPos.Z)
                local targetCF = CFrame.new(stopPos, stopPos + flatDir)

                -- Snapshot saldo tepat sebelum mendarat
                State.PreDeliveryCash = State.CurrentCash or 0
                car:PivotTo(targetCF)

                for _, p in ipairs(car:GetDescendants()) do
                    if p:IsA("BasePart") then
                        p.AssemblyLinearVelocity = Vector3.zero
                        p.AssemblyAngularVelocity = Vector3.zero
                    end
                end
                task.wait(1.2) -- Jeda settle fisik

                -- Tunggu verifikasi payout dari server CDID
                State.Status = "WAIT_PAYOUT"
                local cashBefore = State.PreDeliveryCash or State.CurrentCash or getCDIDCash()
                local waitPayoutStart = os.clock()
                local gained = 0

                while (os.clock() - waitPayoutStart < 7.0) and State.IsFarming do
                    local curCash = getCDIDCash()
                    if curCash > cashBefore then
                        local delta = curCash - cashBefore
                        if delta >= 15000000 then
                            gained = delta
                            State.CurrentCash = curCash
                            if State.StartCash and State.CurrentCash >= State.StartCash then
                                State.TotalEarnings = State.CurrentCash - State.StartCash
                            end
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
                        if State.StartCash and State.CurrentCash >= State.StartCash then
                            State.TotalEarnings = State.CurrentCash - State.StartCash
                        end
                    end
                end

                if not State.IsFarming then break end

                State.TripCount = State.TripCount + 1
                if gained > 0 then
                    State.TotalEarnings = State.TotalEarnings + gained
                    sendLog(string.format("[State 6] Pengiriman #%d Berhasil! Gaji masuk (+%s)", State.TripCount, formatMoney(gained)), "SUCCESS")
                else
                    sendLog(string.format("[State 6] Pengiriman #%d Selesai!", State.TripCount), "SUCCESS")
                end

                -- SMART CHAINING: Cek apakah ada rute sambungan langsung dari dropoff
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
                    local _, pHrp = Helpers.GetValidHumanoid()
                    local curPos = pHrp and pHrp.Position or (lastDeliveredPos or Vector3.zero)
                    local chainDist = (State.CurrentTargetPos - curPos).Magnitude

                    if chainDist >= minStuds then
                        canChain = true
                        State.CurrentRoute = string.format("%s (%.0f km)", State.CurrentTargetName or "Chain", chainDist / 1000)
                        sendLog(string.format("[Smart Chain] Rute Sambungan: %s (%.1f km)!", State.CurrentTargetName, chainDist / 1000), "SUCCESS")
                        DriveEngine.EnsureSeated(car)
                        task.wait(0.5)
                    else
                        sendLog(string.format("[Smart Chain] Rute sambungan %s terlalu dekat (%.0f < %.0f), kembali ke HQ...", State.CurrentTargetName, chainDist, minStuds), "INFO")
                    end
                end

                if not canChain then
                    break -- Keluar untuk Rejob ke HQ
                end
            end

            -- Siklus selesai, bersihkan job
            State.Status = "CYCLE_COMPLETE"
            pcall(function() ReplicatedStorage.NetworkContainer.RemoteEvents.Job:FireServer("Unemployee") end)
            State.CurrentTargetPos = nil
            State.CurrentTargetName = nil
            task.wait(0.5)
            Helpers.TeleportPlayerToHQ()
        end)

        if not loopOk then
            warn("[CDID Truck Exception Caught]:", tostring(loopErr))
            sendLog("[Recovering] Terjadi exception: " .. tostring(loopErr) .. ". Memulihkan dalam 1.5s...", "WARN")
            State.Status = "RECOVERING"
            task.wait(1.5)
        end
    end

    State.Status = "STOPPED"
    State.CurrentRoute = "IDLE"
    sendLog("AutoFarm dihentikan.", "INFO")
end

-- ============================================================================
-- WEBSOCKET CONNECTION & COMMAND DISPATCHER
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

    State.Socket = ws
    _G.OE_ExternalSocket = ws
    print("[OE-External] WebSocket terhubung sukses!")

    ws.OnMessage:Connect(function(msgRaw)
        local okParse, data = pcall(function() return HttpService:JSONDecode(msgRaw) end)
        if not okParse or not data then return end

        if data.type == "INIT_ACK" then
            State.BotId = data.botId
            print("[OE-External] Terdaftar dengan Bot ID: " .. tostring(State.BotId))
            sendLog("Bot aktif di CDID Jawa Timur & terhubung ke Web Hub!", "SUCCESS")

        elseif data.type == "EXECUTE_COMMAND" then
            local action = data.action
            local payload = data.payload or {}
            print("[OE-External] Menerima Perintah: " .. tostring(action))

            if action == "START_FARM" then
                if not State.IsFarming then
                    State.IsFarming = true
                    State.SessionStartTime = os.clock()
                    local initialC = getCDIDCash()
                    if initialC > 0 then State.StartCash = initialC; State.CurrentCash = initialC; end
                    sendLog("Memulai State-Driven CDID Truck Farm", "SUCCESS")
                    task.spawn(runFarmLoop)
                end

            elseif action == "STOP_FARM" then
                State.IsFarming = false
                State.Status = "STOPPED"
                sendLog("Menghentikan AutoFarm...", "WARN")

            elseif action == "TOGGLE_LOW_RENDER" then
                State.LowRender = not State.LowRender
                pcall(function()
                    if typeof(RunService.Set3dRenderingEnabled) == "function" then
                        RunService:Set3dRenderingEnabled(not State.LowRender)
                    end
                end)
                sendLog("Low GPU Mode: " .. (State.LowRender and "AKTIF (3D Off)" or "NONAKTIF (3D On)"), "INFO")

            elseif action == "TELEPORT_HQ" then
                sendLog("Teleportasi manual ke Depo HQ...", "INFO")
                Helpers.TeleportPlayerToHQ()

            elseif action == "SET_MIN_DISTANCE" then
                if payload and payload.minDistance then
                    State.MinDistance = tonumber(payload.minDistance) or 100000
                    sendLog("Batas jarak minimum diubah ke: " .. State.MinDistance .. " studs", "INFO")
                end
            end
        end
    end)

    ws.OnClose:Connect(function()
        warn("[OE-External] WebSocket terputus! Mencoba rekoneksi dalam 3 detik...")
        State.Socket = nil
        State.Status = "DISCONNECTED"
        task.wait(3)
        if _G.OE_ExternalRunning then
            connectWebSocket()
        end
    end)
end

connectWebSocket()
