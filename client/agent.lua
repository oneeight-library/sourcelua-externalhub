--[[
    OneEight External Hub - Master Modular Client Agent
    Version: 3.3.0 (Build: v3.3.mv15v8i5)
--]]

local AGENT_BUILD_ID = "v3.3.mv15v8i5"
local LOADER_URL = "https://externalhub.oneeight-project18.workers.dev/loader"
local HttpService = game:GetService("HttpService")
local MY_INSTANCE_ID = HttpService:GenerateGUID(false)

-- Tutup socket lama secara bersih jika ada instance sebelumnya
if _G.OE_ExternalSocket then
    pcall(function() _G.OE_ExternalSocket:Close() end)
end

-- Klaim ID instance aktif saat ini secara atomik
_G.OE_ExternalCurrentInstance = MY_INSTANCE_ID
_G.OE_ExternalRunning = true

local function isInstanceAlive()
    return (_G.OE_ExternalCurrentInstance == MY_INSTANCE_ID)
end

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
    error("[OE-External VFS] Modul tidak ditemukan: " .. tostring(name))
end

Modules["core/safety"] = function()
--[[
    OneEight External Hub - Core Safety & Kick Detection Engine
    Clean & Robust Architecture:
    1. Anti-AFK (20-minute idle bypass)
    2. Real-time Kick / Disconnect detection (GuiService & RobloxPromptGui)
    3. Safe Teleport / Manual Rejoin helper (Clean & non-intrusive)
--]]

local Safety = {}
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

Safety.AutoRejoin = false -- Default Nonaktif agar bersih dan tidak mengganggu sesi game
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

