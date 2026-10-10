--[[
    OneEight External Hub - CDID Minigames Farm (Sumo Arena) Module
    Ported from Official OneEight Hub CDID Minigame Engine
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local MinigameJob = {}
MinigameJob.JobName = "Minigame"
MinigameJob.PlaceId = 14005966837

local Context = nil

-- 1. CONFIG
--[[
    OneEight Hub - CDID Minigames Farm Configuration
    Contains settings, payout rates, timeouts, and arena metadata.
--]]

local Config = {
    JobName = "Minigame Farm",
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

            -- CASE A: Sedang di dalam Arena Minigames (Pertandingan Minigame)
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
    print("[OE-External CDID] Modul Minigame Berhasil Diinisialisasi")
end

function MinigameJob.SetConfig(config)
    if not config then return end
    if config.autoOpenBox ~= nil then
        State.AutoOpenBox = (config.autoOpenBox == true)
    end
    if config.role and (config.role == "Winner" or config.role == "Loser") then
        State.Role = config.role
    end
    if State.UpdateStatsUI then
        State.UpdateStatsUI()
    end
end

function MinigameJob.SetRole(role)
    if role and (role == "Winner" or role == "Loser") then
        State.Role = role
        if Context and Context.SendLog then
            Context.SendLog(string.format("Role Minigames diubah ke: %s", State.Role), "INFO")
        end
        if State.UpdateStatsUI then
            State.UpdateStatsUI()
        end
    end
end

function MinigameJob.Start(options)
    if options then
        if options.role then State.Role = options.role end
        if options.autoOpenBox ~= nil then State.AutoOpenBox = options.autoOpenBox end
        if options.selectedCar then State.SelectedCar = options.selectedCar end
    end
    AutoFarm.Start()
    if Context and Context.SendLog then
        Context.SendLog(string.format("Minigame Farm Dimulai (Role: %s, Mobil: %s)", State.Role, State.SelectedCar), "SUCCESS")
    end
end

function MinigameJob.Stop()
    AutoFarm.Stop()
    pcall(function() NetworkHandler.LeaveLobby() end)
    if Context and Context.SendLog then
        Context.SendLog("Minigame Farm Dihentikan.", "WARN")
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
