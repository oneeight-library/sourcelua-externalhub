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
local StreamerModeFeature = nil

function CDIDModule.Init(coreContext)
    Context = coreContext

    -- Load sub-modul
    LightingFeature = requireModule("games/cdid/features/lighting")
    SafetyFeature = requireModule("games/cdid/features/safety")
    DealershipFeature = requireModule("games/cdid/features/dealership")
    TeleportFeature = requireModule("games/cdid/features/teleport")
    JobProgressFeature = requireModule("games/cdid/features/job_progress")
    StreamerModeFeature = requireModule("games/cdid/features/streamer_mode")
    TruckJob = requireModule("games/cdid/jobs/truck")
    MinigameJob = requireModule("games/cdid/jobs/minigames")
    KanjiJawaJob = requireModule("games/cdid/jobs/kanji_jawa")

    TruckJob.Init(coreContext)
    if MinigameJob and MinigameJob.Init then MinigameJob.Init(coreContext) end
    if KanjiJawaJob and KanjiJawaJob.Init then KanjiJawaJob.Init(coreContext) end
    if JobProgressFeature and JobProgressFeature.Init then JobProgressFeature.Init(coreContext) end
    if StreamerModeFeature and StreamerModeFeature.Init then StreamerModeFeature.Init(coreContext) end
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

local function resignJobUnemployed()
    pcall(function()
        local rem = game:GetService("ReplicatedStorage"):FindFirstChild("NetworkContainer")
        local evs = rem and rem:FindFirstChild("RemoteEvents")
        local jobEv = evs and evs:FindFirstChild("Job")
        if jobEv then
            jobEv:FireServer("Unemployee")
        end
    end)
end

local function respawnPlayerCharacter()
    pcall(function()
        local char = LocalPlayer and LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                hum.Health = 0
            end
        end
    end)
end

local function stopAllJobsClean(shouldRespawn)
    if TruckJob and TruckJob.Stop then TruckJob.Stop() end
    if MinigameJob and MinigameJob.Stop then MinigameJob.Stop() end
    if KanjiJawaJob and KanjiJawaJob.Stop then KanjiJawaJob.Stop() end
    resignJobUnemployed()
    if shouldRespawn then
        task.defer(function()
            task.wait(0.3)
            respawnPlayerCharacter()
        end)
    end
end

