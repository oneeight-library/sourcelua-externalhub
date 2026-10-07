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
