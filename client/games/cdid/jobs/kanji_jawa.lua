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
KanjiJawaJob.JobName = "Cafe Kanji Jawa (Barista)"
KanjiJawaJob.PlaceIds = { 14005966837 } -- CDID Jakarta

local Context = nil
local isRunning = false
local farmThread = nil
local CurrentHookConn = nil

-- ==============================================================================
-- 1. CONFIGURATION
-- ==============================================================================
local Config = {
    JobName = "Cafe Kanji Jawa (Barista)",
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

    if not pGui then return end

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

    -- 5. Restore Camera
    pcall(function()
        local camera = Workspace.CurrentCamera
        local hum, hrp = Helpers.GetValidHumanoid()
        if camera and hum and camera.CameraType ~= Enum.CameraType.Custom then
            camera.CameraType = Enum.CameraType.Custom
            camera.CameraSubject = hum
            camera.FieldOfView = 70
        end
    end)
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

        if phonePrompt then
            fireproximityprompt(phonePrompt)
            task.wait(0.5)
        end

        local remote = NetworkHandler.GetBaristaRemote(3)
        if remote then
            pcall(function()
                remote:FireServer("TutorialDone")
            end)
        end

        if phoneRing and phoneRing.IsPlaying then
            pcall(function() phoneRing:Stop() end)
        end

        task.wait(0.5)
        LocalPlayer:SetAttribute("NpcDialogOpen", false)
        LocalPlayer:SetAttribute("HidePrompt", false)
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
                Context.SendLog("Menuju lokasi Cafe Kanji Jawa...", "INFO")
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
        Context.SendLog("Auto Farm Cafe Kanji Jawa (Barista) Dimulai!", "SUCCESS")
    end
end

function KanjiJawaJob.Stop()
    AutoFarm.Stop()
    if Context and Context.SendLog then
        Context.SendLog("Auto Farm Cafe Kanji Jawa (Barista) Dihentikan.", "WARN")
    end
end

function KanjiJawaJob.TeleportCafe()
    Helpers.TeleportToCafe()
    if Context and Context.SendLog then
        Context.SendLog("Teleport ke Cafe Kanji Jawa.", "INFO")
    end
end

function KanjiJawaJob.GetState()
    Helpers.GetCash()
    return State
end

return KanjiJawaJob
