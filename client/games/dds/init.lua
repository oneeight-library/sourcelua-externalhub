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