-- 4. Clean Rejoin Function (Simple & Standard)
function Safety.RejoinNow(loaderUrl)
    loaderUrl = loaderUrl or "https://externalhub.oneeight-project18.workers.dev/loader"
    local queue_teleport = (syn and syn.queue_on_teleport) or queue_on_teleport or (fluxus and fluxus.queue_on_teleport) or queueonteleport
    if queue_teleport then
        pcall(function()
            queue_teleport(string.format([[
                task.wait(3.5)
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
    CDID Feature: Safety, Anti-Staff & Server Lock (100% Native In-Game Sync)
--]]
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SafetyFeature = {
    PlayerDetectorEnabled = false,
    EmergencyAction = "Warn Only",
    IgnoreFriends = true,
    ServerLocked = false, -- Default false (terbuka), sesuai state awal in-game
    Connection = nil
}

local function GetPrivateServerRemote()
    local net = ReplicatedStorage:FindFirstChild("NetworkContainer")
    if net then
        local remotes = net:FindFirstChild("RemoteEvents")
        if remotes then
            local ps = remotes:FindFirstChild("Private Server") or remotes:FindFirstChild("PrivateServer")
            if ps then return ps end
        end
    end

    for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
        if desc:IsA("RemoteEvent") and (desc.Name == "Private Server" or desc.Name == "PrivateServer") then
            return desc
        end
    end
    return nil
end

local function TriggerNativeCDIDToggle(enable)
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    local panel = pGui and pGui:FindFirstChild("PrivateServerPanel")
    local serverFrame = panel and panel:FindFirstChild("MainFrame") and panel.MainFrame:FindFirstChild("Main") and panel.MainFrame.Main:FindFirstChild("Server")

    if serverFrame then
        for _, c in ipairs(serverFrame:GetChildren()) do
            local title = c:FindFirstChild("OptionTitle")
            if title and title.Text == "Server Lock" then
                local toggleBtn = c:FindFirstChild("ToggleButton")
                local switch = toggleBtn and toggleBtn:FindFirstChild("ToggleSwitch")

                -- Cek posisi saat ini: 0.05 = OFF, 0.52 = ON
                local isCurrentlyOn = switch and (switch.Position.X.Scale > 0.3)
                local conns = (typeof(getconnections) == "function" and getconnections(toggleBtn.MouseButton1Down)) or {}

                if #conns > 0 and conns[1].Function then
                    if isCurrentlyOn ~= enable then
                        local ok = pcall(conns[1].Function)
                        if ok then return true end
                    end

                    local ups = typeof(debug.getupvalues) == "function" and debug.getupvalues(conns[1].Function)
                    if ups and typeof(ups[4]) == "function" then
                        local ok = pcall(ups[4], "Server Lock", enable and "Enable" or "Disable")
                        if ok then return true end
                    end
                end
            end
        end
    end
    return false
end

function SafetyFeature.CheckCurrentLockState()
    pcall(function()
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        local panel = pGui and pGui:FindFirstChild("PrivateServerPanel")
        local serverFrame = panel and panel:FindFirstChild("MainFrame") and panel.MainFrame:FindFirstChild("Main") and panel.MainFrame.Main:FindFirstChild("Server")
        if serverFrame then
            for _, c in ipairs(serverFrame:GetChildren()) do
                local title = c:FindFirstChild("OptionTitle")
                if title and title.Text == "Server Lock" then
                    local toggleBtn = c:FindFirstChild("ToggleButton")
                    local switch = toggleBtn and toggleBtn:FindFirstChild("ToggleSwitch")
                    if switch then
                        SafetyFeature.ServerLocked = (switch.Position.X.Scale > 0.3)
                    end
                end
            end
        end
    end)
    return SafetyFeature.ServerLocked
end

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
    SafetyFeature.CheckCurrentLockState()

    -- Vector 1: Native CDID toggle
    local nativeOk = TriggerNativeCDIDToggle(enable)

    -- Vector 2: RemoteEvent CDID: serverlock (Lock) atau serverunlock (Unlock)
    local psRemote = GetPrivateServerRemote()
    if psRemote then
        pcall(function()
            if enable then
                psRemote:FireServer("serverlock", {})
            else
                psRemote:FireServer("serverunlock", {})
            end
        end)
    end

    SafetyFeature.ServerLocked = enable

    if Context and Context.SendLog then
        Context.SendLog(string.format("Private Server Lock: %s", enable and "TERKUNCI 🔒" or "TERBUKA 🔓"), "INFO")
    end
end

return SafetyFeature
end

Modules["games/cdid/features/dealership"] = function()
--[[
    CDID Feature: Dealership Controller, Catalog Extractor & Remote Buy
    100% Berbasis Nilai car.Dealership.Value dari ReplicatedStorage.CarData
--]]
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DealershipFeature = {}

-- Urutan resmi nama dealer CDID langsung dari nilai Dealership di CarData
local DEFAULT_DEALER_LIST = {
    "77", "Bandung", "Otnas", "Premium", "Toyota", "Honda",
    "Hyundai", "Mitsubishi", "MercedesBenz", "Suzuki", "Daihatsu",
    "KIA", "Nissan", "Mazda", "Lexus", "Wuling", "Audi", "VW",
    "DIR", "Chery", "Jaecoo", "Geely", "Shehua", "SLM", "Komersial"
}

function DealershipFeature.GetRealDealerList()
    local list = {}
    local seen = {}

    -- Baca langsung semua nilai unik dari car.Dealership.Value di ReplicatedStorage.CarData
    pcall(function()
        local carData = ReplicatedStorage:FindFirstChild("CarData")
        if carData then
            for _, car in ipairs(carData:GetChildren()) do
                local unobtainable = car:FindFirstChild("Unobtainable")
                local d = car:FindFirstChild("Dealership") and car.Dealership.Value
                if d and d ~= "" and not unobtainable then
                    if d == "Komersil" then d = "Komersial" end
                    if not seen[d] then
                        seen[d] = true
                        table.insert(list, d)
                    end
                end
            end
        end
    end)

    if #list == 0 then
        return DEFAULT_DEALER_LIST
    end

    -- Urutkan sesuai urutan populer CDID
    local orderMap = {}
    for idx, name in ipairs(DEFAULT_DEALER_LIST) do
        orderMap[name:lower()] = idx
    end
    table.sort(list, function(a, b)
        local oa = orderMap[a:lower()] or 999
        local ob = orderMap[b:lower()] or 999
        if oa ~= ob then return oa < ob end
        return a:lower() < b:lower()
    end)

    return list
end

local GamepassMaps = nil
local function getGamepassMaps()
    if GamepassMaps then return GamepassMaps end
    GamepassMaps = {
        Luxury = {},
        Rare = {},
        Retro = {},
        Emergency = {},
        Limited = {},
        New = {}
    }
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    if shared then
        local function fill(name, target)
            local m = shared:FindFirstChild(name)
            if m and m:IsA("ModuleScript") then
                local ok, data = pcall(require, m)
                if ok and type(data) == "table" then
                    for _, id in ipairs(data) do
                        target[tostring(id):lower()] = true
                    end
                end
            end
        end
        fill("LuxuryCar", GamepassMaps.Luxury)
        fill("RareImportCar", GamepassMaps.Rare)
        fill("RetroCar", GamepassMaps.Retro)
        fill("EmergencyCar", GamepassMaps.Emergency)
        fill("LimitedCar", GamepassMaps.Limited)
        fill("NewCar", GamepassMaps.New)

        -- Load from Shared.Data.LimitedList
        local dataFolder = shared:FindFirstChild("Data")
        local limListMod = dataFolder and dataFolder:FindFirstChild("LimitedList")
        if limListMod and limListMod:IsA("ModuleScript") then
            local ok, data = pcall(require, limListMod)
            if ok and type(data) == "table" then
                for _, id in ipairs(data) do
                    GamepassMaps.Limited[tostring(id):lower()] = true
                end
            end
        end
    end
    return GamepassMaps
end

function DealershipFeature.GetCars(dealerTarget)
    local list = {}
    local carData = ReplicatedStorage:FindFirstChild("CarData")
    if not carData then return list end

    local cleanTarget = tostring(dealerTarget or ""):lower():gsub("%s+", "")
    if cleanTarget == "komersil" then cleanTarget = "komersial" end

    -- 1. Ambil Server Time resmi dari Backend Remote CDID (Network.GetServerTime)
    local serverTime = os.time()
    pcall(function()
        local mod = ReplicatedStorage:FindFirstChild("Modules")
        if mod and mod:FindFirstChild("Network") then
            local Network = require(mod.Network)
            local st = Network:InvokeServer("GetServerTime")
            if type(st) == "number" and st > 0 then
                serverTime = st
            end
        end
    end)

    -- 2. Ambil jadwal limited langsung dari Backend Memory Game (end_ts)
    local timeMap = {}
    pcall(function()
        if getgc then
            for _, t in ipairs(getgc(true)) do
                if type(t) == "table" then
                    local firstVal = nil
                    for _, v in pairs(t) do
                        firstVal = v
                        break
                    end
                    if type(firstVal) == "table" and rawget(firstVal, "end_ts") and rawget(firstVal, "start_ts") then
                        for carId, entry in pairs(t) do
                        if type(entry) == "table" and entry.end_ts and type(entry.end_ts) == "table" then
                            local expTs = os.time(entry.end_ts)
                            local startTs = entry.start_ts and os.time(entry.start_ts) or 0
                            if startTs > serverTime then
                                -- Mobil terjadwal rilis di masa depan (Upcoming Bocoran)
                                local diffStart = startTs - serverTime
                                local h = math.floor(diffStart / 3600)
                                local m = math.floor((diffStart % 3600) / 60)
                                local s = diffStart % 60
                                timeMap[tostring(carId):lower()] = {
                                    timeLeft = string.format("%02i:%02i:%02i", h, m, s),
                                    expiresAt = expTs,
                                    startAt = startTs,
                                    isUpcoming = true,
                                    serverTime = serverTime
                                }
                            else
                                local diffSec = expTs - serverTime
                                if diffSec > 0 then
                                    local h = math.floor(diffSec / 3600)
                                    local m = math.floor((diffSec % 3600) / 60)
                                    local s = diffSec % 60
                                    timeMap[tostring(carId):lower()] = {
                                        timeLeft = string.format("%02i:%02i:%02i", h, m, s),
                                        expiresAt = expTs,
                                        isUpcoming = false,
                                        serverTime = serverTime
                                    }
                                end
                            end
                        end
                    end
                        break
                    end
                end
            end
        end
    end)

    -- 3. Fallback: Ambil dari TextLabel UI jika memory schedule tidak terjangkau
    pcall(function()
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        local dGui = pGui and pGui:FindFirstChild("Dealership")
        local dList = dGui and dGui:FindFirstChild("Container") and dGui.Container:FindFirstChild("Dealership") and dGui.Container.Dealership:FindFirstChild("Dealerlist")
        if dList then
            for _, dFolder in ipairs(dList:GetChildren()) do
                for _, cFrame in ipairs(dFolder:GetChildren()) do
                    local lowerName = cFrame.Name:lower()
                    if not timeMap[lowerName] then
                        local tLbl = cFrame:FindFirstChild("Frame") and cFrame.Frame:FindFirstChild("Time")
                        if tLbl and tLbl:IsA("TextLabel") and tLbl.Text ~= "" and tLbl.Text ~= "00:00:00" then
                            local h, m, s = tLbl.Text:match("(%d+):(%d+):(%d+)")
                            local sec = 0
                            if h and m and s then
                                sec = tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s)
                            end
                            timeMap[lowerName] = {
                                timeLeft = tLbl.Text,
                                expiresAt = (sec > 0) and (serverTime + sec) or nil,
                                serverTime = serverTime
                            }
                        end
                    end
                end
            end
        end
    end)

    local maps = getGamepassMaps()

    for _, car in ipairs(carData:GetChildren()) do
        local dealerVal = car:FindFirstChild("Dealership")
        local unobtainable = car:FindFirstChild("Unobtainable")
        local lowerId = car.Name:lower()
        local timeInfo = timeMap[lowerId]

        -- Kategori "Upcoming" HANYA diberikan jika ada entri start_ts di memori server yang menunjukkan waktu rilis di masa depan (start_ts > now)
        local isUpcoming = false
        if timeInfo and timeInfo.isUpcoming == true then
            isUpcoming = true
        end

        if dealerVal and (not unobtainable or isUpcoming) then
            local rawDealer = tostring(dealerVal.Value)
            local cleanDealer = rawDealer:lower():gsub("%s+", "")
            if cleanDealer == "komersil" then cleanDealer = "komersial" end

            local isMatch = false
            if cleanTarget == "" or cleanTarget == "all" or cleanTarget == "semuadealer" then
                isMatch = true
            elseif cleanDealer == cleanTarget then
                -- PURE EXACT MATCH terhadap nilai car.Dealership.Value
                isMatch = true
            end

            if isMatch then
                local maps = getGamepassMaps()
                local lowerId = car.Name:lower()
                local gamepassLabel = ""
                local isGamepass = false

                if maps.Luxury[lowerId] then
                    gamepassLabel = "Luxury"
                    isGamepass = true
                elseif maps.Rare[lowerId] then
                    gamepassLabel = "Rare Import"
                    isGamepass = true
                elseif maps.Retro[lowerId] then
                    gamepassLabel = "Retro"
                    isGamepass = true
                elseif maps.Emergency[lowerId] then
                    gamepassLabel = "Emergency"
                    isGamepass = true
                end

                local timeInfo = timeMap[lowerId]
                local timeLeft = timeInfo and timeInfo.timeLeft or ""
                local expiresAt = timeInfo and timeInfo.expiresAt or nil
                local isLimited = false
                if maps.Limited[lowerId] or car:FindFirstChild("Limited") or timeLeft ~= "" then
                    isLimited = true
                end

                local isNew = maps.New[lowerId] == true

                local stockVal = nil
                local stockFolder = ReplicatedStorage:FindFirstChild("LimitedStock")
                if stockFolder then
                    local sItem = stockFolder:FindFirstChild(car.Name)
                    if sItem and (sItem:IsA("IntValue") or sItem:IsA("NumberValue")) then
                        stockVal = sItem.Value
                    end
                end

                local img = car:FindFirstChild("CarImage") and car.CarImage.Value or ""
                local assetId = img:match("id=(%d+)") or img:match("(%d+)$") or ""
                local engineVal = car:FindFirstChild("Engine") and tostring(car.Engine.Value) or ""
                local seaterVal = car:FindFirstChild("Seater") and tostring(car.Seater.Value) or ""
                table.insert(list, {
                    id = car.Name,
                    name = car:FindFirstChild("CarName") and car.CarName.Value or car.Name,
                    cost = car:FindFirstChild("Cost") and car.Cost.Value or 0,
                    dealer = rawDealer, -- Nilai tepat dari car.Dealership.Value
                    assetId = assetId,
                    topSpeed = car:FindFirstChild("TopSpeed") and car.TopSpeed.Value or 0,
                    hp = car:FindFirstChild("Horsepower") and car.Horsepower.Value or 0,
                    year = car:FindFirstChild("CarYear") and car.CarYear.Value or "",
                    engine = engineVal,
                    seater = seaterVal,
                    gamepass = gamepassLabel,
                    isGamepass = isGamepass,
                    isLimited = isLimited,
                    isNew = isNew,
                    isUpcoming = isUpcoming,
                    stock = stockVal,
                    timeLeft = timeLeft,
                    expiresAt = expiresAt,
                    serverTime = serverTime
                })
            end
        end
    end

    table.sort(list, function(a, b) return a.cost < b.cost end)
    return list
end

function DealershipFeature.Buy(carId, dealer, color, Context)
    local colorName = "White"
    if type(color) == "string" and color ~= "" then
        colorName = color
    elseif type(color) == "table" and color.name then
        colorName = color.name
    end

    local cMap = {
        ["Putih"] = "White",
        ["Hitam"] = "Black",
        ["Silver"] = "White",
        ["Abu-abu"] = "Black",
        ["Merah"] = "Red",
        ["Biru"] = "Blue",
        ["Kuning"] = "Yellow",
        ["Oranye"] = "Orange",
        ["Hijau"] = "Green",
        ["Pink"] = "Pink"
    }
    colorName = cMap[colorName] or colorName or "White"

    local result = "Failed"
    pcall(function()
        local Network = require(ReplicatedStorage.Modules.Network)
        result = Network:InvokeServer("Dealership", "Buy", carId, colorName, dealer or "")
    end)
    local isSuccess = (result == "Success")
    if Context and Context.SendLog then
        Context.SendLog(string.format("Hasil beli mobil '%s' (%s, Warna %s): %s", carId, tostring(dealer), colorName, tostring(result)), isSuccess and "SUCCESS" or "WARN")
    end
    if Context and Context.SendPacket then
        pcall(function()
            Context.SendPacket("BUY_CAR_RESULT", {
                carId = carId,
                dealer = dealer or "",
                color = colorName,
                success = isSuccess,
                message = tostring(result)
            })
        end)
    end
    return result
end

function DealershipFeature.Open(dealerName, Context)
    dealerName = dealerName or "77"
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

Modules["games/cdid/features/job_progress"] = function()
--[[
    OneEight External Hub - Job Progress & Level Claim Feature
    100% Pure Backend DataReplication Engine
    - Direct read from replica.Data.Jobs (Zero UI scraping)
    - Full mathematical level curve calculation (Levels 1 - 50)
    - Reward Matrix ($24M base + $9.6M/level, +10% income on milestones)
    - Single and Multi-Claim (Claim All) automated execution via Network Remote
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local JobProgressFeature = {}
local Context = nil
local cachedReplica = nil

local function GetReplica()
    if cachedReplica and cachedReplica.Data then
        return cachedReplica
    end
    pcall(function()
        local dataRep = require(ReplicatedStorage.Services.DataReplication)
        local ups = debug.getupvalues(dataRep.GetCash)
        if ups and ups[1] then
            cachedReplica = ups[1]
        end
    end)
    return cachedReplica
end

local function formatRupiah(amount)
    amount = tonumber(amount) or 0
    local formatted = tostring(math.floor(math.abs(amount))):reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")
    return (amount < 0 and "-Rp " or "Rp ") .. formatted
end

local function calculateLevel(rawXp)
    local xp = math.max(math.floor(rawXp or 0), 0)
    local lvl = 1
    while lvl < 50 do
        local nextLvl = lvl + 1
        local n = nextLvl - 1
        local threshold = n * 150 + n * 35 * (n - 1) / 2
        if threshold <= xp then
            lvl = nextLvl
        else
            break
        end
    end
    local n = lvl - 1
    local currentLevelBaseXp = n * 150 + n * 35 * (n - 1) / 2
    local xpInLevel = xp - currentLevelBaseXp
    local xpNeeded = (lvl >= 50) and 0 or ((lvl - 1) * 35 + 150)
    return lvl, xpInLevel, xpNeeded, xp
end

local function getRemote()
    local netContainer = ReplicatedStorage:FindFirstChild("NetworkContainer")
    local remotes = netContainer and netContainer:FindFirstChild("RemoteEvents")
    return remotes and remotes:FindFirstChild("JobProgress")
end

local function fireClaim(jobName, level)
    local Net = nil
    pcall(function()
        local modules = ReplicatedStorage:FindFirstChild("Modules")
        if modules and modules:FindFirstChild("Network") then
            Net = require(modules.Network)
        end
    end)
    if Net and typeof(Net.FireServer) == "function" then
        Net:FireServer("JobProgress", "Claim", jobName, tonumber(level))
    else
        local remote = getRemote()
        if remote then
            remote:FireServer("Claim", jobName, tonumber(level))
        end
    end
end

function JobProgressFeature.Init(coreContext)
    Context = coreContext
    GetReplica()
    print("[OE-External CDID] Modul Job Progress (Level & Claim) Berhasil Diinisialisasi!")
end

function JobProgressFeature.GetRawJobData(jobName)
    local replica = GetReplica()
    if replica and replica.Data and replica.Data.Jobs then
        local jobObj = replica.Data.Jobs[jobName]
        if typeof(jobObj) == "table" then
            return {
                xp = tonumber(jobObj.xp) or 0,
                claimed = (typeof(jobObj.claimed) == "table" and jobObj.claimed) or {},
                titles = (typeof(jobObj.titles) == "table" and jobObj.titles) or {},
                tutorialDone = jobObj.tutorialDone == true
            }
        elseif typeof(jobObj) == "number" then
            return {
                xp = jobObj,
                claimed = {},
                titles = {},
                tutorialDone = true
            }
        end
    end
    return {
        xp = 0,
        claimed = {},
        titles = {},
        tutorialDone = false
    }
end

function JobProgressFeature.GetProgressData(jobName)
    jobName = jobName or "Barista"
    local raw = JobProgressFeature.GetRawJobData(jobName)
    local currentLvl, xpInLevel, xpNeeded, totalXp = calculateLevel(raw.xp)

    local rewards = {}
    local claimableCount = 0
    local totalClaimed = 0

    for lvl = 2, 50 do
        local isMilestone = (lvl % 10 == 0)
        local rewardText = ""
        local cash = 0
        if isMilestone then
            rewardText = "+10% Income Permanen & Gelar Title"
        else
            cash = 24000000 + (lvl - 2) * 9600000
            rewardText = formatRupiah(cash)
        end

        local status = "LOCKED"
        if raw.claimed[tostring(lvl)] == true then
            status = "CLAIMED"
            totalClaimed = totalClaimed + 1
        elseif lvl <= currentLvl then
            status = "CAN_CLAIM"
            claimableCount = claimableCount + 1
        end

        table.insert(rewards, {
            level = lvl,
            isMilestone = isMilestone,
            rewardText = rewardText,
            cash = cash,
            status = status
        })
    end

    local percent = (xpNeeded > 0) and math.clamp(math.floor((xpInLevel / xpNeeded) * 100), 0, 100) or 100
    local replica = GetReplica()
    local equippedTitle = (replica and replica.Data and replica.Data.EquippedTitle) or ""

    return {
        jobName = jobName,
        level = currentLvl,
        xp = totalXp,
        xpInLevel = xpInLevel,
        xpNeeded = xpNeeded,
        percent = percent,
        claimableCount = claimableCount,
        totalClaimed = totalClaimed,
        equippedTitle = equippedTitle,
        rewards = rewards
    }
end

function JobProgressFeature.ClaimLevel(jobName, level)
    jobName = jobName or "Barista"
    level = tonumber(level)
    if not level or level < 2 or level > 50 then return false end

    local raw = JobProgressFeature.GetRawJobData(jobName)
    local currentLvl = calculateLevel(raw.xp)

    if level > currentLvl then
        if Context and Context.SendLog then
            Context.SendLog(string.format("Level %d belum terbuka (Level saat ini: %d)", level, currentLvl), "WARN")
        end
        return false
    end

    if raw.claimed[tostring(level)] == true then
        if Context and Context.SendLog then
            Context.SendLog(string.format("Hadiah Level %d sudah pernah diklaim sebelumnya.", level), "WARN")
        end
        return false
    end

    fireClaim(jobName, level)

    if Context and Context.SendLog then
        Context.SendLog(string.format("Mengklaim hadiah Level %d untuk pekerjaan %s...", level, jobName), "SUCCESS")
    end

    return true
end

function JobProgressFeature.ClaimAll(jobName)
    jobName = jobName or "Barista"
    local raw = JobProgressFeature.GetRawJobData(jobName)
    local currentLvl = calculateLevel(raw.xp)

    local toClaim = {}
    for lvl = 2, math.min(currentLvl, 50) do
        if raw.claimed[tostring(lvl)] ~= true then
            table.insert(toClaim, lvl)
        end
    end

    if #toClaim == 0 then
        if Context and Context.SendLog then
            Context.SendLog("Tidak ada hadiah level baru yang bisa diklaim saat ini.", "INFO")
        end
        return 0
    end

    if Context and Context.SendLog then
        Context.SendLog(string.format("Memulai klaim otomatis untuk %d hadiah level (%s)...", #toClaim, jobName), "INFO")
    end

    task.spawn(function()
        local successCount = 0
        for _, lvl in ipairs(toClaim) do
            fireClaim(jobName, lvl)
            successCount = successCount + 1
            task.wait(0.35)
        end
        if Context and Context.SendLog then
            Context.SendLog(string.format("Selesai mengklaim %d hadiah level %s!", successCount, jobName), "SUCCESS")
        end
    end)

    return #toClaim
end

return JobProgressFeature
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

    -- HASIL SESI HANYA DIHITUNG JIKA JOB TRUK SEDANG AKTIF BERJALAN!
    if State.IsFarming then
        if not State.StartCash or State.StartCash <= 0 then
            State.StartCash = val
        end
        local netDiff = State.CurrentCash - State.StartCash
        if netDiff >= 0 then
            State.TotalEarnings = netDiff
        end
    end

    -- Kirim instant telemetry packet saat saldo berubah/terdeteksi
    if Context and Context.SendPacket then
        pcall(function()
            Context.SendPacket("TELEMETRY", {
                currentCash = State.CurrentCash,
                startCash = State.StartCash,
                totalEarnings = State.IsFarming and State.TotalEarnings or 0,
                truckEarnings = State.IsFarming and State.TotalEarnings or 0
            })
        end)
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
    _G.OE_TeleportQueued = nil

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
    -- Reset titik awal saldo dan hasil sesi khusus untuk sesi job kargo ini
    State.StartCash = State.CurrentCash or 0
    State.TotalEarnings = 0
    State.TripCount = 0
    if Context and Context.SendLog then
        Context.SendLog("Auto Farm Truk Kargo CDID dimulai!", "SUCCESS")
    end
    if Context and Context.SendPacket then
        pcall(function()
            Context.SendPacket("TELEMETRY", {
                isFarming = true,
                totalEarnings = 0,
                truckEarnings = 0,
                tripCount = 0,
                farmDuration = 0
            })
        end)
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

function TruckJob.GetMetrics()
    local car = DriveEngine.GetPlayerCar()
    local hum, hrp = DriveEngine.GetValidHumanoid()
    local speedKmh = 0
    local distRemainingStr = "0m"

    if car and car.PrimaryPart then
        speedKmh = math.floor(car.PrimaryPart.AssemblyLinearVelocity.Magnitude * 3.6)
    elseif hrp then
        speedKmh = math.floor(hrp.AssemblyLinearVelocity.Magnitude * 3.6)
    end

    if State.CurrentTargetPos and hrp then
        local d = (hrp.Position - State.CurrentTargetPos).Magnitude
        if d >= 1000 then
            distRemainingStr = string.format("%.1f km", d / 1000)
        else
            distRemainingStr = string.format("%d m", math.floor(d))
        end
    end

    return speedKmh, distRemainingStr
end

function TruckJob.GetState()
    local speed, dist = TruckJob.GetMetrics()
    State.Speed = speed
    State.DistRemaining = dist
    return State
end

return TruckJob
end

Modules["games/cdid/jobs/minigames"] = function()
--[[
    OneEight External Hub - CDID Minigames Farm (Sumo Arena) Module
    Ported from Official OneEight Hub CDID Minigame Engine
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local MinigameJob = {}
MinigameJob.JobName = "Minigames Sumo"
MinigameJob.PlaceId = 14005966837

local Context = nil

-- 1. CONFIG
--[[
    OneEight Hub - CDID Minigames Farm Configuration
    Contains settings, payout rates, timeouts, and arena metadata.
--]]

local Config = {
    JobName = "Minigames Sumo Farm",
    PlaceIds = { 14005966837 }, -- Jakarta Map

    -- Minigame Server Constraints
    MINIMUM_PLAYERS = 6,
    MAXIMUM_PLAYERS = 20,
    MAXIMUM_ROUNDS = 10,
    LOBBY_PREPARE_TIME = 30,

    -- Reward Matrix (From ReplicatedStorage.Shared.MinigameConfig)
    Rewards = {
        Public = {
            Win = { Points = 20, Cash = 100000000 },
            Lose = { Points = 10, Cash = 50000000 },
            Draw = { Points = 10, Cash = 50000000 }
        },
        Private = {
            Win = { Points = 10, Cash = 25000000 },
            Lose = { Points = 5, Cash = 10000000 },
            Draw = { Points = 5, Cash = 10000000 }
        }
    },

    -- Box Shop Details
    BoxCost = 20, -- 20 Points per Minigame Box

    -- Timings & Delays
    LobbyCheckInterval = 2.0,
    CarSelectWait = 1.0,
    RoundCheckInterval = 0.5,
    YieldDropDelay = 1.5, -- Delay after round start before bot intentionally falls
    YieldDropDistance = 250, -- Studs to teleport downwards into Hitbox Outside
    SafetyHoverHeight = 15, -- Studs above arena for Winner hover safety mode
    PostMatchWait = 3.0 -- Wait after returning to city before re-entering lobby
}



-- 2. STATE
--[[
    OneEight Hub - CDID Minigames Farm State Management
    Holds live session statistics, roles, statuses, and runtime counters.
--]]

local State = {
    -- Farming Flags
    AutoFarmActive = false,
    Role = "Winner", -- "Winner" (Akun Utama / Selalu Menang) or "Loser" (Akun Bot / Mengalah Cepat)
    AutoOpenBox = false, -- Otomatis beli Minigame Box tiap 20 Poin
    Phase = "Standby", -- "Standby", "SelectingCar", "InLobby", "InArena", "YieldingRound", "CompletedMatch"

    -- Lobby & Match Tracking
    LobbyStatusText = "Standby",
    LobbyPlayersCount = 0,
    CurrentRound = 0,
    MaxRounds = 10,
    CurrentTeam = "-",
    SelectedCar = "Auto",
    LastMatchResult = "-",

    -- Live Economy & Counters (Sinkron 100% Backend CDID)
    StartingPoints = nil,
    StartingCash = nil,
    CurrentPoints = 0,
    CurrentCash = 0,
    PointsEarned = 0,
    CashEarned = 0,
    TotalMatches = 0,
    TotalWins = 0,
    TotalLosses = 0,
    BoxesOpened = 0,

    -- Live Game Scores & Reason
    BlueScore = 0,
    RedScore = 0,
    LastGameOverReason = nil,

    FarmStartTime = nil,
    AvgPointsPerHour = 0,

    -- Formatted Strings for UI
    PointsEarnedText = "+0 Poin",
    CashEarnedText = "Rp 0",
    MatchRecordText = "0 Menang / 0 Kalah",

    -- UI References & Callbacks
    Window = nil,
    UpdateStatsUI = nil,
    Config = nil
}



State.Config = Config

-- 3. HELPERS
--[[
    OneEight Hub - CDID Minigames Farm Helpers
    Provides utility functions for vehicle detection, UI interaction, arena tracking, and physics controls.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Helpers = {}

function Helpers.Init(stateInstance, configInstance)
    State = stateInstance
    Config = configInstance
end

function Helpers.GetLocalPlayer()
    return Players.LocalPlayer
end

function Helpers.GetCharacter()
    local lp = Players.LocalPlayer
    return lp and lp.Character
end

function Helpers.GetRootPart()
    local char = Helpers.GetCharacter()
    return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"))
end

function Helpers.GetVehicle()
    local char = Helpers.GetCharacter()
    if not char then return nil end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return nil end

    local seat = humanoid.SeatPart
    if seat and seat:IsA("VehicleSeat") then
        local model = seat:FindFirstAncestorOfClass("Model")
        return model, seat
    end

    -- Fallback scan (hanya di folder Vehicles agar tidak memindai puluhan ribu part workspace)
    local vehicles = workspace:FindFirstChild("Vehicles")
    if vehicles then
        for _, obj in ipairs(vehicles:GetDescendants()) do
            if obj:IsA("VehicleSeat") and obj.Occupant == humanoid then
                return obj:FindFirstAncestorOfClass("Model"), obj
            end
        end
    end

    return nil, nil
end

local cachedCars = nil
local lastCarFetch = 0

function Helpers.GetOwnedCars()
    if cachedCars and (os.clock() - lastCarFetch < 30) then
        return cachedCars
    end

    local cars = {}
    -- 1. Coba backend langsung dari DataReplication
    pcall(function()
        local dataRep = require(ReplicatedStorage.Services.DataReplication)
        local vData = dataRep.GetVehicleData and dataRep.GetVehicleData()
        local carDataFolder = ReplicatedStorage:FindFirstChild("CarData")
        if vData and type(vData) == "table" then
            for code, _ in pairs(vData) do
                local disp = code
                if carDataFolder and carDataFolder:FindFirstChild(code) and carDataFolder[code]:FindFirstChild("CarName") then
                    disp = carDataFolder[code].CarName.Value
                end
                table.insert(cars, {
                    Id = code,
                    DisplayName = disp
                })
            end
        end
    end)

    if #cars > 0 then return cars end

    -- 2. Fallback baca dari UI SelectCar jika backend gagal
    pcall(function()
        local lp = Players.LocalPlayer
        local raceGui = lp and lp.PlayerGui:FindFirstChild("Race")
        local scFrame = raceGui and raceGui:FindFirstChild("Container")
            and raceGui.Container:FindFirstChild("SelectCar")
            and raceGui.Container.SelectCar:FindFirstChild("ScrollingFrame")
        if scFrame then
            for _, item in ipairs(scFrame:GetChildren()) do
                if item:IsA("Frame") and item:FindFirstChild("Frame") then
                    local textLbl = item.Frame:FindFirstChild("TextLabel")
                    table.insert(cars, {
                        Id = item.Name,
                        DisplayName = textLbl and textLbl.Text or item.Name
                    })
                end
            end
        end
    end)

    if #cars > 0 then
        cachedCars = cars
        lastCarFetch = os.clock()
        return cars
    end

    return cars
end

function Helpers.GetResolvedCarCode(carSetting)
    local cars = Helpers.GetOwnedCars()
    if #cars == 0 then
        return "2011A620TAvant" -- Safe universal default in CDID
    end

    if not carSetting or carSetting == "Auto" or carSetting == "Auto (Paling Atas)" then
        return cars[1].Id
    end

    for _, c in ipairs(cars) do
        if c.Id == carSetting or c.DisplayName == carSetting then
            return c.Id
        end
    end

    return cars[1].Id
end

function Helpers.SelectCar(carId)
    local resolvedCode = Helpers.GetResolvedCarCode(carId)
    State.SelectedCar = resolvedCode

    -- Trigger UI click jika ada button agar UI game sinkron
    pcall(function()
        local lp = Players.LocalPlayer
        local raceGui = lp and lp.PlayerGui:FindFirstChild("Race")
        local scFrame = raceGui and raceGui:FindFirstChild("Container")
            and raceGui.Container:FindFirstChild("SelectCar")
            and raceGui.Container.SelectCar:FindFirstChild("ScrollingFrame")
        if scFrame then
            local item = scFrame:FindFirstChild(resolvedCode)
            if item and item:FindFirstChild("Frame") and item.Frame:FindFirstChild("TextButton") then
                local btn = item.Frame.TextButton
                if typeof(firesignal) == "function" then
                    firesignal(btn.MouseButton1Down)
                elseif typeof(getconnections) == "function" then
                    for _, conn in ipairs(getconnections(btn.MouseButton1Down)) do
                        conn:Fire()
                    end
                end
            end
        end
    end)

    return true
end

function Helpers.IsInLobby()
    local lp = Players.LocalPlayer
    if not lp then return false end

    local minigameFrame = lp.PlayerGui:FindFirstChild("Race")
        and lp.PlayerGui.Race:FindFirstChild("Container")
        and lp.PlayerGui.Race.Container:FindFirstChild("Minigame")
    if not minigameFrame then return false end

    local enterBtn = minigameFrame:FindFirstChild("EnterButton")
    if enterBtn and enterBtn:FindFirstChild("Label") and enterBtn.Label.Text == "LEAVE" then
        return true
    end

    -- Fallback: Cek apakah nama player terdaftar di playerlist lobby
    local pListFrame = minigameFrame:FindFirstChild("PlayerList")
        and minigameFrame.PlayerList:FindFirstChild("ScrollingFrame")
    if pListFrame and pListFrame:FindFirstChild(lp.Name) then
        return true
    end

    return false
end

function Helpers.GetLobbyStatus()
    local lp = Players.LocalPlayer
    if not lp then return "-" end

    local minigameFrame = lp.PlayerGui:FindFirstChild("Race")
        and lp.PlayerGui.Race:FindFirstChild("Container")
        and lp.PlayerGui.Race.Container:FindFirstChild("Minigame")
    if not minigameFrame then return "-" end

    local statusLbl = minigameFrame:FindFirstChild("MainFrame")
        and minigameFrame.MainFrame:FindFirstChild("Status")
    return statusLbl and statusLbl.Text or "-"
end

function Helpers.GetLobbyPlayerCount()
    local lp = Players.LocalPlayer
    if not lp then return 0 end

    local pListFrame = lp.PlayerGui:FindFirstChild("Race")
        and lp.PlayerGui.Race:FindFirstChild("Container")
        and lp.PlayerGui.Race.Container:FindFirstChild("Minigame")
        and lp.PlayerGui.Race.Container.Minigame:FindFirstChild("PlayerList")
        and lp.PlayerGui.Race.Container.Minigame.PlayerList:FindFirstChild("ScrollingFrame")
    if not pListFrame then return 0 end

    local count = 0
    for _, c in ipairs(pListFrame:GetChildren()) do
        if c:IsA("Frame") then
            count = count + 1
        end
    end

    return count
end

function Helpers.IsInArena()
    local lp = Players.LocalPlayer
    if not lp then return false end

    -- 1. Ketinggian arena fisik (di atas langit Y > 800)
    local root = Helpers.GetRootPart()
    if root and root.Position.Y > 800 then
        return true
    end

    -- 2. GUI TopBar aktif (ronde sedang berjalan)
    local miniGui = lp.PlayerGui:FindFirstChild("Minigame")
    local mainFrame = miniGui and miniGui:FindFirstChild("Main")
    local topBar = mainFrame and mainFrame:FindFirstChild("TopBar")
    if topBar and topBar.Visible then
        return true
    end

    return false
end

function Helpers.GetRoundInfo()
    local lp = Players.LocalPlayer
    if not lp then return 1, 10 end

    local miniGui = lp.PlayerGui:FindFirstChild("Minigame")
    local topBar = miniGui and miniGui:FindFirstChild("Main") and miniGui.Main:FindFirstChild("TopBar")
    local roundFrame = topBar and topBar:FindFirstChild("Round")
    local roundLbl = roundFrame and roundFrame:FindFirstChildWhichIsA("TextLabel")

    if roundLbl and roundLbl.Text then
        -- Cocokkan format apapun: "Round: 1", "Round 1", "1/10", dsb.
        local num = string.match(roundLbl.Text, "(%d+)")
        if num then
            local max = string.match(roundLbl.Text, "%d+%s*/%s*(%d+)") or 10
            return tonumber(num), tonumber(max)
        end
    end

    return 1, 10
end

-- ==============================================================================
-- REAL-TIME LIVE POINTS & CASH (CACHED BACKEND DATA REPLICATION)
-- ==============================================================================
local cachedReplica = nil

local function GetReplica()
    if cachedReplica and cachedReplica.Data then
        return cachedReplica
    end
    pcall(function()
        local dataRep = require(ReplicatedStorage.Services.DataReplication)
        local ups = debug.getupvalues(dataRep.GetCash)
        if ups and ups[1] then
            cachedReplica = ups[1]
        end
    end)
    return cachedReplica
end

function Helpers.GetMinigamePoints()
    local pts = nil
    pcall(function()
        local replica = GetReplica()
        if replica and replica.Data and replica.Data.Minigame then
            pts = tonumber(replica.Data.Minigame.Point)
        end
    end)

    if pts ~= nil then
        State.CurrentPoints = pts
        return pts
    end

    return State.CurrentPoints or 0
end

function Helpers.GetCash()
    local cash = nil
    pcall(function()
        local replica = GetReplica()
        if replica and replica.Data and replica.Data.Cash then
            cash = tonumber(replica.Data.Cash)
        end
    end)

    if cash == nil then
        pcall(function()
            local dataRep = require(ReplicatedStorage.Services.DataReplication)
            if typeof(dataRep.GetCash) == "function" then
                cash = tonumber(dataRep.GetCash())
            end
        end)
    end

    if cash ~= nil then
        State.CurrentCash = cash
        return cash
    end

    return State.CurrentCash or 0
end

-- ==============================================================================
-- REAL-TIME MATCH TELEMETRY (LIVE GAME GUI READER)
-- ==============================================================================
function Helpers.GetGameMatchStatus()
    local lp = Players.LocalPlayer
    if not lp then return nil end

    local miniGui = lp.PlayerGui:FindFirstChild("Minigame")
    local main = miniGui and miniGui:FindFirstChild("Main")
    if not main then return nil end

    local topBar = main:FindFirstChild("TopBar")
    local notif = main:FindFirstChild("Notification")

    local status = {
        TopBarVisible = (topBar and topBar.Visible) or false,
        NotifVisible = (notif and notif.Visible) or false,
        NotifTitle = notif and notif:FindFirstChild("Label1") and notif.Label1.Text or "",
        NotifDesc = notif and notif:FindFirstChild("Label2") and notif.Label2.Text or "",
        BlueWins = 0,
        RedWins = 0,
        BlueAlive = 0,
        RedAlive = 0,
        RoundNumber = 1,
    }

    if topBar then
        local roundLbl = topBar:FindFirstChild("Round", true) and topBar.Round:FindFirstChildWhichIsA("TextLabel")
        if roundLbl and roundLbl.Text then
            status.RoundNumber = tonumber(string.match(roundLbl.Text, "(%d+)")) or 1
        end

        local blueWin = topBar:FindFirstChild("Blue") and topBar.Blue:FindFirstChild("WinLabel")
        if blueWin and blueWin.Text then
            status.BlueWins = tonumber(string.match(blueWin.Text, "(%d+)")) or 0
        end

        local redWin = topBar:FindFirstChild("Red") and topBar.Red:FindFirstChild("WinLabel")
        if redWin and redWin.Text then
            status.RedWins = tonumber(string.match(redWin.Text, "(%d+)")) or 0
        end

        local blueAlive = topBar:FindFirstChild("Blue") and topBar.Blue:FindFirstChild("AliveLabel")
        if blueAlive and blueAlive.Text then
            status.BlueAlive = tonumber(string.match(blueAlive.Text, "(%d+)")) or 0
        end

        local redAlive = topBar:FindFirstChild("Red") and topBar.Red:FindFirstChild("AliveLabel")
        if redAlive and redAlive.Text then
            status.RedAlive = tonumber(string.match(redAlive.Text, "(%d+)")) or 0
        end
    end

    State.BlueScore = status.BlueWins
    State.RedScore = status.RedWins

    return status
end

function Helpers.GetMyTeam()
    local lp = Players.LocalPlayer
    if not lp then return "-" end

    -- 1. Cek dari Team Player
    if lp.Team and lp.Team.Name ~= "" then
        local tName = string.lower(lp.Team.Name)
        if string.find(tName, "blue") then return "Blue" end
        if string.find(tName, "red") then return "Red" end
    end

    -- 2. Cek dari Attributes
    local attr = lp:GetAttribute("Team") or lp:GetAttribute("MinigameTeam")
    if attr then
        local tName = string.lower(tostring(attr))
        if string.find(tName, "blue") then return "Blue" end
        if string.find(tName, "red") then return "Red" end
    end

    -- 3. Cek dari PlayerList di UI Minigame
    local miniGui = lp.PlayerGui:FindFirstChild("Minigame")
    local main = miniGui and miniGui:FindFirstChild("Main")
    if main then
        local blueList = main:FindFirstChild("Blue", true)
        local redList = main:FindFirstChild("Red", true)
        if blueList and blueList:FindFirstChild(lp.Name, true) then return "Blue" end
        if redList and redList:FindFirstChild(lp.Name, true) then return "Red" end
    end

    return State.CurrentTeam or "-"
end

-- ==============================================================================
-- STRATEGI GAMEPLAY: BOT KELUAR MOBIL & AKUN UTAMA STANDBY DI ARENA
-- ==============================================================================

-- Fungsi unseat: paksa karakter turun/lompat dari mobil
function Helpers.ExitVehicle()
    local char = Helpers.GetCharacter()
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Sit then
        hum.Sit = false
        hum.Jump = true
    end
end

-- Untuk Akun Bot: Cukup unseat & lompat dari mobil agar gugur ronde tanpa mati/DC
function Helpers.YieldRound()
    Helpers.ExitVehicle()
end

-- Untuk Akun Utama (Selalu Menang): Murni diam alami tanpa treatment/intervensi apapun
function Helpers.HoldSafetyPosition()
    -- No-op: Murni diam di tempat duduk mobil
end

function Helpers.CleanAllUIs()
    pcall(function()
        local lp = Players.LocalPlayer
        if not lp then return end
        local raceGui = lp.PlayerGui:FindFirstChild("Race")
        if raceGui and raceGui:FindFirstChild("Container") then
            local selCar = raceGui.Container:FindFirstChild("SelectCar")
            if selCar then selCar.Visible = false end
            local mg = raceGui.Container:FindFirstChild("Minigame")
            if mg then mg.Visible = false end
        end
    end)
end



-- 4. NETWORK
--[[
    OneEight Hub - CDID Minigames Farm Network Handler
    Manages RemoteEvents for joining/leaving minigames, buying gacha boxes, and listening to match broadcasts.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local NetworkHandler = {}
local NetworkModule = nil

function NetworkHandler.Init(stateInstance, helpersInstance, configInstance)
    State = stateInstance
    Helpers = helpersInstance
    Config = configInstance

    -- Load Network Module
    pcall(function()
        NetworkModule = require(ReplicatedStorage.Modules.Network)
    end)
end

function NetworkHandler.GetNetworkModule()
    if NetworkModule and typeof(NetworkModule.FireServer) == "function" then
        return NetworkModule
    end
    pcall(function()
        local mod = ReplicatedStorage:FindFirstChild("Modules")
        if mod and mod:FindFirstChild("Network") then
            NetworkModule = require(mod.Network)
        end
    end)
    return NetworkModule
end

function NetworkHandler.JoinLobby()
    local carCode = Helpers.GetResolvedCarCode(State.SelectedCar)
    local net = NetworkHandler.GetNetworkModule()

    -- 100% Direct Backend Remote (Instan, aman, tanpa ketergantungan UI/firesignal)
    if net and typeof(net.FireServer) == "function" then
        pcall(function()
            net:FireServer("Minigames", "Enter", carCode)
        end)
    else
        pcall(function()
            local remoteEvents = ReplicatedStorage:FindFirstChild("NetworkContainer")
                and ReplicatedStorage.NetworkContainer:FindFirstChild("RemoteEvents")
            local minigameRem = remoteEvents and remoteEvents:FindFirstChild("Minigames")
            if minigameRem then
                minigameRem:FireServer("Enter", carCode)
            end
        end)
    end
end

function NetworkHandler.LeaveLobby()
    local net = NetworkHandler.GetNetworkModule()

    -- 100% Direct Backend Remote
    if net and typeof(net.FireServer) == "function" then
        pcall(function()
            net:FireServer("Minigames", "Leave")
        end)
    else
        pcall(function()
            local remoteEvents = ReplicatedStorage:FindFirstChild("NetworkContainer")
                and ReplicatedStorage.NetworkContainer:FindFirstChild("RemoteEvents")
            local minigameRem = remoteEvents and remoteEvents:FindFirstChild("Minigames")
            if minigameRem then
                minigameRem:FireServer("Leave")
            end
        end)
    end
end

function NetworkHandler.BuyMinigameBox()
    -- 100% Backend Remote Box Buy
    if NetworkModule and typeof(NetworkModule.FireServer) == "function" then
        pcall(function()
            NetworkModule:FireServer("Box", "Buy", "Minigame")
        end)
    else
        pcall(function()
            local boxRem = ReplicatedStorage:FindFirstChild("NetworkContainer")
                and ReplicatedStorage.NetworkContainer:FindFirstChild("RemoteEvents")
                and ReplicatedStorage.NetworkContainer.RemoteEvents:FindFirstChild("Box")
            if boxRem then
                boxRem:FireServer("Buy", "Minigame")
            end
        end)
    end

    task.wait(0.5)
    Helpers.GetMinigamePoints()
end

function NetworkHandler.SetupHooks(context)
    -- Bersihkan hook sebelumnya agar tidak ada kebocoran memori (memory leak)
    if not _G.OneEight_MinigameHooks then _G.OneEight_MinigameHooks = {} end
    for _, conn in ipairs(_G.OneEight_MinigameHooks) do
        pcall(function() conn:Disconnect() end)
    end
    _G.OneEight_MinigameHooks = {}

    -- Hook listener untuk mendengarkan broadcast lobby countdown & status
    pcall(function()
        local remoteEvents = ReplicatedStorage:FindFirstChild("NetworkContainer") and ReplicatedStorage.NetworkContainer:FindFirstChild("RemoteEvents")
        if not remoteEvents then return end

        local uiStarter = remoteEvents:FindFirstChild("MinigameUIStarter")
        if uiStarter and uiStarter:IsA("RemoteEvent") then
            local conn = uiStarter.OnClientEvent:Connect(function(msg)
                if typeof(msg) == "string" then
                    State.LobbyStatusText = msg
                    if State.UpdateStatsUI then
                        State.UpdateStatsUI()
                    end
                end
            end)
            table.insert(_G.OneEight_MinigameHooks, conn)
        end
    end)
end



-- 5. AUTOFARM
--[[
    OneEight Hub - CDID Minigames Farm Loop Engine
    Handles the autonomous state machine for queueing, lobby management,
    in-game combat/yield tactics, and post-match reward handling.
--]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local AutoFarm = {}
local Utils = nil

local isRunning = false
local farmThread = nil

function AutoFarm.Init(stateInstance, helpersInstance, networkInstance, contextInstance, utilsInstance, configInstance)
    State = stateInstance
    Helpers = helpersInstance
    NetworkHandler = networkInstance
    Context = contextInstance
    Utils = utilsInstance
    Config = configInstance
end

function AutoFarm.IsPrivateServer()
    local isPrivate = false
    pcall(function()
        if game.PrivateServerId and game.PrivateServerId ~= "" then
            isPrivate = true
        end
    end)
    return isPrivate
end

function AutoFarm.FormatRupiah(amount)
    amount = tonumber(amount) or 0
    local formatted = tostring(math.floor(amount))
    while true do
        local k
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1.%2')
        if k == 0 then break end
    end
    return "Rp " .. formatted
end

function AutoFarm.Start()
    if isRunning then return end
    isRunning = true
    State.AutoFarmActive = true
    if not State.FarmStartTime then
        State.FarmStartTime = os.time()
    end

    -- Inisialisasi awal saldo dari backend asli game
    local initPts = Helpers.GetMinigamePoints()
    local initCash = Helpers.GetCash()
    if not State.StartingPoints then
        State.StartingPoints = initPts
    end
    if not State.StartingCash then
        State.StartingCash = initCash
    end

    farmThread = task.spawn(function()
        local lastArenaState = false
        local lastRound = 0
        local matchStartPoints = Helpers.GetMinigamePoints()
        local matchStartCash = Helpers.GetCash()

        while isRunning and State.AutoFarmActive do
            local inArena = Helpers.IsInArena()

            -- Transisi: Masuk ke dalam Arena (Match Baru Dimulai)
            if not lastArenaState and inArena then
                matchStartPoints = Helpers.GetMinigamePoints()
                matchStartCash = Helpers.GetCash()
                State.LastGameOverReason = nil
                State.CurrentTeam = Helpers.GetMyTeam()
            end

            -- Transisi: Keluar dari arena (Match Selesai atau Dibatalkan)
            if lastArenaState and not inArena then
                State.Phase = "Memeriksa Hasil..."
                if State.UpdateStatsUI then State.UpdateStatsUI() end

                task.wait(1.5) -- Beri jeda 1.5 detik agar server CDID mereplikasi data poin/kas ke client

                local currentPoints = Helpers.GetMinigamePoints()
                local currentCash = Helpers.GetCash()
                local deltaPoints = currentPoints - matchStartPoints
                local deltaCash = currentCash - matchStartCash

                -- Cek apakah ada penambahan poin resmi dari game
                if deltaPoints > 0 then
                    State.TotalMatches = State.TotalMatches + 1
                    local isPrivate = AutoFarm.IsPrivateServer()
                    local winThreshold = isPrivate and Config.Rewards.Private.Win.Points or Config.Rewards.Public.Win.Points

                    if deltaPoints >= winThreshold then
                        State.TotalWins = State.TotalWins + 1
                        State.LastMatchResult = string.format("Menang (+%d Poin)", deltaPoints)
                    else
                        State.TotalLosses = State.TotalLosses + 1
                        State.LastMatchResult = string.format("Kalah (+%d Poin)", deltaPoints)
                    end
                else
                    -- Jika deltaPoints == 0, berarti game batal / game over tanpa reward
                    if State.LastGameOverReason then
                        State.LastMatchResult = string.format("Batal: %s", State.LastGameOverReason)
                    else
                        State.LastMatchResult = "Dibatalkan / Tanpa Poin"
                    end
                end

                -- Sinkronkan Total Earned secara presisi dari database asli
                State.PointsEarned = math.max(0, currentPoints - (State.StartingPoints or currentPoints))
                State.CashEarned = math.max(0, currentCash - (State.StartingCash or currentCash))
                State.PointsEarnedText = "+" .. tostring(State.PointsEarned) .. " Poin"
                State.CashEarnedText = AutoFarm.FormatRupiah(State.CashEarned)
                State.MatchRecordText = string.format("%dW / %dL", State.TotalWins, State.TotalLosses)

                -- Hitung Avg/h stabil (hanya saat match selesai dan poin bertambah, bukan turun tiap detik)
                if State.FarmStartTime and State.PointsEarned and State.PointsEarned > 0 then
                    local elapsed = math.max(1, os.time() - State.FarmStartTime)
                    State.AvgPointsPerHour = math.floor((State.PointsEarned / elapsed) * 3600)
                end

                -- Periksa Live Points & Auto Beli Box
                if State.AutoOpenBox and State.CurrentPoints >= Config.BoxCost then
                    NetworkHandler.BuyMinigameBox()
                    State.BoxesOpened = State.BoxesOpened + 1
                end

                State.Phase = "Reset Lobby"
                if State.UpdateStatsUI then State.UpdateStatsUI() end

                State.LastGameOverReason = nil
                task.wait(Config.PostMatchWait or 3.0)
            end

            lastArenaState = inArena

            -- CASE A: Sedang di dalam Arena Minigames (Sumo Match)
            if inArena then
                local currentRound, maxRounds = Helpers.GetRoundInfo()
                State.CurrentRound = currentRound
                State.MaxRounds = maxRounds

                local matchStatus = Helpers.GetGameMatchStatus()
                if matchStatus and matchStatus.NotifTitle and matchStatus.NotifTitle ~= "" then
                    if string.find(string.upper(matchStatus.NotifTitle), "GAME OVER") then
                        State.LastGameOverReason = (matchStatus.NotifDesc ~= "" and matchStatus.NotifDesc) or "4 players left"
                        State.Phase = string.format("Game Over (%s)", State.LastGameOverReason)
                    end
                end

                if State.Role == "Loser" then
                    -- Akun Bot: Langsung turun dari mobil untuk mengalah instan
                    if currentRound ~= lastRound then
                        lastRound = currentRound
                        State.Phase = string.format("R%d (Keluar Mobil)", currentRound)
                        if State.UpdateStatsUI then State.UpdateStatsUI() end

                        task.wait(0.5)
                        Helpers.YieldRound()
                    else
                        State.Phase = string.format("R%d (Bot Gugur)", currentRound)
                        Helpers.ExitVehicle()
                    end
                else
                    -- Akun Utama: Murni diam alami tanpa treatment apapun
                    lastRound = currentRound
                    local bWins = State.BlueScore or 0
                    local rWins = State.RedScore or 0
                    if not State.LastGameOverReason then
                        State.Phase = string.format("R%d [B:%d R:%d] Menang", currentRound, bWins, rWins)
                    end
                end

                if State.UpdateStatsUI then State.UpdateStatsUI() end
                task.wait(Config.RoundCheckInterval or 0.5)

            -- CASE B: Berada di Luar Arena (Kota / Spawn)
            else
                lastRound = 0
                local inLobby = Helpers.IsInLobby()

                if not inLobby then
                    State.Phase = "Antre Lobby"
                    if State.UpdateStatsUI then State.UpdateStatsUI() end

                    NetworkHandler.JoinLobby()
                    task.wait(Config.LobbyCheckInterval or 1.5)
                else
                    local lobbyStatus = Helpers.GetLobbyStatus()
                    local pCount = Helpers.GetLobbyPlayerCount()
                    State.LobbyPlayersCount = pCount

                    if lobbyStatus ~= "-" and lobbyStatus ~= "" then
                        State.LobbyStatusText = lobbyStatus
                    end

                    State.Phase = string.format("Lobby (%d/6)", pCount)
                    if State.UpdateStatsUI then State.UpdateStatsUI() end
                    task.wait(1.0)
                end
            end
        end

        isRunning = false
        State.Phase = "Standby"
        if State.UpdateStatsUI then State.UpdateStatsUI() end
    end)
end

function AutoFarm.Stop()
    isRunning = false
    State.AutoFarmActive = false
    State.Phase = "Standby"

    local GpuSaver = (Context and Context.GpuSaver) or _G.OneEight_SharedGpuSaver
    if GpuSaver and typeof(GpuSaver.OnFarmToggle) == "function" then
        GpuSaver.OnFarmToggle(false)
    end

    if farmThread then
        pcall(function() task.cancel(farmThread) end)
        farmThread = nil
    end

    if State.UpdateStatsUI then
        State.UpdateStatsUI()
    end
end



-- 6. PUBLIC INTERFACE
function MinigameJob.Init(coreContext)
    Context = coreContext
    Helpers.Init(State, Config)
    NetworkHandler.Init(State, Helpers, Config)
    AutoFarm.Init(State, Helpers, NetworkHandler, coreContext, nil, Config)
    State.UpdateStatsUI = function()
        if Context and Context.SendPacket then
            pcall(function()
                Context.SendPacket("TELEMETRY", {
                    minigame = {
                        phase = State.Phase,
                        role = State.Role,
                        points = State.CurrentPoints,
                        pointsEarned = State.PointsEarned,
                        cashEarned = State.CashEarned,
                        wins = State.TotalWins,
                        losses = State.TotalLosses,
                        boxes = State.BoxesOpened,
                        round = State.CurrentRound,
                        maxRounds = State.MaxRounds,
                        lastResult = State.LastMatchResult
                    }
                })
            end)
        end
    end
    Helpers.GetMinigamePoints()
    Helpers.GetCash()
    print("[OE-External CDID] Modul Minigames Sumo Berhasil Diinisialisasi")
end

function MinigameJob.Start(options)
    if options then
        if options.role then State.Role = options.role end
        if options.autoOpenBox ~= nil then State.AutoOpenBox = options.autoOpenBox end
        if options.selectedCar then State.SelectedCar = options.selectedCar end
    end
    AutoFarm.Start()
    if Context and Context.SendLog then
        Context.SendLog(string.format("Minigames Sumo Farm Dimulai (Role: %s, Mobil: %s)", State.Role, State.SelectedCar), "SUCCESS")
    end
end

function MinigameJob.Stop()
    AutoFarm.Stop()
    pcall(function() NetworkHandler.LeaveLobby() end)
    if Context and Context.SendLog then
        Context.SendLog("Minigames Sumo Farm Dihentikan.", "WARN")
    end
end

function MinigameJob.BuyBox()
    NetworkHandler.BuyMinigameBox()
    State.BoxesOpened = State.BoxesOpened + 1
    if Context and Context.SendLog then
        Context.SendLog("Membeli Minigame Box (-20 Poin)", "SUCCESS")
    end
end

function MinigameJob.GetState()
    Helpers.GetMinigamePoints()
    Helpers.GetCash()
    return State
end

function MinigameJob.GetCars()
    return Helpers.GetOwnedCars()
end

return MinigameJob
end

Modules["games/cdid/jobs/kanji_jawa"] = function()
--[[
    OneEight External Hub - Cafe Kanji Jawa (Barista) Farm Module
    Ported directly from Official OneEight Hub Cafe Kanji Jawa Engine (sourcelua-dev)
    100% Faithful Architecture:
    - Map: CDID Jakarta (14005966837)
    - ActionDelay: 0.8s natural human-like pacing (Anti-Ruined & Anti-Detection)
    - Jitter: ±0.2 studs offset (Anti-Robot coordinate detection)
    - Dynamic Station Dispatcher (CupRack, Brewer, Milk, Flavour, Ice, Water, Tea, Boba, Matcha, etc.)
    - Smart Dialog & Phone Answering (Automatic tutorial phone handler)
    - Auto Trash Ruined Cups
    - Complete RemoteEvent Hooking & Telemetry
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local KanjiJawaJob = {}
KanjiJawaJob.JobName = "Kanji Jiwa (Barista)"
KanjiJawaJob.PlaceIds = { 14005966837 } -- CDID Jakarta

local Context = nil
local isRunning = false
local farmThread = nil
local CurrentHookConn = nil

-- ==============================================================================
-- 1. CONFIGURATION
-- ==============================================================================
local Config = {
    JobName = "Kanji Jiwa (Barista)",
    PlaceIds = { 14005966837 },
    KitchenFloorY = 22.9,
    CafeCenter = Vector3.new(-32.5, 22.9, 8420.0),

    -- Action Timings
    ActionDelay = 0.8,
    StepWait = 1.2,
    BrewExtractionWait = 5.0,
    PickWait = 0.8,
    LoopWait = 1.2,

    -- Jarak Berdiri dari Peralatan / Customer
    StandOffset = 3.8,
    DistanceTolerance = 4.0,

    -- Mapping Step Minuman ke Nama Part Stasiun
    StepToStation = {
        ["Cup"] = "CupRack",
        ["Beans"] = "BeanHopper",
        ["LoadBeans"] = "Brewer",
        ["Brew"] = "Brewer",
        ["Pour"] = "Brewer",
        ["Milk"] = "Milk",
        ["Flavour"] = "FlavourBottle",
        ["Ice"] = "IceMaker",
        ["Water"] = "WaterTap",
        ["TeaBag"] = "TeaBox",
        ["Boba"] = "BobaPot",
        ["MatchaPowder"] = "MatchaJar",
        ["ChocolatePowder"] = "ChocolateJar",
        ["LemonSlice"] = "LemonBoard",
        ["Carbonate"] = "Carbonator",
        ["Cream"] = "CreamDispenser",
        ["Foam"] = "Steamer",
        ["Trash"] = "Trash"
    }
}

-- ==============================================================================
-- 2. STATE
-- ==============================================================================
local State = {
    IsFarming = false,
    AutoFarmActive = false,
    IsBusy = false,
    Phase = "Standby", -- "Standby", "Mencari Customer", "Ambil Pesanan", "Meracik", "Menyajikan Minuman"

    -- Order Tracking
    CurrentOrder = {
        OrderId = nil,
        MenuId = nil,
        Flavour = nil,
        NextStep = nil,
        NextStation = nil,
        Ruined = false,
        Done = false,
        StepCount = 0,
        DoneCount = 0
    },

    -- Counters & Statistics
    TotalOrders = 0,
    RuinedOrders = 0,
    TotalEarned = 0,
    LastGaji = 0,
    CurrentCash = 0,
    StartCash = 0,

    -- Financial Strings
    LastGajiText = "Rp 0",
    TotalEarnedText = "Rp 0",
    AvgPerHourText = "Rp 0/jam",
    CurrentCustomerName = "-",

    FarmStartTime = nil,
    AvgPerHour = 0,
    LastServedCustomer = nil,
    LastServedTime = 0,
    LastPickPromptKind = nil,
    LastPickPromptChoices = nil,
    BrewDuration = 5.2,
    BrewStartTime = 0
}

-- ==============================================================================
-- 3. HELPERS
-- ==============================================================================
local Helpers = {}

function Helpers.GetValidHumanoid()
    local char = LocalPlayer.Character
    if not char then return nil, nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hum and hrp and hum.Health > 0 then
        return hum, hrp
    end
    return nil, nil
end

function Helpers.FormatRupiah(amount)
    amount = tonumber(amount) or 0
    local formatted = tostring(math.floor(math.abs(amount))):reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")
    return (amount < 0 and "-Rp " or "Rp ") .. formatted
end

local cachedReplica = nil
local function GetReplica()
    if cachedReplica and cachedReplica.Data then
        return cachedReplica
    end
    pcall(function()
        local dataRep = require(ReplicatedStorage.Services.DataReplication)
        local ups = debug.getupvalues(dataRep.GetCash)
        if ups and ups[1] then
            cachedReplica = ups[1]
        end
    end)
    return cachedReplica
end

function Helpers.GetCash()
    local cash = nil
    pcall(function()
        local replica = GetReplica()
        if replica and replica.Data and replica.Data.Inventory and replica.Data.Inventory.Cash then
            cash = tonumber(replica.Data.Inventory.Cash)
        end
    end)
    if cash ~= nil then
        State.CurrentCash = cash
        return cash
    end

    pcall(function()
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        local mainGui = pGui and pGui:FindFirstChild("MainScreen") or (pGui and pGui:FindFirstChild("HUD"))
        if mainGui then
            local cashLbl = mainGui:FindFirstChild("Cash", true) or mainGui:FindFirstChild("Money", true)
            if cashLbl and cashLbl:IsA("TextLabel") then
                local num = cashLbl.Text:gsub("%D", "")
                if num ~= "" then
                    cash = tonumber(num)
                end
            end
        end
    end)
    if cash ~= nil then
        State.CurrentCash = cash
        return cash
    end
    return State.CurrentCash or 0
end

function Helpers.RestoreCamera()
    pcall(function()
        -- 1. Resmi Abort / Selesaikan NPC Dialog & Cutscene Cinematic
        local rs = game:GetService("ReplicatedStorage")
        local net = rs:FindFirstChild("NetworkContainer") and rs.NetworkContainer:FindFirstChild("RemoteEvents")
        local remote = net and net:FindFirstChild("NpcDialog")
        if remote then
            pcall(function()
                remote:FireServer("Finish", nil)
            end)
            if typeof(getconnections) == "function" then
                local conns = getconnections(remote.OnClientEvent)
                if conns and conns[1] and conns[1].Function then
                    local ups = typeof(getupvalues) == "function" and getupvalues(conns[1].Function)
                    if ups and typeof(ups[2]) == "function" then
                        pcall(ups[2]) -- Panggil fungsi abort resmi di NpcDialog.LocalScript
                    end
                end
            end
        end

        -- 2. Kembalikan CameraType, CameraSubject, FOV & matikan Tween kamera
        local camera = Workspace.CurrentCamera
        local hum, hrp = Helpers.GetValidHumanoid()
        if camera then
            pcall(function()
                camera.CameraType = Enum.CameraType.Custom
                if hum then
                    camera.CameraSubject = hum
                end
                camera.FieldOfView = 70
                if hrp then
                    camera.CFrame = CFrame.new(hrp.Position - hrp.CFrame.LookVector * 10 + Vector3.new(0, 3.5, 0), hrp.Position)
                end
            end)
        end

        -- 3. Pulihkan Kontrol Karakter PlayerModule jika sempat terkunci dialog
        pcall(function()
            local pScripts = LocalPlayer:FindFirstChild("PlayerScripts")
            local pModule = pScripts and pScripts:FindFirstChild("PlayerModule")
            if pModule then
                local controls = require(pModule):GetControls()
                if controls and not controls:IsEnabled() then
                    controls:Enable()
                end
            end
        end)

        -- 4. Bersihkan Attribute Dialog Player
        LocalPlayer:SetAttribute("NpcDialogOpen", false)
        LocalPlayer:SetAttribute("HidePrompt", false)
    end)
end

function Helpers.CleanAllUIs()
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")

    -- 1. Reset attribute dialog player
    pcall(function()
        if LocalPlayer:GetAttribute("NpcDialogOpen") then
            LocalPlayer:SetAttribute("NpcDialogOpen", false)
        end
        if LocalPlayer:GetAttribute("HidePrompt") then
            LocalPlayer:SetAttribute("HidePrompt", false)
        end
    end)

    if pGui then
        -- 2. ChoicePicker
        pcall(function()
            local choicePicker = pGui:FindFirstChild("Job") and pGui.Job:FindFirstChild("ChoicePicker")
            if choicePicker and choicePicker.Visible then
                choicePicker.Visible = false
            end
        end)

        -- 3. BrewMinigame
        pcall(function()
            local brewMinigame = pGui:FindFirstChild("Job") and pGui.Job:FindFirstChild("BrewMinigame")
            if brewMinigame and brewMinigame.Visible then
                brewMinigame.Visible = false
            end
        end)

        -- 4. NpcDialog & Letterbox
        pcall(function()
            local npcDialog = pGui:FindFirstChild("NpcDialog")
            if npcDialog then
                if npcDialog.Enabled then npcDialog.Enabled = false end
                local top = npcDialog:FindFirstChild("LetterboxTop")
                local btm = npcDialog:FindFirstChild("LetterboxBottom")
                if top and top.Visible then top.Visible = false end
                if btm and btm.Visible then btm.Visible = false end
            end
        end)
    end

    -- 5. Restore Camera & Controls secara menyeluruh
    Helpers.RestoreCamera()
end

function Helpers.StandAt(standPos, lookTargetPos)
    local hum, hrp = Helpers.GetValidHumanoid()
    if not hrp then return end

    local elevatedY = standPos.Y + 1.5
    local lookTargetFlat = Vector3.new(lookTargetPos.X, elevatedY, lookTargetPos.Z)
    local targetCF = CFrame.lookAt(Vector3.new(standPos.X, elevatedY, standPos.Z), lookTargetFlat)

    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    hrp.CFrame = targetCF
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    task.wait(Config.ActionDelay or 0.8)
end

function Helpers.MoveToStation(stationName)
    local barista = Workspace:FindFirstChild("Barista")
    local stations = barista and barista:FindFirstChild("Stations")
    if not stations then return false end

    local s = stations:FindFirstChild(stationName)
    if not s then return false end

    local p = s.Position
    local standX = p.X
    local standZ = p.Z
    local offset = Config.StandOffset or 3.8

    -- Jitter natural ±0.2 studs
    local jitterX = (math.random(-20, 20) / 100)
    local jitterZ = (math.random(-20, 20) / 100)

    if p.X < -38 then
        standX = p.X + offset + jitterX
        standZ = p.Z + jitterZ
    elseif p.Z <= 8420 then
        standX = p.X + jitterX
        standZ = p.Z + offset + jitterZ
    else
        standX = p.X + jitterX
        standZ = p.Z - offset + jitterZ
    end

    local floorY = Config.KitchenFloorY or 22.9
    local standPos = Vector3.new(standX, floorY, standZ)
    Helpers.StandAt(standPos, p)
    return true
end

function Helpers.MoveToCustomerCounter(counterCustomer)
    if not counterCustomer or not counterCustomer:FindFirstChild("HumanoidRootPart") then return end
    local custPos = counterCustomer.HumanoidRootPart.Position

    local floorY = Config.KitchenFloorY or 22.9
    local offset = Config.StandOffset or 3.8
    local jitterZ = (math.random(-20, 20) / 100)
    local standX = custPos.X + offset
    local standZ = custPos.Z + jitterZ
    local standPos = Vector3.new(standX, floorY, standZ)
    Helpers.StandAt(standPos, custPos)
end

function Helpers.TeleportToCafe()
    local barista = Workspace:FindFirstChild("Barista")
    local npc = barista and barista:FindFirstChild("NPC_BARISTA_MANAGER")
    local hum, hrp = Helpers.GetValidHumanoid()
    if not hrp then return end

    pcall(function()
        if hum then hum.Sit = false end
        hrp.Anchored = true
        if npc and npc:FindFirstChild("Head") then
            hrp.CFrame = CFrame.new(npc.Head.Position + Vector3.new(0, 3.5, -3), npc.Head.Position)
        else
            hrp.CFrame = CFrame.new(-13.5, 26.5, 8448.0)
        end
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
    task.wait(0.35)
    pcall(function()
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        hrp.Anchored = false
    end)
    Helpers.RestoreCamera()
end

-- ==============================================================================
-- 4. NETWORK & REMOTES
-- ==============================================================================
local NetworkHandler = {}
local Net = nil
local BaristaRemote = nil
local NpcDialogRemote = nil

function NetworkHandler.GetBaristaRemote(timeout)
    if BaristaRemote and BaristaRemote.Parent then
        return BaristaRemote
    end

    local netContainer = ReplicatedStorage:FindFirstChild("NetworkContainer")
    local remotes = netContainer and netContainer:FindFirstChild("RemoteEvents")
    if not remotes and timeout and timeout > 0 then
        netContainer = ReplicatedStorage:WaitForChild("NetworkContainer", timeout)
        remotes = netContainer and netContainer:WaitForChild("RemoteEvents", timeout)
    end

    if remotes then
        local baristaList = {}
        for _, child in ipairs(remotes:GetChildren()) do
            if child.Name == "Barista" and child:IsA("RemoteEvent") then
                table.insert(baristaList, child)
            end
        end

        if #baristaList > 1 then
            BaristaRemote = baristaList[#baristaList]
            pcall(function() baristaList[1]:Destroy() end)
        elseif #baristaList == 1 then
            BaristaRemote = baristaList[1]
        elseif timeout and timeout > 0 then
            BaristaRemote = remotes:WaitForChild("Barista", timeout)
        end
    end

    return BaristaRemote
end

function NetworkHandler.Init()
    pcall(function()
        local modules = ReplicatedStorage:FindFirstChild("Modules")
        if modules and modules:FindFirstChild("Network") then
            Net = require(modules.Network)
        end

        NetworkHandler.GetBaristaRemote(2)

        local netContainer = ReplicatedStorage:FindFirstChild("NetworkContainer") or ReplicatedStorage:WaitForChild("NetworkContainer", 5)
        local remotes = netContainer and (netContainer:FindFirstChild("RemoteEvents") or netContainer:WaitForChild("RemoteEvents", 5))
        if remotes then
            NpcDialogRemote = remotes:FindFirstChild("NpcDialog") or remotes:WaitForChild("NpcDialog", 3)
        end
    end)
end

function NetworkHandler.SetupHooks()
    local remote = NetworkHandler.GetBaristaRemote(5)
    if not remote then return false end

    if CurrentHookConn and CurrentHookConn.Connected then
        return true
    end

    CurrentHookConn = remote.OnClientEvent:Connect(function(action, ...)
        local args = {...}
        if action == "OrderTaken" then
            State.CurrentOrder.OrderId = args[1]
            State.CurrentOrder.MenuId = args[2]
            State.CurrentOrder.Flavour = args[3]
            if Context and Context.SendLog then
                Context.SendLog(string.format("[Barista] Pesanan diambil: %s (%s)", tostring(args[2]), tostring(args[3] or "Standard")), "INFO")
            end

        elseif action == "CupState" then
            local s = args[1]
            if s then
                State.CurrentOrder.NextStation = s.nextStation
                State.CurrentOrder.NextStep = s.nextStep
                State.CurrentOrder.Ruined = s.ruined or false
                State.CurrentOrder.DoneCount = s.doneCount or 0
                State.CurrentOrder.StepCount = s.stepCount or 0
                if not s.nextStep and (s.doneCount and s.stepCount and s.doneCount >= s.stepCount) then
                    State.CurrentOrder.Done = true
                end
            else
                State.CurrentOrder.NextStep = nil
                State.CurrentOrder.NextStation = nil
                State.CurrentOrder.Ruined = false
                State.CurrentOrder.Done = false
            end

        elseif action == "PickPrompt" then
            local pickKind = args[1]
            local choices = args[2]
            State.LastPickPromptKind = pickKind
            State.LastPickPromptChoices = choices
            task.spawn(function()
                task.wait(0.15)
                if pickKind == "Menu" then
                    local menu = State.CurrentOrder.MenuId
                    if not menu or menu == "" or (choices and not table.find(choices, menu)) then
                        menu = (choices and choices[1]) or "KopiHitam"
                    end
                    NetworkHandler.FirePick("Menu", menu)
                elseif pickKind == "Flavour" then
                    local flav = State.CurrentOrder.Flavour
                    if not flav or flav == "" or (choices and not table.find(choices, flav)) then
                        flav = (choices and choices[1]) or "Vanilla"
                    end
                    NetworkHandler.FirePick("Flavour", flav)
                end
                Helpers.CleanAllUIs()
            end)

        elseif action == "BrewStart" then
            State.BrewDuration = tonumber(args[1]) or 5.2
            State.BrewStartTime = os.clock()

        elseif action == "OrderDone" then
            local orderId, earnedSalary, bonus, isSuccess = args[1], args[2], args[3], args[4]
            State.TotalOrders = State.TotalOrders + 1
            local salaryNum = tonumber(earnedSalary) or 0
            State.LastGaji = salaryNum
            State.TotalEarned = State.TotalEarned + salaryNum
            State.LastGajiText = Helpers.FormatRupiah(salaryNum)
            State.TotalEarnedText = Helpers.FormatRupiah(State.TotalEarned)

            if State.FarmStartTime and State.TotalEarned > 0 then
                local elapsedHours = math.max((os.clock() - State.FarmStartTime) / 3600, 0.005)
                local avgPerHour = math.floor(State.TotalEarned / elapsedHours)
                State.AvgPerHour = avgPerHour
                State.AvgPerHourText = Helpers.FormatRupiah(avgPerHour) .. "/jam"
            end

            Helpers.GetCash()

            if Context and Context.SendLog then
                Context.SendLog(string.format("[Barista] Minuman Selesai! Gaji: %s (Total Pesanan: %d)", Helpers.FormatRupiah(salaryNum), State.TotalOrders), "SUCCESS")
            end

            pcall(function()
                if Context and Context.SendPacket then
                    Context.SendPacket("TELEMETRY", {
                        barista = {
                            isFarming = State.IsFarming,
                            phase = State.Phase,
                            totalOrders = State.TotalOrders,
                            ruinedOrders = State.RuinedOrders,
                            lastGaji = State.LastGaji,
                            totalEarned = State.TotalEarned,
                            avgPerHour = State.AvgPerHour
                        }
                    })
                end
            end)

        elseif action == "OrderRejected" then
            warn("⚠️ [Kanji Jawa] Pesanan ditolak server:", args[1], args[2])
            if Context and Context.SendLog then
                Context.SendLog(string.format("[Barista] Pesanan ditolak: %s", tostring(args[1])), "WARN")
            end
        end
    end)

    return true
end

function NetworkHandler.CheckAndAnswerTelephone()
    local bGui = LocalPlayer.PlayerGui:FindFirstChild("Job") and LocalPlayer.PlayerGui.Job:FindFirstChild("Barista")
    local phoneRing = bGui and bGui:FindFirstChild("Sounds") and bGui.Sounds:FindFirstChild("PhoneRing")

    local phoneFolder = Workspace:FindFirstChild("NEW_JOB")
    if phoneFolder then
        phoneFolder = phoneFolder:FindFirstChild("Cafe")
        if phoneFolder then
            phoneFolder = phoneFolder:FindFirstChild("Cafe_Kanji_Jawa")
            if phoneFolder then
                phoneFolder = phoneFolder:FindFirstChild("Telphone")
            end
        end
    end

    local phonePrompt = phoneFolder and phoneFolder:FindFirstChild("Telephone") and phoneFolder.Telephone:FindFirstChild("BaristaPhonePrompt")
    local isRinging = (phoneRing and phoneRing.IsPlaying) or (phonePrompt and phonePrompt.Enabled)

    if isRinging then
        if phoneFolder and phoneFolder:FindFirstChild("Telephone") then
            local telPart = phoneFolder.Telephone
            Helpers.StandAt(telPart.Position + Vector3.new(0, 0, 2), telPart.Position)
            task.wait(0.3)
        end

        -- Selesaikan tutorial langsung ke server agar telepon tidak perlu berdering lagi
        local remote = NetworkHandler.GetBaristaRemote(3)
        if remote then
            pcall(function()
                remote:FireServer("TutorialDone")
            end)
        end

        if phonePrompt and phonePrompt.Enabled then
            pcall(function()
                fireproximityprompt(phonePrompt)
            end)
            task.wait(0.3)
        end

        if phoneRing and phoneRing.IsPlaying then
            pcall(function() phoneRing:Stop() end)
        end

        task.wait(0.3)
        Helpers.RestoreCamera()
        Helpers.CleanAllUIs()
        return true
    end
    return false
end

function NetworkHandler.EnsureBaristaJob()
    local bGui = LocalPlayer.PlayerGui:FindFirstChild("Job") and LocalPlayer.PlayerGui.Job:FindFirstChild("Barista")
    if bGui and bGui.Visible then
        NetworkHandler.GetBaristaRemote(3)
        NetworkHandler.SetupHooks()
        NetworkHandler.CheckAndAnswerTelephone()
        return true
    end

    local barista = Workspace:FindFirstChild("Barista")
    local npc = barista and barista:FindFirstChild("NPC_BARISTA_MANAGER")
    local prompt = npc and npc:FindFirstChild("Head") and npc.Head:FindFirstChild("DialogPrompt")
    if not prompt then return false end

    Helpers.StandAt(npc.Head.Position + Vector3.new(0, 0, -3), npc.Head.Position)
    task.wait(0.3)

    local dialogConn
    if NpcDialogRemote then
        dialogConn = NpcDialogRemote.OnClientEvent:Connect(function(action)
            if action == "Start" then
                task.spawn(function()
                    task.wait(0.2)
                    NpcDialogRemote:FireServer("Finish", nil)
                end)
            end
        end)
    end

    fireproximityprompt(prompt)
    task.wait(2.5)

    if dialogConn then dialogConn:Disconnect() end
    LocalPlayer:SetAttribute("NpcDialogOpen", false)
    LocalPlayer:SetAttribute("HidePrompt", false)
    Helpers.CleanAllUIs()

    local active = LocalPlayer.PlayerGui:FindFirstChild("Job") and LocalPlayer.PlayerGui.Job:FindFirstChild("Barista") and LocalPlayer.PlayerGui.Job.Barista.Visible
    if active then
        NetworkHandler.GetBaristaRemote(5)
        NetworkHandler.SetupHooks()
        NetworkHandler.CheckAndAnswerTelephone()
    end
    return active or false
end

function NetworkHandler.FireTakeOrder(orderId)
    local remote = NetworkHandler.GetBaristaRemote()
    if Net then
        Net:FireServer("Barista", "TakeOrder", orderId)
    elseif remote then
        remote:FireServer("TakeOrder", orderId)
    end
end

function NetworkHandler.FireStation(stationName)
    local remote = NetworkHandler.GetBaristaRemote()
    if Net then
        Net:FireServer("Barista", "Station", stationName)
    elseif remote then
        remote:FireServer("Station", stationName)
    end
end

function NetworkHandler.FirePick(kind, value)
    local remote = NetworkHandler.GetBaristaRemote()
    if Net then
        Net:FireServer("Barista", "Pick", kind, value)
    elseif remote then
        remote:FireServer("Pick", kind, value)
    end
end

function NetworkHandler.FireBrewResult(score)
    score = score or 1
    local remote = NetworkHandler.GetBaristaRemote()
    if Net then
        Net:FireServer("Barista", "BrewResult", score)
    elseif remote then
        remote:FireServer("BrewResult", score)
    end
end

function NetworkHandler.FireServe(orderId)
    local remote = NetworkHandler.GetBaristaRemote()
    if Net then
        Net:FireServer("Barista", "Serve", orderId)
    elseif remote then
        remote:FireServer("Serve", orderId)
    end
end

function NetworkHandler.FireTrash()
    local remote = NetworkHandler.GetBaristaRemote()
    if Net then
        Net:FireServer("Barista", "Station", "Trash")
    elseif remote then
        remote:FireServer("Station", "Trash")
    end
end

-- ==============================================================================
-- 5. AUTOFARM CORE ENGINE
-- ==============================================================================
local function IsAlive()
    return isRunning and State.IsFarming
end

local AutoFarm = {}

function AutoFarm.Start()
    if isRunning or State.IsFarming then return end
    isRunning = true
    State.IsFarming = true
    State.AutoFarmActive = true
    State.IsBusy = false
    if not State.FarmStartTime then
        State.FarmStartTime = os.clock()
    end

    local initCash = Helpers.GetCash()
    if not State.StartCash or State.StartCash == 0 then
        State.StartCash = initCash
    end

    farmThread = task.spawn(function()
        -- 1. Teleport ke kafe jika posisi player jauh dari kafe
        local _, hrp = Helpers.GetValidHumanoid()
        if hrp and (hrp.Position - Config.CafeCenter).Magnitude > 75 then
            if Context and Context.SendLog then
                Context.SendLog("Menuju lokasi Kanji Jiwa...", "INFO")
            end
            Helpers.TeleportToCafe()
            task.wait(1.5)
        end

        -- 2. Pastikan Job Barista Aktif
        if not NetworkHandler.EnsureBaristaJob() then
            if Context and Context.SendLog then
                Context.SendLog("Gagal mengaktifkan job Barista (Manager NPC tidak merespons)", "WARN")
            end
            isRunning = false
            State.IsFarming = false
            State.AutoFarmActive = false
            return
        end

        NetworkHandler.SetupHooks()
        Helpers.CleanAllUIs()

        -- Cek sisa gelas / pesanan aktif sebelum farming dimulai
        pcall(function()
            local bGui = LocalPlayer.PlayerGui:FindFirstChild("Job") and LocalPlayer.PlayerGui.Job:FindFirstChild("Barista")
            if not bGui then return end

            local hint = bGui:FindFirstChild("Hint") and bGui.Hint.Text or ""
            if hint:find("Rusak") or hint:find("Tong Sampah") then
                Helpers.MoveToStation("Trash")
                task.wait(Config.ActionDelay or 0.8)
                NetworkHandler.FireTrash()
                task.wait(1.5)
                Helpers.CleanAllUIs()
            elseif hint:find("Antar") or hint:find("serah") then
                State.CurrentOrder.Done = true
            end

            local ordersFrame = bGui:FindFirstChild("Orders")
            if ordersFrame and not State.CurrentOrder.OrderId then
                for _, row in ipairs(ordersFrame:GetChildren()) do
                    if row:IsA("Frame") and row:FindFirstChild("Menu") and row:FindFirstChild("Number") then
                        local numStr = row.Number.Text:gsub("%D", "")
                        local menuStr = row.Menu.Text:gsub("^%s*(.-)%s*$", "%1")
                        if menuStr ~= "" and tonumber(numStr) then
                            State.CurrentOrder.OrderId = tonumber(numStr)
                            State.CurrentOrder.MenuId = menuStr
                            break
                        end
                    end
                end
            end
        end)

        -- Background Watchdog: Bersihkan UI liar
        task.spawn(function()
            while IsAlive() do
                Helpers.CleanAllUIs()
                task.wait(0.5)
            end
            Helpers.CleanAllUIs()
        end)

        -- 3. Loop Autofarm Utama
        while IsAlive() do
            Helpers.CleanAllUIs()
            State.Phase = "Mencari Customer"

            -- Cari customer di meja kasir counter yang prompt-nya sudah aktif
            local baristaCust = Workspace:FindFirstChild("BaristaCustomers")
            local counterCustomer = nil
            local targetPrompt = nil
            local counterPos = Vector3.new(-36.4, 24.3, 8419.2)

            if baristaCust then
                for _, cust in ipairs(baristaCust:GetChildren()) do
                    if cust:IsA("Model") and cust:FindFirstChild("HumanoidRootPart") then
                        if cust == State.LastServedCustomer and (os.clock() - (State.LastServedTime or 0) < 6.0) then
                            continue
                        end
                        local dX = cust.HumanoidRootPart.Position.X - counterPos.X
                        local dZ = cust.HumanoidRootPart.Position.Z - counterPos.Z
                        local flatDist = math.sqrt(dX * dX + dZ * dZ)
                        if flatDist < 8.0 then
                            local prompt = cust:FindFirstChildWhichIsA("ProximityPrompt", true)
                            if prompt and prompt.Enabled then
                                counterCustomer = cust
                                targetPrompt = prompt
                                break
                            elseif not counterCustomer then
                                counterCustomer = cust
                                targetPrompt = prompt
                            end
                        end
                    end
                end
            end

            if not counterCustomer then
                -- Angkat telepon tutorial jika berdering
                NetworkHandler.CheckAndAnswerTelephone()

                -- Standby di balik meja kasir counter
                local waitPos = Vector3.new(-32.5, Config.KitchenFloorY or 22.9, 8420.0)
                local lookPos = Vector3.new(-36.0, Config.KitchenFloorY or 22.9, 8420.0)
                local _, hrpNow = Helpers.GetValidHumanoid()
                if hrpNow and (hrpNow.Position - waitPos).Magnitude > 3.0 then
                    Helpers.StandAt(waitPos, lookPos)
                end
                task.wait(1.0)
                continue
            end

            State.CurrentCustomerName = counterCustomer.Name

            -- Berdiri di balik kasir menghadap customer
            Helpers.MoveToCustomerCounter(counterCustomer)

            -- Tunggu sampai customer benar-benar tiba di meja kasir
            local promptWaitT0 = os.clock()
            while counterCustomer.Parent and (os.clock() - promptWaitT0 < 12.0) and IsAlive() do
                targetPrompt = counterCustomer:FindFirstChildWhichIsA("ProximityPrompt", true)
                if targetPrompt and targetPrompt.Enabled then
                    break
                end
                task.wait(0.25)
            end

            if not targetPrompt or not targetPrompt.Enabled then
                task.wait(0.5)
                continue
            end

            -- A. Jika minuman sudah selesai (State.CurrentOrder.Done) -> Langsung Sajikan
            if State.CurrentOrder.Done then
                State.Phase = "Menyajikan Minuman"
                fireproximityprompt(targetPrompt)
                task.wait(Config.ActionDelay or 0.8)

                State.LastServedCustomer = counterCustomer
                State.LastServedTime = os.clock()

                State.CurrentOrder.OrderId = nil
                State.CurrentOrder.MenuId = nil
                State.CurrentOrder.Flavour = nil
                State.CurrentOrder.NextStep = nil
                State.CurrentOrder.NextStation = nil
                State.CurrentOrder.DoneCount = 0
                State.CurrentOrder.StepCount = 0
                State.CurrentOrder.Ruined = false
                State.CurrentOrder.Done = false

                Helpers.CleanAllUIs()
                continue
            end

            -- B. Cek apakah prompt customer adalah Hand over
            local act = (targetPrompt.ActionText or ""):lower()
            local isHandOver = act:find("hand") or act:find("serah") or act:find("antar") or act:find("beri") or act:find("saji")
            if isHandOver and not State.CurrentOrder.OrderId then
                fireproximityprompt(targetPrompt)
                task.wait(Config.ActionDelay or 0.8)
                continue
            end

            -- C. Ambil Pesanan Baru
            State.CurrentOrder.OrderId = nil
            State.CurrentOrder.MenuId = nil
            State.CurrentOrder.Flavour = nil
            State.CurrentOrder.NextStep = nil
            State.CurrentOrder.NextStation = nil
            State.CurrentOrder.DoneCount = 0
            State.CurrentOrder.StepCount = 0
            State.CurrentOrder.Ruined = false
            State.CurrentOrder.Done = false

            State.Phase = "Ambil Pesanan"
            NetworkHandler.SetupHooks()
            fireproximityprompt(targetPrompt)
            task.wait(Config.ActionDelay or 0.8)

            local waitT0 = os.clock()
            while not State.CurrentOrder.OrderId and (os.clock() - waitT0 < 5.0) and IsAlive() do
                if targetPrompt and targetPrompt.Enabled and (os.clock() - waitT0 > 1.2) then
                    fireproximityprompt(targetPrompt)
                    task.wait(0.3)
                end
                task.wait(0.2)
            end

            -- Fallback deteksi pesanan dari PlayerGui
            if not State.CurrentOrder.OrderId or not State.CurrentOrder.MenuId then
                pcall(function()
                    local bGui = LocalPlayer.PlayerGui:FindFirstChild("Job") and LocalPlayer.PlayerGui.Job:FindFirstChild("Barista")
                    local ordersFrame = bGui and bGui:FindFirstChild("Orders")
                    if ordersFrame then
                        for _, row in ipairs(ordersFrame:GetChildren()) do
                            if row:IsA("Frame") and row:FindFirstChild("Menu") and row:FindFirstChild("Number") then
                                local numStr = row.Number.Text:gsub("%D", "")
                                local menuStr = row.Menu.Text:gsub("^%s*(.-)%s*$", "%1")
                                if menuStr ~= "" then
                                    State.CurrentOrder.OrderId = tonumber(numStr) or 1
                                    State.CurrentOrder.MenuId = menuStr
                                    break
                                end
                            end
                        end
                    end
                end)
            end

            Helpers.CleanAllUIs()

            if not State.CurrentOrder.OrderId or not State.CurrentOrder.MenuId then
                task.wait(Config.ActionDelay or 0.8)
                continue
            end

            State.Phase = "Meracik: " .. tostring(State.CurrentOrder.MenuId)

            -- Langkah 1: Ambil Cup di CupRack & Pilih Menu
            Helpers.MoveToStation("CupRack")
            task.wait(Config.ActionDelay or 0.8)
            State.LastPickPromptKind = nil
            NetworkHandler.FireStation("CupRack")

            local fallbackPicked = false
            local cupT0 = os.clock()
            while (State.CurrentOrder.DoneCount or 0) < 1 and not State.CurrentOrder.Ruined and (os.clock() - cupT0 < 6.0) and IsAlive() do
                if not fallbackPicked and os.clock() - cupT0 > 1.2 and (State.CurrentOrder.DoneCount or 0) < 1 and not State.LastPickPromptKind then
                    fallbackPicked = true
                    NetworkHandler.FirePick("Menu", State.CurrentOrder.MenuId or "KopiHitam")
                end
                task.wait(0.15)
            end
            Helpers.CleanAllUIs()
            task.wait(Config.ActionDelay or 0.8)

            -- Langkah 2+: Ikuti langkah racikan stasiun dinamis dari server
            local loopT0 = os.clock()
            while not State.CurrentOrder.Done and not State.CurrentOrder.Ruined and (os.clock() - loopT0 < 50.0) and IsAlive() do
                Helpers.CleanAllUIs()

                local step = State.CurrentOrder.NextStep
                local station = State.CurrentOrder.NextStation

                if not step then
                    task.wait(0.2)
                    continue
                end

                if step == "Pour" then
                    task.wait(0.5)
                    continue
                end

                local prevDone = State.CurrentOrder.DoneCount or 0

                if step == "Brew" then
                    -- Mesin Espresso
                    Helpers.MoveToStation("Brewer")
                    task.wait(Config.ActionDelay or 0.8)
                    NetworkHandler.FireStation("Brewer")
                    local waitExtract = (State.BrewDuration or 5.0) + 0.3
                    task.wait(waitExtract)
                    NetworkHandler.FireBrewResult(1)
                else
                    local targetStation = station or Config.StepToStation[step] or step
                    Helpers.MoveToStation(targetStation)
                    task.wait(Config.ActionDelay or 0.8)
                    State.LastPickPromptKind = nil
                    NetworkHandler.FireStation(targetStation)

                    if step == "Flavour" then
                        task.wait(Config.ActionDelay or 0.8)
                        if (State.CurrentOrder.DoneCount or 0) <= prevDone and not State.LastPickPromptKind then
                            local chosenFlavour = State.CurrentOrder.Flavour
                            if not chosenFlavour or chosenFlavour == "" then
                                chosenFlavour = "Vanilla"
                            end
                            NetworkHandler.FirePick("Flavour", chosenFlavour)
                        end
                    end
                end

                -- Tunggu server menambah DoneCount (Anti Double-Fire)
                local stepT0 = os.clock()
                while (State.CurrentOrder.DoneCount or 0) <= prevDone and not State.CurrentOrder.Done and not State.CurrentOrder.Ruined and (os.clock() - stepT0 < 6.0) and IsAlive() do
                    task.wait(0.15)
                end
                task.wait(Config.ActionDelay or 0.8)
            end

            -- Jika minuman rusak, buang ke Trash
            if State.CurrentOrder.Ruined then
                State.RuinedOrders = State.RuinedOrders + 1
                warn("⚠️ [Kanji Jawa] Minuman rusak! Membuang ke tempat sampah...")
                if Context and Context.SendLog then
                    Context.SendLog("[Barista] Minuman rusak! Membuang ke tempat sampah...", "WARN")
                end
                Helpers.MoveToStation("Trash")
                task.wait(Config.ActionDelay or 0.8)
                NetworkHandler.FireTrash()
                task.wait(1.5)
                Helpers.CleanAllUIs()
                continue
            end

            -- Langkah Terakhir: Sajikan Minuman ke Customer
            if State.CurrentOrder.Done and State.CurrentOrder.OrderId and IsAlive() then
                State.Phase = "Menyajikan Minuman"

                if counterCustomer and counterCustomer.Parent then
                    Helpers.MoveToCustomerCounter(counterCustomer)
                    task.wait(Config.ActionDelay or 0.8)

                    local servePrompt = counterCustomer:FindFirstChildWhichIsA("ProximityPrompt", true)
                    local waitServeT0 = os.clock()
                    while (not servePrompt or not servePrompt.Enabled) and (os.clock() - waitServeT0 < 6.0) and IsAlive() do
                        task.wait(0.2)
                        servePrompt = counterCustomer:FindFirstChildWhichIsA("ProximityPrompt", true)
                    end

                    if servePrompt and servePrompt.Enabled then
                        fireproximityprompt(servePrompt)
                    end
                end

                NetworkHandler.FireServe(State.CurrentOrder.OrderId)
                task.wait(1.5)
                Helpers.CleanAllUIs()

                State.LastServedCustomer = counterCustomer
                State.LastServedTime = os.clock()

                State.CurrentOrder.OrderId = nil
                State.CurrentOrder.MenuId = nil
                State.CurrentOrder.Flavour = nil
                State.CurrentOrder.NextStep = nil
                State.CurrentOrder.NextStation = nil
                State.CurrentOrder.DoneCount = 0
                State.CurrentOrder.StepCount = 0
                State.CurrentOrder.Ruined = false
                State.CurrentOrder.Done = false
            end

            task.wait(Config.LoopWait or 1.0)
        end

        State.Phase = "Standby"
        State.IsBusy = false
        Helpers.CleanAllUIs()
    end)
end

function AutoFarm.Stop()
    isRunning = false
    State.IsFarming = false
    State.AutoFarmActive = false
    State.IsBusy = false
    State.Phase = "Standby"
    Helpers.CleanAllUIs()
end

-- ==============================================================================
-- 6. PUBLIC INTERFACE
-- ==============================================================================
function KanjiJawaJob.Init(coreContext)
    Context = coreContext
    NetworkHandler.Init()
    Helpers.GetCash()
    print("[OE-External CDID] Modul Cafe Kanji Jawa (Barista) Berhasil Diinisialisasi")
end

function KanjiJawaJob.Start()
    AutoFarm.Start()
    if Context and Context.SendLog then
        Context.SendLog("Auto Farm Kanji Jiwa (Barista) Dimulai!", "SUCCESS")
    end
end

function KanjiJawaJob.Stop()
    AutoFarm.Stop()
    if Context and Context.SendLog then
        Context.SendLog("Auto Farm Kanji Jiwa (Barista) Dihentikan.", "WARN")
    end
end

function KanjiJawaJob.TeleportCafe()
    Helpers.TeleportToCafe()
    if Context and Context.SendLog then
        Context.SendLog("Teleport ke Kanji Jiwa.", "INFO")
    end
end

function KanjiJawaJob.GetState()
    Helpers.GetCash()
    return State
end

return KanjiJawaJob
end

Modules["games/cdid"] = function()
--[[
    OneEight External Hub - CDID Modular Main Coordinator
    100% Clean, Modular, and Extensible Architecture
--]]
local CDID_PLACES = {
    [6911148748]        = "CDID Main Menu",
    [110369730911937]   = "CDID Jawa Timur",
    [14005966837]       = "CDID Jakarta",
    [79488788685813]    = "CDID Bandung",
    [9233343468]        = "CDID Jawa Barat",
    [9508940498]        = "CDID Jawa Tengah",
    [118108582994420]   = "CDID Bali",
    [132986577553100]   = "CDID Seasonal"
}

local function getPlaceName()
    local name = CDID_PLACES[game.PlaceId]
    if not name then
        pcall(function()
            local MarketplaceService = game:GetService("MarketplaceService")
            local info = MarketplaceService:GetProductInfo(game.PlaceId)
            if info and info.Name then
                name = info.Name
            end
        end)
    end
    return name or "Car Driving Indonesia"
end

local CDIDModule = {}
CDIDModule.GameId = "cdid"
CDIDModule.GameName = getPlaceName()
CDIDModule.GetPlaceName = getPlaceName
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
local MinigameJob = nil
local KanjiJawaJob = nil
local JobProgressFeature = nil

function CDIDModule.Init(coreContext)
    Context = coreContext

    -- Load sub-modul
    LightingFeature = requireModule("games/cdid/features/lighting")
    SafetyFeature = requireModule("games/cdid/features/safety")
    DealershipFeature = requireModule("games/cdid/features/dealership")
    TeleportFeature = requireModule("games/cdid/features/teleport")
    JobProgressFeature = requireModule("games/cdid/features/job_progress")
    TruckJob = requireModule("games/cdid/jobs/truck")
    MinigameJob = requireModule("games/cdid/jobs/minigames")
    KanjiJawaJob = requireModule("games/cdid/jobs/kanji_jawa")

    TruckJob.Init(coreContext)
    if MinigameJob and MinigameJob.Init then MinigameJob.Init(coreContext) end
    if KanjiJawaJob and KanjiJawaJob.Init then KanjiJawaJob.Init(coreContext) end
    if JobProgressFeature and JobProgressFeature.Init then JobProgressFeature.Init(coreContext) end
    if SafetyFeature and SafetyFeature.CheckCurrentLockState then
        pcall(SafetyFeature.CheckCurrentLockState)
    end
    print("[OE-External CDID] Modular Coordinator Berhasil Diinisialisasi (Truk, Minigames & Cafe Kanji Jawa)!")
    _G.OE_ExternalCDID = CDIDModule

    -- Auto-push katalog dealer saat inisialisasi agar web langsung punya data tanpa nunggu tombol
    task.spawn(function()
        task.wait(1.5)
        if DealershipFeature and Context and Context.SendPacket then
            local cars = DealershipFeature.GetCars("all")
            Context.SendPacket("DEALER_CARS_DATA", {
                dealer = "all",
                cars = cars
            })
        end
    end)
end

function CDIDModule.HandleCommand(action, payload)
    if action == "START_FARM" then
        local jobType = payload and payload.jobType or "truck"
        if jobType == "minigame" then
            if MinigameJob then MinigameJob.Start(payload) end
        elseif jobType == "kanji_jawa" or jobType == "barista" then
            if KanjiJawaJob then KanjiJawaJob.Start() end
        else
            if TruckJob then TruckJob.Start() end
        end
        return true

    elseif action == "STOP_FARM" then
        if TruckJob then TruckJob.Stop() end
        if MinigameJob then MinigameJob.Stop() end
        if KanjiJawaJob then KanjiJawaJob.Stop() end
        return true

    elseif action == "START_MINIGAME_FARM" then
        if MinigameJob then MinigameJob.Start(payload) end
        return true

    elseif action == "STOP_MINIGAME_FARM" then
        if MinigameJob then MinigameJob.Stop() end
        return true

    elseif action == "BUY_MINIGAME_BOX" then
        if MinigameJob then MinigameJob.BuyBox() end
        return true

    elseif action == "START_KANJI_JAWA_FARM" or action == "START_BARISTA_FARM" then
        if KanjiJawaJob then KanjiJawaJob.Start() end
        return true

    elseif action == "STOP_KANJI_JAWA_FARM" or action == "STOP_BARISTA_FARM" then
        if KanjiJawaJob then KanjiJawaJob.Stop() end
        return true

    elseif action == "TELEPORT_CAFE" then
        if KanjiJawaJob then KanjiJawaJob.TeleportCafe() end
        return true

    elseif action == "CLAIM_JOB_LEVEL" then
        if JobProgressFeature and payload and payload.level then
            local job = (payload and payload.jobName) or "Barista"
            JobProgressFeature.ClaimLevel(job, payload.level)
        end
        return true

    elseif action == "CLAIM_ALL_JOB_LEVELS" then
        if JobProgressFeature then
            local job = (payload and payload.jobName) or "Barista"
            JobProgressFeature.ClaimAll(job)
        end
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
            pcall(function()
                local cars = DealershipFeature.GetCars(dealer)
                Context.SendPacket("DEALER_CARS_DATA", {
                    dealer = dealer,
                    cars = cars
                })
            end)
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
    local stMg = MinigameJob and MinigameJob.GetState() or {}
    local stKj = KanjiJawaJob and KanjiJawaJob.GetState() or {}

    local isTruckFarming = (st.IsFarming == true)
    local isMinigameFarming = (stMg.IsFarming == true)
    local isKanjiFarming = (stKj.IsFarming == true)
    local isFarming = isTruckFarming or isMinigameFarming or isKanjiFarming
    local elapsedSec = 0
    if st.IsFarming and st.FarmStartTime and st.FarmStartTime > 0 then
        elapsedSec = math.floor(os.clock() - st.FarmStartTime)
    elseif stMg.IsFarming and stMg.FarmStartTime and stMg.FarmStartTime > 0 then
        elapsedSec = math.floor(os.time() - stMg.FarmStartTime)
    elseif stKj.IsFarming and stKj.FarmStartTime and stKj.FarmStartTime > 0 then
        elapsedSec = math.floor(os.clock() - stKj.FarmStartTime)
    end

    local placeName = getPlaceName()
    local dynamicJob = "Unemployed"
    if stMg.IsFarming then
        dynamicJob = "Minigames Sumo (" .. (stMg.Role or "Winner") .. ")"
    elseif stKj.IsFarming then
        dynamicJob = "Kanji Jiwa (Barista)"
    elseif st.IsFarming then
        dynamicJob = "Truk Kargo"
    end

    return {
        -- SSOT: Unified Active Features Flags (Single Source of Truth)
        features = {
            truck = isTruckFarming,
            minigame = isMinigameFarming,
            kanjiJiwa = isKanjiFarming,
            lowRender = (st.LowRender == true),
            serverLocked = (SafetyFeature and SafetyFeature.ServerLocked == true) or false,
            playerDetector = (SafetyFeature and SafetyFeature.PlayerDetectorEnabled == true) or false,
            fullbright = (LightingFeature and LightingFeature.Fullbright == true) or false,
            noFog = (LightingFeature and LightingFeature.NoFog == true) or false,
            autoOpenBox = (stMg.AutoOpenBox == true),
        },
        config = {
            minigameRole = stMg.Role or "Winner",
            emergencyAction = (SafetyFeature and SafetyFeature.EmergencyAction) or "Warn Only",
            ignoreFriends = (SafetyFeature and SafetyFeature.IgnoreFriends ~= false),
        },
        status = isMinigameFarming and (stMg.Phase or "RUNNING") or (isKanjiFarming and (stKj.Phase or "RUNNING") or (st.Status or "CONNECTED")),
        job = dynamicJob,
        placeName = placeName,
        gameName = placeName,
        currentRoute = stMg.IsFarming and ("Sumo Arena: " .. (stMg.Phase or "Lobby")) or (stKj.IsFarming and ("Kanji Jiwa: " .. (stKj.Phase or "Standby")) or (st.CurrentRoute or "IDLE")),
        tripCount = st.TripCount or 0,
        truckEarnings = st.IsFarming and (st.TotalEarnings or 0) or (st.TripCount and st.TripCount > 0 and (st.TotalEarnings or 0) or 0),
        totalEarnings = (st.IsFarming and (st.TotalEarnings or 0) or 0) + (stMg.IsFarming and (stMg.CashEarned or 0) or 0) + (stKj.IsFarming and (stKj.TotalEarned or 0) or 0),
        currentCash = (st.CurrentCash and st.CurrentCash > 0) and st.CurrentCash or ((stMg.CurrentCash and stMg.CurrentCash > 0) and stMg.CurrentCash or (stKj.CurrentCash or 0)),
        startCash = st.StartCash or 0,
        isFarming = isFarming,
        minigame = {
            isFarming = stMg.IsFarming or false,
            role = stMg.Role or "Winner",
            phase = stMg.Phase or "Standby",
            points = stMg.CurrentPoints or 0,
            pointsEarned = stMg.PointsEarned or 0,
            cashEarned = stMg.CashEarned or 0,
            wins = stMg.TotalWins or 0,
            losses = stMg.TotalLosses or 0,
            boxes = stMg.BoxesOpened or 0,
            autoOpenBox = stMg.AutoOpenBox or false,
            round = stMg.CurrentRound or 0,
            maxRounds = stMg.MaxRounds or 10,
            lastResult = stMg.LastMatchResult or "-"
        },
        barista = {
            isFarming = stKj.IsFarming or false,
            phase = stKj.Phase or "Standby",
            totalOrders = stKj.TotalOrders or 0,
            ruinedOrders = stKj.RuinedOrders or 0,
            totalEarned = stKj.TotalEarned or 0,
            lastGaji = stKj.LastGaji or 0,
            avgPerHour = stKj.AvgPerHour or 0,
            currentCustomer = stKj.CurrentCustomerName or "-",
            currentOrder = stKj.CurrentOrder or {}
        },
        jobProgress = JobProgressFeature and JobProgressFeature.GetProgressData("Barista") or nil,
        speed = st.Speed or 0,
        distRemaining = st.DistRemaining or "0m",
        lowRender = st.LowRender or false,
        minDistance = st.MinDistance or 100000,
        farmDuration = elapsedSec,
        dealerList = DealershipFeature and DealershipFeature.GetRealDealerList() or {},
        safety = SafetyFeature and {
            PlayerDetectorEnabled = SafetyFeature.PlayerDetectorEnabled,
            EmergencyAction = SafetyFeature.EmergencyAction,
            IgnoreFriends = SafetyFeature.IgnoreFriends,
            ServerLocked = (SafetyFeature.CheckCurrentLockState and SafetyFeature.CheckCurrentLockState()) or SafetyFeature.ServerLocked
        } or {},
        lighting = LightingFeature and {
            Fullbright = LightingFeature.Fullbright,
            NoFog = LightingFeature.NoFog
        } or {}
    }
end

function CDIDModule.Cleanup()
    if TruckJob then TruckJob.Stop() end
    if MinigameJob then MinigameJob.Stop() end
    if KanjiJawaJob then KanjiJawaJob.Stop() end
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
    { Key = "Jakarta",     Name = "Jakarta",      PlaceId = 14005966837,     Desc = "Kurir BCA & Kanji Jiwa",  Icon = "building" },
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
    _G.OE_PRIVATE_SERVER_CODE = clean
    
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

    -- Sumber 4: Global Variable & Persisten File (Auto-Rejoin Bridge)
    local persistentCode = nil
    if _G.OE_PRIVATE_SERVER_CODE and isValidServerCode(_G.OE_PRIVATE_SERVER_CODE) then
        persistentCode = _G.OE_PRIVATE_SERVER_CODE
    elseif typeof(readfile) == "function" then
        pcall(function()
            if (typeof(isfile) == "function" and isfile("oe_cdid_ps_code.txt")) or true then
                local saved = readfile("oe_cdid_ps_code.txt")
                if isValidServerCode(saved) then
                    persistentCode = saved
                end
            end
        end)
    end
    if persistentCode then
        return applyServerCode(persistentCode, "PersistentFileOrGlobal")
    end

    return false
end

-- Request kode baru dari server game CDID
local function requestServerCode()
    print("[OE-External CDID] 🔄 Meminta pembuatan kode server private baru...")
    if Context and Context.SendLog then
        Context.SendLog("Meminta server CDID untuk generate kode private baru...", "INFO")
    end

    local triggered = false
    pcall(function()
        local ps = LocalPlayer.PlayerGui.Hub.Container.Window.PrivateServer
        local genBtn = ps and ps:FindFirstChild("GenerateButton") and ps.GenerateButton:FindFirstChild("TextButton")
        if genBtn then
            local conns = getconnections and getconnections(genBtn.MouseButton1Down) or {}
            for _, c in ipairs(conns) do
                if c.Function then
                    pcall(c.Function)
                    triggered = true
                end
            end
            if not triggered and typeof(firesignal) == "function" then
                firesignal(genBtn.MouseButton1Down)
                triggered = true
            end
        end
    end)

    local net = getCDIDNetwork()
    if not triggered and net and net.FireServer then
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

    -- 1. Klik tombol map asli di UI CDID (MouseButton1Down & Activated)
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
            local actConns = getconnections and getconnections(btn.Activated) or {}
            for _, c in ipairs(actConns) do
                if c.Function then pcall(c.Function) end
            end
        end
    end)

    -- 2. Sync ke real UIAnimation di GC & SetMapSelected
    local realUI = getRealUIAnimation()
    if realUI then
        realUI.SelectedMap = mapKey
        pcall(function()
            if realUI.WindowModule and realUI.WindowModule.HubContainer and realUI.WindowModule.HubContainer.SetMapSelected then
                realUI.WindowModule.HubContainer:SetMapSelected(mapKey:upper())
            end
        end)
    end

    -- 3. Sync ke Controller UIAnimation CDID
    pcall(function()
        local controller = ReplicatedStorage:FindFirstChild("Controller")
        if controller and controller:FindFirstChild("UIAnimation") then
            local uiMod = require(controller.UIAnimation)
            if uiMod then uiMod.SelectedMap = mapKey end
        end
    end)
end

local function joinMap(mapKey, serverCode)
    mapKey = mapKey or State.SelectedMap or "JawaTimur"
    State.Status = "JOINING_" .. string.upper(mapKey)

    -- Setup queue_on_teleport agar loader kembali berjalan di server tujuan (Maksimal 1 kali agar tidak menumpuk)
    if not _G.OE_TeleportQueued then
        _G.OE_TeleportQueued = true
        local queue_teleport = (syn and syn.queue_on_teleport) or queue_on_teleport or (fluxus and fluxus.queue_on_teleport) or queueonteleport
        if queue_teleport then
            pcall(function()
                queue_teleport([[
                    task.wait(3.5)
                    loadstring(game:HttpGet("https://externalhub.oneeight-project18.workers.dev/loader"))()
                ]])
            end)
        end
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
    task.wait(0.5)

    -- Pemicu 1: Klik tombol Join asli game via connections
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
            local actConns = getconnections and getconnections(joinBtn.Activated) or {}
            for _, c in ipairs(actConns) do
                if c.Function then pcall(c.Function) end
            end
        end
    end)

    -- Pemicu 2: Backup langsung via Network Remote
    local net = getCDIDNetwork()
    if net and net.FireServer and codeToUse and codeToUse ~= "" then
        pcall(function()
            net:FireServer("PrivateServer", "Join", tostring(codeToUse), mapKey)
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
        job = "Server Gateway",
        placeName = "CDID Main Menu",
        gameName = "CDID Main Menu",
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

local CDID_PLACES = {
    [6911148748]        = "CDID Main Menu",
    [110369730911937]   = "CDID Jawa Timur",
    [14005966837]       = "CDID Jakarta",
    [79488788685813]    = "CDID Bandung",
    [9233343468]        = "CDID Jawa Barat",
    [9508940498]        = "CDID Jawa Tengah",
    [118108582994420]   = "CDID Bali",
    [132986577553100]   = "CDID Seasonal"
}

local function getDetectedPlaceName()
    local name = CDID_PLACES[placeId]
    if not name then
        pcall(function()
            local MarketplaceService = game:GetService("MarketplaceService")
            local info = MarketplaceService:GetProductInfo(placeId)
            if info and info.Name then
                name = info.Name
            end
        end)
    end
    return name or (isLobby and "CDID Main Menu" or "Car Driving Indonesia")
end

local detectedPlaceName = getDetectedPlaceName()
local initialJob = isLobby and "Server Gateway" or "Unemployed"

if isLobby then
    activeGameModule = requireModule("games/cdid_menu")
else
    activeGameModule = requireModule("games/cdid")
end

-- ============================================================================
-- STATE & WEBSOCKET NETWORKING
-- ============================================================================
local WS_BASE_URL = "wss://externalhub.oneeight-project18.workers.dev/ws"
local WS_URL = string.format("%s?role=bot&name=%s&userId=%s&displayName=%s&gameId=%s&gameName=%s&placeName=%s&placeId=%s&job=%s",
    WS_BASE_URL,
    HttpService:UrlEncode(LocalPlayer.Name),
    tostring(LocalPlayer.UserId or 0),
    HttpService:UrlEncode(LocalPlayer.DisplayName or LocalPlayer.Name),
    HttpService:UrlEncode(activeGameModule.GameId or "generic"),
    HttpService:UrlEncode(detectedPlaceName),
    HttpService:UrlEncode(detectedPlaceName),
    tostring(placeId),
    HttpService:UrlEncode(initialJob)
)

local CoreState = {
    Socket = nil,
    BotId = nil,
    SessionStartTime = os.clock(),
    AutoRejoin = true,
    IsTerminated = false
}

local function sendPacket(packetType, payload)
    if not CoreState.Socket or CoreState.IsTerminated then return end
    pcall(function()
        local data = HttpService:JSONEncode({
            type = packetType,
            payload = payload
        })
        CoreState.Socket:Send(data)
    end)
end

local function sendLog(msg, level)
    if not CoreState.Socket or CoreState.IsTerminated then return end
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

-- ============================================================================
-- OVER-THE-AIR (OTA) HOT-RELOAD & STATE PRESERVATION SYSTEM
-- ============================================================================
local function performHotReload(targetBuildId)
    if CoreState.IsReloading then return end
    CoreState.IsReloading = true
    CoreState.IsTerminated = true

    sendLog(string.format("Memulai Hot-Reload OTA ke build [%s] tanpa rejoin...", tostring(targetBuildId or "TERBARU")), "WARN")
    print(string.format("[OE-External OTA] Executing Live Hot-Reload to Build: %s", tostring(targetBuildId or "TERBARU")))

    -- 1. Tangkap status fitur aktif saat ini untuk auto-resume pasca reload
    pcall(function()
        local telem = activeGameModule and activeGameModule.GetTelemetry and activeGameModule.GetTelemetry()
        local feats = telem and telem.features or {}
        local activeJob = nil
        if feats.kanjiJiwa then
            activeJob = "kanji_jawa"
        elseif feats.minigame then
            activeJob = "minigames"
        elseif feats.truck then
            activeJob = "truck"
        end

        _G.OE_PreservedState = {
            timestamp = os.time(),
            activeJob = activeJob,
            minigameRole = telem and telem.config and telem.config.minigameRole,
            autoOpenBox = feats.autoOpenBox,
            lowRender = feats.lowRender,
            serverLocked = feats.serverLocked,
            playerDetector = feats.playerDetector,
            emergencyAction = telem and telem.config and telem.config.emergencyAction,
            ignoreFriends = telem and telem.config and telem.config.ignoreFriends,
            fullbright = feats.fullbright,
            noFog = feats.noFog,
            minDistance = telem and telem.minDistance
        }
        print("[OE-External OTA] State aktif berhasil diawetkan di _G.OE_PreservedState!")
    end)

    -- 2. Matikan modul aktif secara tertib (membersihkan UI, prompt, dan loop)
    pcall(function()
        if activeGameModule and activeGameModule.Cleanup then
            activeGameModule.Cleanup()
        end
    end)

    -- 3. Tutup WebSocket saat ini dengan status HOT_RELOAD
    if CoreState.Socket then
        pcall(function()
            CoreState.Socket:Close(4001, "HOT_RELOAD")
        end)
        CoreState.Socket = nil
    end

    _G.OE_ExternalRunning = false

    -- 4. Unduh & eksekusi build agen terbaru secara in-memory
    task.delay(0.6, function()
        local loadOk, loadErr = pcall(function()
            local targetUrl = LOADER_URL or "https://externalhub.oneeight-project18.workers.dev/loader"
            local src = game:HttpGet(targetUrl .. "?t=" .. tostring(os.time()))
            src = src:gsub("^\239\187\191", "")
            local fn, compileErr = loadstring(src, "OE_ExternalAgent")
            if not fn then
                error(tostring(compileErr))
            end
            fn()
        end)
        if not loadOk then
            warn("[OE-External OTA] Gagal mengeksekusi loader:", tostring(loadErr))
        end
    end)
end

local function checkPreservedState()
    local preserved = _G.OE_PreservedState
    if preserved and (os.time() - (preserved.timestamp or 0) < 30) then
        _G.OE_PreservedState = nil
        print("[OE-External OTA] Ditemukan state tersimpan pasca Hot-Reload! Memulihkan dalam 1.5 detik...")
        task.spawn(function()
            task.wait(1.5)
            if preserved.serverLocked ~= nil then
                activeGameModule.HandleCommand("TOGGLE_SERVER_LOCK", { locked = preserved.serverLocked })
            end
            if preserved.fullbright then
                activeGameModule.HandleCommand("TOGGLE_FULLBRIGHT", { enabled = true })
            end
            if preserved.noFog then
                activeGameModule.HandleCommand("TOGGLE_NO_FOG", { enabled = true })
            end
            if preserved.playerDetector ~= nil then
                activeGameModule.HandleCommand("SET_SAFETY_CONFIG", {
                    playerDetector = preserved.playerDetector,
                    emergencyAction = preserved.emergencyAction,
                    ignoreFriends = preserved.ignoreFriends
                })
            end
            if preserved.minDistance then
                activeGameModule.HandleCommand("SET_MIN_DISTANCE", { minDistance = preserved.minDistance })
            end

            -- Pulihkan pekerjaan auto-farm yang sebelumnya sedang jalan
            if preserved.activeJob == "kanji_jawa" then
                sendLog("[OTA Auto-Resume] Melanjutkan pekerjaan Kanji Jiwa...", "SUCCESS")
                activeGameModule.HandleCommand("START_KANJI_JAWA_FARM")
            elseif preserved.activeJob == "minigames" then
                sendLog("[OTA Auto-Resume] Melanjutkan Minigames Sumo...", "SUCCESS")
                activeGameModule.HandleCommand("START_MINIGAME_FARM", { role = preserved.minigameRole, autoOpenBox = preserved.autoOpenBox })
            elseif preserved.activeJob == "truck" then
                sendLog("[OTA Auto-Resume] Melanjutkan Truk Kargo...", "SUCCESS")
                activeGameModule.HandleCommand("START_FARM")
            end
        end)
    else
        _G.OE_PreservedState = nil
    end
end

local function connectWebSocket()
    if CoreState.IsTerminated or not isInstanceAlive() then return end
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
        if _G.OE_ExternalRunning and not CoreState.IsTerminated then return connectWebSocket() end
        return
    end

    CoreState.Socket = ws
    _G.OE_ExternalSocket = ws
    print("[OE-External] WebSocket terhubung sukses!")

    -- Heartbeat Ping Loop (Setiap 5 detik untuk menjaga koneksi tetap hidup)
    task.spawn(function()
        while isInstanceAlive() and not CoreState.IsTerminated and CoreState.Socket == ws do
            task.wait(5)
            if CoreState.Socket == ws and not CoreState.IsTerminated then
                pcall(function()
                    ws:Send(HttpService:JSONEncode({
                        type = "PING",
                        timestamp = os.time()
                    }))
                end)
            end
        end
    end)

    ws.OnMessage:Connect(function(msgRaw)
        local okParse, data = pcall(function() return HttpService:JSONDecode(msgRaw) end)
        if not okParse or not data then return end

        if data.type == "INIT_ACK" or data.type == "SERVER_HANDSHAKE" then
            CoreState.BotId = data.botId or CoreState.BotId
            print("[OE-External] Terdaftar dengan Bot ID: " .. tostring(CoreState.BotId))
            sendLog(string.format("Akun aktif di %s (%s) & terhubung ke Web Hub! [Build: %s]", activeGameModule.GameName, tostring(game.PlaceId), tostring(AGENT_BUILD_ID or "N/A")), "SUCCESS")

            -- Cek versi build: jika build server berbeda dengan build lokal agen, otomatis Hot-Reload
            if data.buildId and AGENT_BUILD_ID and data.buildId ~= AGENT_BUILD_ID then
                print(string.format("[OE-External OTA] Build server (%s) berbeda dengan build lokal (%s). Memulai Hot-Reload...", tostring(data.buildId), tostring(AGENT_BUILD_ID)))
                task.delay(0.2, function()
                    performHotReload(data.buildId)
                end)
                return
            end

        elseif data.type == "OTA_UPDATE" then
            if data.buildId and AGENT_BUILD_ID and data.buildId ~= AGENT_BUILD_ID then
                print(string.format("[OE-External OTA] Menerima sinyal OTA_UPDATE (%s). Memulai Hot-Reload...", tostring(data.buildId)))
                task.delay(0.2, function()
                    performHotReload(data.buildId)
                end)
                return
            end

        elseif data.type == "PONG" then
            CoreState.LastPong = os.time()

        elseif data.type == "FORCE_DISCONNECT" then
            print("[OE-External] Sesi digantikan oleh koneksi baru: " .. tostring(data.message or "SUPERSEDED"))
            CoreState.IsTerminated = true
            if _G.OE_ExternalCurrentInstance == MY_INSTANCE_ID then
                _G.OE_ExternalRunning = false
            end
            pcall(function() ws:Close() end)
            return

        elseif data.type == "EXECUTE_COMMAND" then
            local action = data.action
            local payload = data.payload or {}
            print("[OE-External] Menerima Perintah: " .. tostring(action))

            if action == "HOT_RELOAD" then
                sendLog("Menerima perintah Hot-Reload manual dari Web Console...", "WARN")
                task.delay(0.1, function()
                    performHotReload(data.payload and data.payload.buildId or "MANUAL_TRIGGER")
                end)

            elseif action == "REJOIN_SERVER" then
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

    ws.OnClose:Connect(function(codeOrReason, maybeReason)
        CoreState.Socket = nil
        local closeReasonStr = string.lower(tostring(codeOrReason or "") .. " " .. tostring(maybeReason or ""))

        if CoreState.IsTerminated or not isInstanceAlive() then
            print("[OE-External] Instance dihentikan atau ditutup permanen, coroutine berhenti.")
            return
        end

        if string.find(closeReasonStr, "replaced") or string.find(closeReasonStr, "4001") or string.find(closeReasonStr, "hot_reload") then
            print("[OE-External] Terdeteksi penutupan karena sesi baru (replaced). Menghentikan rekoneksi.")
            CoreState.IsTerminated = true
            return
        end

        local retryDelay = 1
        warn(string.format("[OE-External] WebSocket terputus! Mencoba rekoneksi instan dalam %d detik...", retryDelay))
        task.wait(retryDelay)
        if isInstanceAlive() and not Safety.IsKicked and not CoreState.IsTerminated then
            connectWebSocket()
        end
    end)
end

-- ============================================================================
-- TELEMETRY STREAM LOOP (1 Detik Sekali)
-- ============================================================================
task.spawn(function()
    while isInstanceAlive() and not CoreState.IsTerminated do
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
            gameName = gameTelem.gameName or detectedPlaceName,
            placeName = gameTelem.placeName or detectedPlaceName,
            job = gameTelem.job or initialJob,
            currencyUnit = activeGameModule.CurrencyUnit,
            metricUnit = activeGameModule.MetricUnit,
            placeId = tostring(game.PlaceId)
        }

        for k, v in pairs(gameTelem) do
            combinedPayload[k] = v
        end

        sendPacket("TELEMETRY", combinedPayload)
        task.wait(1.5)
    end
end)

connectWebSocket()
