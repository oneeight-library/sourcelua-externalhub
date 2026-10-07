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
