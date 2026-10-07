--[[
    OneEight External Hub - Master Modular Client Agent
    Version: 3.1.0 (CDID Main Menu & Server Gateway Support)
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
-- MODULAR INTERNAL VFS
-- ============================================================================
local Modules = {}
local LoadedModules = {}

local function requireModule(name)
    if LoadedModules[name] ~= nil then
        return LoadedModules[name]
    end
    if Modules[name] then
        local res = Modules[name]()
        LoadedModules[name] = res
        return res
    end
    error("[OE-External] Modul tidak ditemukan: " .. tostring(name))
end


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

-- ============================================================================
-- MODULAR CDID SUB-MODULES
-- ============================================================================
Modules["games/cdid/features/lighting"] = function()
--[[
    CDID Feature: Lighting & Performance Visuals
--]]
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local LightingFeature = {
    Fullbright = false,
    NoFog = false,
    Connection = nil,
    SavedFog = 1000
}

pcall(function()
    LightingFeature.SavedFog = Lighting.FogEnd
end)

function LightingFeature.SetFullbright(enable, Context)
    LightingFeature.Fullbright = enable
    if enable then
        if not LightingFeature.Connection then
            LightingFeature.Connection = RunService.RenderStepped:Connect(function()
                if LightingFeature.Fullbright then
                    Lighting.Brightness = 2
                    Lighting.ClockTime = 14
                    Lighting.Ambient = Color3.fromRGB(255, 255, 255)
                    Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
                end
            end)
        end
    else
        if LightingFeature.Connection then
            LightingFeature.Connection:Disconnect()
            LightingFeature.Connection = nil
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

function LightingFeature.SetNoFog(enable, Context)
    LightingFeature.NoFog = enable
    if enable then
        pcall(function() Lighting.FogEnd = 1000000 end)
    else
        pcall(function() Lighting.FogEnd = LightingFeature.SavedFog or 1000 end)
    end
    if Context and Context.SendLog then
        Context.SendLog(string.format("No Fog Mode: %s", enable and "AKTIF (Jernih)" or "NONAKTIF"), "INFO")
    end
end

return LightingFeature

end

Modules["games/cdid/features/safety"] = function()
--[[
    CDID Feature: Safety, Anti-Staff & Server Lock
--]]
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SafetyFeature = {
    PlayerDetectorEnabled = false,
    EmergencyAction = "Warn Only",
    IgnoreFriends = true,
    ServerLocked = false,
    Connection = nil
}

function SafetyFeature.IsFriend(player)
    if not SafetyFeature.IgnoreFriends then return false end
    local ok, friend = pcall(function()
        return LocalPlayer:IsFriendsWith(player.UserId)
    end)
    return ok and friend
end

function SafetyFeature.TriggerPanic(intruder, Context)
    if not SafetyFeature.PlayerDetectorEnabled then return end
    local msg = string.format("🚨 [Safety Alert] Stranger detected: %s (@%s)", intruder.DisplayName, intruder.Name)
    if Context and Context.SendLog then
        Context.SendLog(msg, "WARN")
    end

    if SafetyFeature.EmergencyAction == "Kick" then
        task.wait(0.2)
        LocalPlayer:Kick(string.format("[OneEight Safety Alert]\nStranger joined: %s (@%s)\nAuto-disconnected for account safety.", intruder.DisplayName, intruder.Name))
    elseif SafetyFeature.EmergencyAction == "Server Hop" then
        task.wait(0.2)
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end
end

function SafetyFeature.InitDetector(Context)
    if SafetyFeature.Connection then return end
    SafetyFeature.Connection = Players.PlayerAdded:Connect(function(player)
        if player == LocalPlayer then return end
        task.wait(0.5)
        if not SafetyFeature.IsFriend(player) then
            SafetyFeature.TriggerPanic(player, Context)
        end
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and not SafetyFeature.IsFriend(player) then
            task.spawn(function()
                SafetyFeature.TriggerPanic(player, Context)
            end)
            break
        end
    end
end

function SafetyFeature.SetServerLock(enable, Context)
    SafetyFeature.ServerLocked = enable
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

return SafetyFeature

end

Modules["games/cdid/features/dealership"] = function()
--[[
    CDID Feature: Dealership Controller, Catalog Extractor & Remote Buy
    100% Dynamic - Auto-discovers dealers from in-game UI & CarData memory
--]]
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DealershipFeature = {}

-- Urutan dan nama dealer CDID resmi
local KNOWN_DEALER_ORDER = {
    "77", "Bandung", "Otnas", "Premium", "Toyota", "Honda",
    "Hyundai", "Mitsubishi", "MercedesBenz", "Suzuki", "Daihatsu",
    "KIA", "Nissan", "Mazda", "Lexus", "Wuling", "Audi", "VW",
    "DIR", "Chery", "Jaecoo", "Geely", "Shehua", "SLM", "Komersial"
}

function DealershipFeature.GetRealDealerList()
    local list = {}
    local seen = {}

    -- 1. Baca dari UI Dealerlist in-game CDID (PlayerGui.Dealership.Container.Dealership.Dealerlist)
    pcall(function()
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        local dGui = pGui and pGui:FindFirstChild("Dealership")
        local dList = dGui and dGui:FindFirstChild("Container") and dGui.Container:FindFirstChild("Dealership") and dGui.Container.Dealership:FindFirstChild("Dealerlist")
        if dList then
            for _, child in ipairs(dList:GetChildren()) do
                if (child:IsA("ScrollingFrame") or child:IsA("Frame") or child:IsA("Folder")) and not seen[child.Name] then
                    seen[child.Name] = true
                    table.insert(list, child.Name)
                end
            end
        end
    end)

    -- 2. Baca dari CarData di ReplicatedStorage (ekstraksi dinamis dari data mobil game)
    pcall(function()
        local carData = ReplicatedStorage:FindFirstChild("CarData")
        if carData then
            for _, car in ipairs(carData:GetChildren()) do
                local d = car:FindFirstChild("Dealership") and car.Dealership.Value
                if d and d ~= "" and not seen[d] then
                    seen[d] = true
                    table.insert(list, d)
                end
            end
        end
    end)

    -- 3. Fallback jika data belum termuat
    if #list == 0 then
        for _, name in ipairs(KNOWN_DEALER_ORDER) do
            table.insert(list, name)
        end
    else
        -- Urutkan berdasarkan urutan CDID populer
        local orderMap = {}
        for idx, name in ipairs(KNOWN_DEALER_ORDER) do
            orderMap[name:lower()] = idx
        end
        table.sort(list, function(a, b)
            local oa = orderMap[a:lower()] or 999
            local ob = orderMap[b:lower()] or 999
            if oa ~= ob then return oa < ob end
            return a:lower() < b:lower()
        end)
    end

    return list
end

function DealershipFeature.GetCars(dealerTarget)
    local list = {}
    local carData = ReplicatedStorage:FindFirstChild("CarData")
    if not carData then return list end

    local cleanTarget = (dealerTarget or ""):lower():gsub("%s+", ""):gsub("[^%w]", "")
    -- Aliases normalizer
    if cleanTarget == "dealer77" or cleanTarget == "utama" then cleanTarget = "77" end
    if cleanTarget == "bekasbandung" then cleanTarget = "bandung" end
    if cleanTarget == "komersil" then cleanTarget = "komersial" end

    for _, car in ipairs(carData:GetChildren()) do
        local dealerVal = car:FindFirstChild("Dealership")
        local unobtainable = car:FindFirstChild("Unobtainable")
        if dealerVal and not unobtainable then
            local rawDealer = dealerVal.Value
            local cleanDealer = rawDealer:lower():gsub("%s+", ""):gsub("[^%w]", "")
            if cleanDealer == "komersil" then cleanDealer = "komersial" end

            local isMatch = false
            if cleanTarget == "" or cleanTarget == "all" or cleanTarget == "semuadealer" then
                isMatch = true
            elseif cleanDealer == cleanTarget then
                isMatch = true
            elseif cleanDealer:find(cleanTarget, 1, true) or cleanTarget:find(cleanDealer, 1, true) then
                isMatch = true
            end

            if isMatch then
                local img = car:FindFirstChild("CarImage") and car.CarImage.Value or ""
                local assetId = img:match("id=(%d+)") or img:match("(%d+)$") or ""
                table.insert(list, {
                    id = car.Name,
                    name = car:FindFirstChild("CarName") and car.CarName.Value or car.Name,
                    cost = car:FindFirstChild("Cost") and car.Cost.Value or 0,
                    dealer = rawDealer,
                    assetId = assetId,
                    topSpeed = car:FindFirstChild("TopSpeed") and car.TopSpeed.Value or 0,
                    hp = car:FindFirstChild("Horsepower") and car.Horsepower.Value or 0,
                    year = car:FindFirstChild("CarYear") and car.CarYear.Value or ""
                })
            end
        end
    end

    table.sort(list, function(a, b) return a.cost < b.cost end)
    return list
end

function DealershipFeature.Buy(carId, dealer, color, Context)
    local color3 = (color and Color3.fromRGB(color.r or 255, color.g or 255, color.b or 255)) or Color3.fromRGB(255, 255, 255)
    local result = "Failed"
    pcall(function()
        local net = require(ReplicatedStorage.Shared.Network)
        result = net:InvokeServer("Dealership", "Buy", carId, color3, dealer or "")
    end)
    if Context and Context.SendLog then
        Context.SendLog(string.format("Hasil beli mobil '%s' (%s): %s", carId, dealer, tostring(result)), result == "Success" and "SUCCESS" or "WARN")
    end
    return result
end

function DealershipFeature.Open(dealerName, Context)
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
                Context.SendLog(string.format("UI Dealership '%s' berhasil dibuka.", dealerName), "SUCCESS")
            end
        elseif Context and Context.SendLog then
            Context.SendLog("Executor tidak mendukung firesignal.", "WARN")
        end

        task.delay(1.5, function()
            if fakeModel then fakeModel:Destroy() end
        end)
    end)
end

function DealershipFeature.Teleport(dealerName, Context)
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
        end
    end)
end

return DealershipFeature

end

Modules["games/cdid/features/teleport"] = function()
--[[
    CDID Feature: Map Quick Teleports
--]]
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local TeleportFeature = {
    Locations = {
        bengkel = Vector3.new(35210, 135, -53980),
        dealer = Vector3.new(34800, 140, -54200),
        rest_area = Vector3.new(33650, 138, -52100)
    }
}

function TeleportFeature.Quick(targetKey, Context)
    local pos = TeleportFeature.Locations[targetKey]
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

return TeleportFeature

end

Modules["games/cdid/jobs/truck"] = function()
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

local TruckJob = {}
TruckJob.GameId = "cdid"
TruckJob.GameName = "Car Driving Indonesia"
TruckJob.CurrencyUnit = "Rp"
TruckJob.MetricUnit = "Trips"

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
function TruckJob.Init(coreContext)
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

function TruckJob.Start()
    if State.IsFarming then return end
    State.IsFarming = true
    State.FarmStartTime = os.clock()
    if Context and Context.SendLog then
        Context.SendLog("Auto Farm Truk Kargo CDID dimulai!", "SUCCESS")
    end
    task.spawn(runFarmLoop)
end

function TruckJob.Stop()
    State.IsFarming = false
    State.Status = "STOPPED"
    State.CurrentRoute = "IDLE"
    pcall(function()
        ReplicatedStorage.NetworkContainer.RemoteEvents.Job:FireServer("Unemployee")
    end)
    if Context and Context.SendLog then
        Context.SendLog("Auto Farm Truk dihentikan.", "WARN")
    end
end

function TruckJob.TeleportHQ()
    Helpers.TeleportPlayerToHQ()
end

function TruckJob.GetState()
    return State
end

return TruckJob

end

Modules["games/cdid"] = function()
--[[
    OneEight External Hub - CDID Modular Main Coordinator
    100% Clean, Modular, and Extensible Architecture
--]]
local CDIDModule = {}
CDIDModule.GameId = "cdid"
CDIDModule.GameName = "CDID Jawa Timur"
CDIDModule.CurrencyUnit = "Rp"
CDIDModule.MetricUnit = "Trips"

local Context = nil
local RunService = game:GetService("RunService")

-- Sub-modul Modular
local LightingFeature = nil
local SafetyFeature = nil
local DealershipFeature = nil
local TeleportFeature = nil
local TruckJob = nil

function CDIDModule.Init(coreContext)
    Context = coreContext

    -- Load sub-modul
    LightingFeature = requireModule("games/cdid/features/lighting")
    SafetyFeature = requireModule("games/cdid/features/safety")
    DealershipFeature = requireModule("games/cdid/features/dealership")
    TeleportFeature = requireModule("games/cdid/features/teleport")
    TruckJob = requireModule("games/cdid/jobs/truck")

    TruckJob.Init(coreContext)
    print("[OE-External CDID] Modular Coordinator Berhasil Diinisialisasi!")
end

function CDIDModule.HandleCommand(action, payload)
    if action == "START_FARM" then
        TruckJob.Start()
        return true

    elseif action == "STOP_FARM" then
        TruckJob.Stop()
        return true

    elseif action == "TELEPORT_HQ" then
        TruckJob.TeleportHQ()
        if Context and Context.SendLog then
            Context.SendLog("Teleport manual ke Depot HQ Truk.", "INFO")
        end
        return true

    elseif action == "TOGGLE_LOW_RENDER" then
        local st = TruckJob.GetState()
        st.LowRender = not st.LowRender
        pcall(function()
            if typeof(RunService.Set3dRenderingEnabled) == "function" then
                RunService:Set3dRenderingEnabled(not st.LowRender)
            end
        end)
        if Context and Context.SendLog then
            Context.SendLog("Low GPU Mode: " .. (st.LowRender and "AKTIF (3D Off)" or "NONAKTIF (3D On)"), "INFO")
        end
        return true

    elseif action == "SET_MIN_DISTANCE" then
        if payload and payload.minDistance and TruckJob then
            local st = TruckJob.GetState()
            st.MinDistance = tonumber(payload.minDistance) or 100000
            if Context and Context.SendLog then
                Context.SendLog("Konfigurasi Best Destination: " .. tostring(st.MinDistance), "INFO")
            end
        end
        return true

    elseif action == "SET_SAFETY_CONFIG" then
        if payload and SafetyFeature then
            if payload.playerDetector ~= nil then
                SafetyFeature.PlayerDetectorEnabled = payload.playerDetector
                if payload.playerDetector then SafetyFeature.InitDetector(Context) end
            end
            if payload.emergencyAction ~= nil then
                SafetyFeature.EmergencyAction = payload.emergencyAction
            end
            if payload.ignoreFriends ~= nil then
                SafetyFeature.IgnoreFriends = payload.ignoreFriends
            end
            if Context and Context.SendLog then
                Context.SendLog(string.format("Safety Config: Detector=%s, Action=%s, IgnoreFriends=%s",
                    tostring(SafetyFeature.PlayerDetectorEnabled), SafetyFeature.EmergencyAction, tostring(SafetyFeature.IgnoreFriends)), "INFO")
            end
        end
        return true

    elseif action == "TOGGLE_SERVER_LOCK" then
        if SafetyFeature then
            local enable = (payload and payload.locked ~= nil) and payload.locked or not SafetyFeature.ServerLocked
            SafetyFeature.SetServerLock(enable, Context)
        end
        return true

    elseif action == "TOGGLE_FULLBRIGHT" then
        if LightingFeature then
            local enable = (payload and payload.enabled ~= nil) and payload.enabled or not LightingFeature.Fullbright
            LightingFeature.SetFullbright(enable, Context)
        end
        return true

    elseif action == "TOGGLE_NO_FOG" then
        if LightingFeature then
            local enable = (payload and payload.enabled ~= nil) and payload.enabled or not LightingFeature.NoFog
            LightingFeature.SetNoFog(enable, Context)
        end
        return true

    elseif action == "OPEN_DEALERSHIP" then
        if DealershipFeature then
            local dealer = (payload and payload.dealer) or "Dealer Utama"
            DealershipFeature.Open(dealer, Context)
        end
        return true

    elseif action == "TELEPORT_DEALERSHIP" then
        if DealershipFeature then
            local dealer = (payload and payload.dealer) or "Dealer Utama"
            DealershipFeature.Teleport(dealer, Context)
        end
        return true

    elseif action == "QUICK_TELEPORT" then
        if TeleportFeature and payload and payload.target then
            TeleportFeature.Quick(payload.target, Context)
        end
        return true

    elseif action == "FETCH_DEALER_CARS" then
        if DealershipFeature and Context and Context.SendPacket then
            local dealer = payload and payload.dealer or "all"
            local cars = DealershipFeature.GetCars(dealer)
            Context.SendPacket("DEALER_CARS_DATA", {
                dealer = dealer,
                cars = cars
            })
        end
        return true

    elseif action == "BUY_CAR" then
        if DealershipFeature and payload and payload.carId then
            DealershipFeature.Buy(payload.carId, payload.dealer, payload.color, Context)
        end
        return true
    end

    return false
end

function CDIDModule.GetTelemetry()
    local st = TruckJob and TruckJob.GetState() or {}
    local elapsedSec = (st.IsFarming and st.FarmStartTime and st.FarmStartTime > 0) and math.floor(os.clock() - st.FarmStartTime) or 0
    return {
        status = st.Status or "CONNECTED",
        currentRoute = st.CurrentRoute or "IDLE",
        tripCount = st.TripCount or 0,
        totalEarnings = st.TotalEarnings or 0,
        currentCash = st.CurrentCash or 0,
        startCash = st.StartCash or 0,
        isFarming = st.IsFarming or false,
        lowRender = st.LowRender or false,
        minDistance = st.MinDistance or 100000,
        farmDuration = elapsedSec,
        dealerList = DealershipFeature and DealershipFeature.GetRealDealerList() or {},
        safety = SafetyFeature and {
            PlayerDetectorEnabled = SafetyFeature.PlayerDetectorEnabled,
            EmergencyAction = SafetyFeature.EmergencyAction,
            IgnoreFriends = SafetyFeature.IgnoreFriends,
            ServerLocked = SafetyFeature.ServerLocked
        } or {},
        lighting = LightingFeature and {
            Fullbright = LightingFeature.Fullbright,
            NoFog = LightingFeature.NoFog
        } or {}
    }
end

function CDIDModule.Cleanup()
    if TruckJob then TruckJob.Stop() end
end

return CDIDModule

end

Modules["games/cdid_menu"] = function()
--[[
    OneEight External Hub - CDID Main Menu & Server Gateway Module
    100% Exact Port of OneEight Hub Server Manager:
    - Realtime multi-source private server code detection (UI, GC Replica, NetworkEvent)
    - Free private server code generation (Network:FireServer("PrivateServer", "Create"))
    - Native map selection & controller synchronization (UIAnimation.SelectedMap)
    - Full bidirectional server code sync with Web Dashboard
    - Auto-Enter Jawa Timur with auto-code fallback & queue_on_teleport
--]]

local CDIDMenu = {}
CDIDMenu.GameId = "cdid_menu"
CDIDMenu.GameName = "CDID Main Menu"
CDIDMenu.CurrencyUnit = "Rp"
CDIDMenu.MetricUnit = "Maps"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

local Context = nil
local State = {
    Status = "LOBBY_READY",
    AutoJoinJatim = false,
    CurrentServerCode = "",
    SelectedMap = "JawaTimur",
    AutoJoinTimer = 5,
    CodeSource = "None"
}

local CDID_MAPS = {
    { Key = "JawaTimur",   Name = "Jawa Timur",   PlaceId = 110369730911937, Desc = "Pusat Truck Cargo Auto Farm", Icon = "truck", Primary = true },
    { Key = "Jakarta",     Name = "Jakarta",      PlaceId = 14005966837,     Desc = "Kurir BCA & Cafe Kanji Jawa",  Icon = "building" },
    { Key = "Bandung",     Name = "Bandung",      PlaceId = 79488788685813,  Desc = "Kota Kembang",                Icon = "compass" },
    { Key = "JawaBarat",   Name = "Jawa Barat",   PlaceId = 9233343468,      Desc = "Tol & Pegunungan",            Icon = "compass" },
    { Key = "JawaTengah",  Name = "Jawa Tengah",  PlaceId = 9508940498,      Desc = "Semarang & Solo",             Icon = "compass" },
    { Key = "Bali",        Name = "Bali",         PlaceId = 118108582994420, Desc = "Pulau Dewata",               Icon = "palm-tree" },
    { Key = "Seasonal",    Name = "Seasonal",     PlaceId = 132986577553100, Desc = "Event Khusus",               Icon = "sparkles" }
}

-- Native CDID Network Helper
local CDID_Network = nil
local CDID_UIAnimation = nil

local function getCDIDNetwork()
    if CDID_Network then return CDID_Network end
    pcall(function()
        local shared = ReplicatedStorage:FindFirstChild("Shared")
        if shared and shared:FindFirstChild("Network") then
            CDID_Network = require(shared.Network)
        end
    end)
    return CDID_Network
end

local function getRealUIAnimation()
    local success, result = pcall(function()
        for _, v in ipairs(getgc(true)) do
            if type(v) == "table" and rawget(v, "SelectedMap") and rawget(v, "WindowModule") then
                return v
            end
        end
    end)
    return success and result or nil
end

-- ============================================================================
-- VALIDASI & PENERAPAN KODE SERVER (ONE-EIGHT HUB ALGORITHM)
-- ============================================================================
local function isValidServerCode(text)
    if not text or type(text) ~= "string" then return false end
    local clean = text:gsub("%s+", "")
    if clean == "" or clean == "ServerLabel" or clean == "nil" or clean == "InsertHere" then return false end
    local lower = clean:lower()
    if lower:find("ms") or lower:find("fps") or lower:find("singapore")
        or lower:find("unitedstates") or lower:find("indonesia") or lower:find(",") then
        return false
    end
    return (clean:len() >= 4 and clean:len() <= 35)
end

local function applyServerCode(code, source)
    if not isValidServerCode(code) then return false end
    local clean = tostring(code):gsub("%s+", "")
    if clean == State.CurrentServerCode then return false end

    State.CurrentServerCode = clean
    State.CodeSource = source or "Unknown"
    print(string.format("[OE-External CDID] 🔑 Kode Server Terdeteksi [%s]: %s", State.CodeSource, State.CurrentServerCode))

    if Context and Context.SendLog then
        Context.SendLog(string.format("Kode Server CDID terdeteksi (%s): %s", State.CodeSource, State.CurrentServerCode), "SUCCESS")
    end

    -- Update ke GUI CDID jika ada
    pcall(function()
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        local ps = pGui and pGui:FindFirstChild("Hub") and pGui.Hub.Container.Window:FindFirstChild("PrivateServer")
        if ps and ps:FindFirstChild("ServerLabel") then
            ps.ServerLabel.Text = State.CurrentServerCode
        end
    end)

    return true
end

-- ============================================================================
-- MULTI-SOURCE SCANNER (EXACT ONE-EIGHT HUB METHOD)
-- ============================================================================
local function scanAllSources()
    -- Sumber 1: Real UIAnimation dari GC
    local realUI = getRealUIAnimation()
    if realUI and realUI.WindowModule then
        local ps = realUI.WindowModule.PrivateServer
        if ps and ps.ServerLabel and isValidServerCode(ps.ServerLabel.Text) then
            return applyServerCode(ps.ServerLabel.Text, "UIAnimation")
        end
    end

    -- Sumber 2: Recursive scan di PlayerGui untuk ServerLabel
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    if pGui then
        for _, inst in ipairs(pGui:GetDescendants()) do
            if (inst:IsA("TextLabel") or inst:IsA("TextBox")) and inst.Name == "ServerLabel" then
                if isValidServerCode(inst.Text) then
                    return applyServerCode(inst.Text, "PlayerGui.ServerLabel")
                end
            end
        end
    end

    -- Sumber 3: ReplicaService Player Data State (GC scan)
    local replicaCode = nil
    pcall(function()
        for _, v in ipairs(getgc(true)) do
            if type(v) == "table" and type(rawget(v, "Class")) == "string" and rawget(v, "Class"):find("^Player_") and rawget(v, "Data") then
                local data = rawget(v, "Data")
                if data and data.PrivateServer and data.PrivateServer.Code and isValidServerCode(data.PrivateServer.Code) then
                    replicaCode = data.PrivateServer.Code
                    break
                end
            end
        end
    end)
    if replicaCode then
        return applyServerCode(replicaCode, "GCReplicaScan")
    end

    return false
end

-- Request kode baru dari server game CDID
local function requestServerCode()
    print("[OE-External CDID] 🔄 Meminta pembuatan kode server private baru...")
    if Context and Context.SendLog then
        Context.SendLog("Meminta server CDID untuk generate kode private baru...", "INFO")
    end

    local net = getCDIDNetwork()
    if net and net.FireServer then
        pcall(function()
            net:FireServer("PrivateServer", "Create")
        end)
    end

    -- Polling agresif selama 5 detik
    for _ = 1, 15 do
        task.wait(0.3)
        if scanAllSources() then
            return State.CurrentServerCode
        end
    end
    return State.CurrentServerCode
end

-- ============================================================================
-- MAP SELECTION & JOIN DISPATCHER
-- ============================================================================
local function selectMapNative(mapKey)
    State.SelectedMap = mapKey

    -- 1. Sync ke real UIAnimation di GC
    local realUI = getRealUIAnimation()
    if realUI then
        pcall(function() realUI.SelectedMap = mapKey end)
    end

    -- 2. Sync ke Controller UIAnimation CDID
    pcall(function()
        local controller = ReplicatedStorage:FindFirstChild("Controller")
        if controller and controller:FindFirstChild("UIAnimation") then
            local uiMod = require(controller.UIAnimation)
            if uiMod then uiMod.SelectedMap = mapKey end
        end
    end)

    -- 3. Trigger tombol map di PlayerGui.Hub
    pcall(function()
        local mapWin = LocalPlayer.PlayerGui.Hub.Container.Window:FindFirstChild("MapSelection")
        local targetMapFrame = mapWin and mapWin:FindFirstChild(mapKey)
        local btn = targetMapFrame and targetMapFrame:FindFirstChild("TextButton")
        if btn then
            local conns = getconnections and getconnections(btn.MouseButton1Down) or {}
            for _, c in ipairs(conns) do
                if c.Function then pcall(c.Function) end
            end
            if typeof(firesignal) == "function" then
                pcall(firesignal, btn.MouseButton1Down)
            end
        end
    end)
end

local function joinMap(mapKey, serverCode)
    mapKey = mapKey or State.SelectedMap or "JawaTimur"
    State.Status = "JOINING_" .. string.upper(mapKey)

    -- Setup queue_on_teleport agar loader kembali berjalan di server tujuan
    local queue_teleport = (syn and syn.queue_on_teleport) or queue_on_teleport or (fluxus and fluxus.queue_on_teleport)
    if queue_teleport then
        pcall(function()
            queue_teleport([[
                task.wait(4)
                loadstring(game:HttpGet("https://externalhub.oneeight-project18.workers.dev/loader"))()
            ]])
        end)
    end

    -- 1. Pastikan Kode Server Terisi
    local codeToUse = serverCode
    if not codeToUse or codeToUse == "" then
        codeToUse = State.CurrentServerCode
    end

    if not codeToUse or codeToUse == "" then
        scanAllSources()
        codeToUse = State.CurrentServerCode
    end

    -- Jika masih belum ada, minta server buatkan kode otomatis sekarang juga
    if not codeToUse or codeToUse == "" then
        codeToUse = requestServerCode()
    end

    print(string.format("[OE-External CDID] 🚀 Melakukan Join ke %s dengan Kode: '%s'...", mapKey, tostring(codeToUse)))
    if Context and Context.SendLog then
        Context.SendLog(string.format("Menghubungkan ke %s (Kode: %s)...", mapKey, tostring(codeToUse)), "WARN")
    end

    selectMapNative(mapKey)
    task.wait(0.3)

    -- Tutup websocket lama secara bersih agar tidak ada duplikat di backend
    if _G.OE_ExternalSocket then
        pcall(function() _G.OE_ExternalSocket:Close() end)
    end

    -- Pemicu 1: Remote CDID Network (Utama - Persis OneEight Hub)
    local net = getCDIDNetwork()
    if net and net.FireServer and codeToUse and codeToUse ~= "" then
        pcall(function()
            net:FireServer("PrivateServer", "Join", tostring(codeToUse), mapKey)
        end)
    end

    -- Pemicu 2: Klik tombol Join bawaan UI CDID
    pcall(function()
        local ps = LocalPlayer.PlayerGui.Hub.Container.Window.PrivateServer
        if ps and ps:FindFirstChild("ServerLabel") and codeToUse and #codeToUse > 0 then
            ps.ServerLabel.Text = tostring(codeToUse)
        end

        local joinBtn = ps and ps:FindFirstChild("JoinButton") and ps.JoinButton:FindFirstChild("TextButton")
        if joinBtn then
            local conns = getconnections and getconnections(joinBtn.MouseButton1Down) or {}
            for _, c in ipairs(conns) do
                if c.Function then pcall(c.Function) end
            end
            if typeof(firesignal) == "function" then
                pcall(firesignal, joinBtn.MouseButton1Down)
            end
        end
    end)

    -- Pemicu 3: TeleportService Fallback (Jika server code gagal atau join public)
    task.wait(2.0)
    local targetPlaceId = nil
    for _, m in ipairs(CDID_MAPS) do
        if m.Key == mapKey then
            targetPlaceId = m.PlaceId
            break
        end
    end
    if targetPlaceId then
        pcall(function()
            TeleportService:Teleport(targetPlaceId, LocalPlayer)
        end)
    end
end

-- ============================================================================
-- MODUL INIT & BACKGROUND LISTENERS
-- ============================================================================
function CDIDMenu.Init(coreContext)
    Context = coreContext
    print("[OE-External CDID] Modul Main Menu / Lobby CDID aktif!")

    -- Initial scan kode server
    scanAllSources()

    -- Hook Remote Network jika sudah siap
    task.spawn(function()
        local net = getCDIDNetwork()
        if net and net.OnClientEvent then
            pcall(function()
                net.OnClientEvent("PrivateServer", function(action, arg1)
                    if isValidServerCode(arg1) then
                        applyServerCode(arg1, "NetworkEvent")
                    elseif isValidServerCode(action) then
                        applyServerCode(action, "NetworkEvent")
                    end
                end)
            end)
        end
    end)

    -- Realtime Hook pada PlayerGui ServerLabel
    task.spawn(function()
        local pGui = LocalPlayer:WaitForChild("PlayerGui", 10)
        if not pGui then return end

        local function checkInst(inst)
            if (inst:IsA("TextLabel") or inst:IsA("TextBox")) and inst.Name == "ServerLabel" then
                if isValidServerCode(inst.Text) then
                    applyServerCode(inst.Text, "ServerLabelHook")
                end
                inst:GetPropertyChangedSignal("Text"):Connect(function()
                    if isValidServerCode(inst.Text) then
                        applyServerCode(inst.Text, "ServerLabelChange")
                    end
                end)
            end
        end

        for _, inst in ipairs(pGui:GetDescendants()) do checkInst(inst) end
        pGui.DescendantAdded:Connect(checkInst)
    end)

    -- Background scanner berkala tiap 3 detik
    task.spawn(function()
        while _G.OE_ExternalRunning do
            task.wait(3)
            if State.CurrentServerCode == "" then
                scanAllSources()
            end
        end
    end)

    -- Auto-Enter Jawa Timur dinonaktifkan (User memegang kendali penuh)
    -- Bot tetap standby di lobi dan memindai kode server secara damai
    task.spawn(function()
        task.wait(1.5)
        if State.CurrentServerCode == "" then
            scanAllSources()
        end
    end)
end

function CDIDMenu.HandleCommand(action, payload)
    if action == "JOIN_MAP" then
        local mapKey = payload and payload.mapKey or "JawaTimur"
        local code = payload and payload.code or State.CurrentServerCode
        joinMap(mapKey, code)
        return true

    elseif action == "GENERATE_SERVER_CODE" then
        task.spawn(function()
            requestServerCode()
        end)
        return true

    elseif action == "SET_SERVER_CODE" then
        if payload and payload.code then
            applyServerCode(payload.code, "WebInput")
        end
        return true

    elseif action == "TOGGLE_AUTO_JOIN_JATIM" then
        State.AutoJoinJatim = not State.AutoJoinJatim
        if Context and Context.SendLog then
            Context.SendLog("Auto-Enter Jawa Timur: " .. (State.AutoJoinJatim and "AKTIF" or "NONAKTIF"), "INFO")
        end
        return true
    end
    return false
end

function CDIDMenu.GetTelemetry()
    return {
        status = State.Status,
        isLobby = true,
        autoJoinJatim = State.AutoJoinJatim,
        selectedMap = State.SelectedMap,
        serverCode = State.CurrentServerCode,
        codeSource = State.CodeSource,
        currentRoute = "Di Lobi (Kode: " .. (State.CurrentServerCode ~= "" and State.CurrentServerCode or "Belum Ada") .. ")",
        tripCount = 0,
        totalEarnings = 0,
        currentCash = 0
    }
end

function CDIDMenu.Cleanup()
    State.AutoJoinJatim = false
end

return CDIDMenu

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

local LoadedModules = {}
-- ============================================================================
-- LOAD CORE SAFETY & KICK DETECTOR
-- ============================================================================
local Safety = requireModule("core/safety")
Safety.StartAntiAFK()

-- ============================================================================
-- DETECT ACTIVE GAME MODULE & PLACE ID
-- ============================================================================
local placeId = game.PlaceId
local activeGameModule = nil

-- Cek apakah player berada di CDID Main Menu / Lobby (PlaceId: 6911148748)
local pGui = LocalPlayer:FindFirstChild("PlayerGui")
local isLobby = (placeId == 6911148748) or (pGui and pGui:FindFirstChild("Hub") ~= nil)

if isLobby then
    activeGameModule = requireModule("games/cdid_menu")
elseif placeId == 110369730911937 then
    -- Jawa Timur (Tempat Khusus Truck Driver)
    activeGameModule = requireModule("games/cdid")
else
    -- Map CDID lainnya atau fallback
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

-- Initialize Active Game Module
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

            if action == "REJOIN_SERVER" then
                sendLog("Menerima perintah Rejoin Server...", "WARN")
                Safety.RejoinNow()

            elseif action == "TOGGLE_AUTO_REJOIN" then
                Safety.AutoRejoin = not Safety.AutoRejoin
                sendLog("Auto-Rejoin saat kick: " .. (Safety.AutoRejoin and "AKTIF" or "NONAKTIF"), "INFO")

            else
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
            metricUnit = activeGameModule.MetricUnit,
            placeId = tostring(game.PlaceId)
        }

        for k, v in pairs(gameTelem) do
            combinedPayload[k] = v
        end

        sendPacket("TELEMETRY", combinedPayload)
        task.wait(1.0)
    end
end)

connectWebSocket()
