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
