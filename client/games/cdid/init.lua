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
end

return CDIDModule
