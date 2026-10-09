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

function CDIDModule.Init(coreContext)
    Context = coreContext

    -- Load sub-modul
    LightingFeature = requireModule("games/cdid/features/lighting")
    SafetyFeature = requireModule("games/cdid/features/safety")
    DealershipFeature = requireModule("games/cdid/features/dealership")
    TeleportFeature = requireModule("games/cdid/features/teleport")
    TruckJob = requireModule("games/cdid/jobs/truck")
    MinigameJob = requireModule("games/cdid/jobs/minigames")

    TruckJob.Init(coreContext)
    if MinigameJob and MinigameJob.Init then MinigameJob.Init(coreContext) end
    if SafetyFeature and SafetyFeature.CheckCurrentLockState then
        pcall(SafetyFeature.CheckCurrentLockState)
    end
    print("[OE-External CDID] Modular Coordinator Berhasil Diinisialisasi!")

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
        else
            if TruckJob then TruckJob.Start() end
        end
        return true

    elseif action == "STOP_FARM" then
        if TruckJob then TruckJob.Stop() end
        if MinigameJob then MinigameJob.Stop() end
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
    local isFarming = (st.IsFarming or stMg.IsFarming) or false
    local elapsedSec = 0
    if st.IsFarming and st.FarmStartTime and st.FarmStartTime > 0 then
        elapsedSec = math.floor(os.clock() - st.FarmStartTime)
    elseif stMg.IsFarming and stMg.FarmStartTime and stMg.FarmStartTime > 0 then
        elapsedSec = math.floor(os.time() - stMg.FarmStartTime)
    end
    local placeName = getPlaceName()
    local dynamicJob = "Unemployed"
    if stMg.IsFarming then
        dynamicJob = "Minigames Sumo (" .. (stMg.Role or "Winner") .. ")"
    elseif st.IsFarming then
        dynamicJob = "Truk Kargo"
    end
    return {
        status = stMg.IsFarming and (stMg.Phase or "RUNNING") or (st.Status or "CONNECTED"),
        job = dynamicJob,
        placeName = placeName,
        gameName = placeName,
        currentRoute = stMg.IsFarming and ("Sumo Arena: " .. (stMg.Phase or "Lobby")) or (st.CurrentRoute or "IDLE"),
        tripCount = st.TripCount or 0,
        totalEarnings = (st.TotalEarnings or 0) + (stMg.CashEarned or 0),
        currentCash = (st.CurrentCash and st.CurrentCash > 0) and st.CurrentCash or (stMg.CurrentCash or 0),
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
end

return CDIDModule