function CDIDModule.HandleCommand(action, payload)
    if action == "START_FARM" then
        local jobType = payload and payload.jobType or "truck"
        if jobType == "minigame" then
            stopAllJobsClean(false)
            if MinigameJob then MinigameJob.Start(payload) end
        elseif jobType == "kanji_jawa" or jobType == "barista" then
            stopAllJobsClean(false)
            if KanjiJawaJob then KanjiJawaJob.Start() end
        else
            stopAllJobsClean(false)
            if TruckJob then TruckJob.Start() end
        end
        return true

    elseif action == "STOP_FARM" then
        stopAllJobsClean(true)
        if Context and Context.SendLog then
            Context.SendLog("Semua pekerjaan dihentikan. Resign ke Unemployed & karakter di-respawn.", "WARN")
        end
        return true

    elseif action == "START_MINIGAME_FARM" then
        stopAllJobsClean(false)
        if MinigameJob then MinigameJob.Start(payload) end
        return true

    elseif action == "STOP_MINIGAME_FARM" then
        if MinigameJob then MinigameJob.Stop() end
        resignJobUnemployed()
        task.defer(function()
            task.wait(0.3)
            respawnPlayerCharacter()
        end)
        return true

    elseif action == "SET_MINIGAME_CONFIG" then
        if MinigameJob and payload then
            if MinigameJob.SetConfig then
                MinigameJob.SetConfig(payload)
            else
                if payload.role and MinigameJob.SetRole then MinigameJob.SetRole(payload.role) end
            end
        end
        return true

    elseif action == "SET_MINIGAME_ROLE" then
        if MinigameJob and payload and payload.role then
            if MinigameJob.SetRole then
                MinigameJob.SetRole(payload.role)
            else
                MinigameJob.Start({ role = payload.role })
            end
        end
        return true

    elseif action == "BUY_MINIGAME_BOX" then
        if MinigameJob then MinigameJob.BuyBox() end
        return true

    elseif action == "START_KANJI_JAWA_FARM" or action == "START_BARISTA_FARM" then
        stopAllJobsClean(false)
        if KanjiJawaJob then KanjiJawaJob.Start() end
        return true

    elseif action == "STOP_KANJI_JAWA_FARM" or action == "STOP_BARISTA_FARM" then
        if KanjiJawaJob then KanjiJawaJob.Stop() end
        resignJobUnemployed()
        task.defer(function()
            task.wait(0.3)
            respawnPlayerCharacter()
        end)
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

    elseif action == "TOGGLE_STREAMER_MODE" then
        if StreamerModeFeature then
            local enable = (payload and payload.enabled ~= nil) and payload.enabled or not StreamerModeFeature.Enabled
            local spoofName = (payload and payload.spoofedName) or StreamerModeFeature.SpoofedName
            StreamerModeFeature.SetEnabled(enable, spoofName, Context)
        end
        return true

    elseif action == "SET_SPOOFED_NAME" then
        if StreamerModeFeature and payload and payload.spoofedName then
            StreamerModeFeature.SetEnabled(true, payload.spoofedName, Context)
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
    local isMinigameFarming = (stMg.IsFarming == true) or (stMg.AutoFarmActive == true)
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

    local truckDuration = (st.IsFarming and st.FarmStartTime and st.FarmStartTime > 0) and math.floor(os.clock() - st.FarmStartTime) or 0
    local baristaDuration = (stKj.IsFarming and stKj.FarmStartTime and stKj.FarmStartTime > 0) and math.floor(os.clock() - stKj.FarmStartTime) or 0
    local minigameDuration = (stMg.IsFarming and stMg.FarmStartTime and stMg.FarmStartTime > 0) and math.floor(os.time() - stMg.FarmStartTime) or 0

    local placeName = getPlaceName()
    local dynamicJob = "Unemployed"
    if stMg.IsFarming then
        dynamicJob = "Minigame (" .. (stMg.Role or "Winner") .. ")"
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
            streamerMode = (StreamerModeFeature and StreamerModeFeature.Enabled == true) or false,
        },
        config = {
            minigameRole = stMg.Role or "Winner",
            emergencyAction = (SafetyFeature and SafetyFeature.EmergencyAction) or "Warn Only",
            ignoreFriends = (SafetyFeature and SafetyFeature.IgnoreFriends ~= false),
            spoofedName = (StreamerModeFeature and StreamerModeFeature.SpoofedName) or "Warga_Sipil",
        },
        status = isTruckFarming and (st.Status or "CONNECTED") or (isKanjiFarming and (stKj.Phase or "RUNNING") or (isMinigameFarming and (stMg.Phase or "RUNNING") or "CONNECTED")),
        job = dynamicJob,
        placeName = placeName,
        gameName = placeName,
        currentRoute = isTruckFarming and (st.CurrentRoute or "IDLE") or (stMg.IsFarming and ("Arena Minigame: " .. (stMg.Phase or "Lobby")) or (stKj.IsFarming and ("Kanji Jiwa: " .. (stKj.Phase or "Standby")) or "IDLE")),
        tripCount = st.TripCount or 0,
        truckEarnings = st.IsFarming and (st.TotalEarnings or 0) or (st.TripCount and st.TripCount > 0 and (st.TotalEarnings or 0) or 0),
        totalEarnings = (st.IsFarming and (st.TotalEarnings or 0) or 0) + (stMg.IsFarming and (stMg.CashEarned or 0) or 0) + (stKj.IsFarming and (stKj.TotalEarned or 0) or 0),
        currentCash = (st.CurrentCash and st.CurrentCash > 0) and st.CurrentCash or ((stMg.CurrentCash and stMg.CurrentCash > 0) and stMg.CurrentCash or (stKj.CurrentCash or 0)),
        startCash = st.StartCash or 0,
        isFarming = isFarming,
        truck = {
            isFarming = isTruckFarming,
            status = isTruckFarming and (st.Status or "CONNECTED") or "Standby",
            currentRoute = isTruckFarming and (st.CurrentRoute or "IDLE") or "IDLE",
            tripCount = st.TripCount or 0,
            earnings = (st.IsFarming or (st.TripCount and st.TripCount > 0)) and (st.TotalEarnings or 0) or 0,
            speed = isTruckFarming and (st.Speed or 0) or 0,
            distRemaining = isTruckFarming and (st.DistRemaining or "0m") or "0m",
            duration = truckDuration
        },
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
            lastResult = stMg.LastMatchResult or "-",
            duration = minigameDuration
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
            currentOrder = stKj.CurrentOrder or {},
            duration = baristaDuration
        },
        jobProgress = JobProgressFeature and JobProgressFeature.GetProgressData("Barista") or nil,
        speed = isTruckFarming and (st.Speed or 0) or 0,
        distRemaining = isTruckFarming and (st.DistRemaining or "0m") or "0m",
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
