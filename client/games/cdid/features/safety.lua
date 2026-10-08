--[[
    CDID Feature: Safety, Anti-Staff & Server Lock
--]]
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SafetyFeature = {
    PlayerDetectorEnabled = false,
    EmergencyAction = "Warn Only",
    IgnoreFriends = true,
    ServerLocked = true, -- Default true karena private server CDID otomatis terkunci saat join
    Connection = nil
}

function SafetyFeature.CheckCurrentLockState()
    local detectedState = nil
    pcall(function()
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        local panel = pGui and pGui:FindFirstChild("PrivateServerPanel")
        local serverFrame = panel and panel:FindFirstChild("MainFrame") and panel.MainFrame:FindFirstChild("Main") and panel.MainFrame.Main:FindFirstChild("Server")
        if serverFrame then
            for _, c in ipairs(serverFrame:GetChildren()) do
                local title = c:FindFirstChild("OptionTitle")
                if title and title.Text:lower():find("server%s*lock") then
                    local toggleBtn = c:FindFirstChild("ToggleButton") or c:FindFirstChildWhichIsA("TextButton") or c:FindFirstChildWhichIsA("ImageButton")
                    if toggleBtn then
                        local val = toggleBtn:FindFirstChildWhichIsA("BoolValue") or c:FindFirstChildWhichIsA("BoolValue")
                        if val then
                            detectedState = val.Value
                        end
                        if detectedState == nil and toggleBtn:IsA("GuiObject") then
                            local bg = toggleBtn.BackgroundColor3
                            if bg.G > 0.5 and bg.G > bg.R then
                                detectedState = true
                            elseif bg.R > 0.5 and bg.R > bg.G then
                                detectedState = false
                            end
                        end
                    end
                end
            end
        end
    end)
    if detectedState ~= nil then
        SafetyFeature.ServerLocked = detectedState
    end
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

    -- Jika state sudah sesuai, jangan di-toggle lagi agar tidak terbalik
    if SafetyFeature.ServerLocked == enable then
        if Context and Context.SendLog then
            Context.SendLog(string.format("Private Server Lock sudah %s.", enable and "TERKUNCI 🔒" or "TERBUKA 🔓"), "INFO")
        end
        return
    end

    SafetyFeature.ServerLocked = enable
    pcall(function()
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        local panel = pGui and pGui:FindFirstChild("PrivateServerPanel")
        local serverFrame = panel and panel:FindFirstChild("MainFrame") and panel.MainFrame:FindFirstChild("Main") and panel.MainFrame.Main:FindFirstChild("Server")
        local triggered = false
        if serverFrame then
            for _, c in ipairs(serverFrame:GetChildren()) do
                local title = c:FindFirstChild("OptionTitle")
                if title and title.Text:lower():find("server%s*lock") then
                    local toggleBtn = c:FindFirstChild("ToggleButton") or c:FindFirstChildWhichIsA("TextButton")
                    if toggleBtn then
                        local conns = (typeof(getconnections) == "function" and getconnections(toggleBtn.MouseButton1Down)) or {}
                        if #conns > 0 and conns[1].Function then
                            pcall(conns[1].Function)
                            triggered = true
                        end
                    end
                end
            end
        end

        if not triggered then
            local net = ReplicatedStorage:FindFirstChild("NetworkContainer")
            local remotes = net and net:FindFirstChild("RemoteEvents")
            local ps = remotes and (remotes:FindFirstChild("Private Server") or remotes:FindFirstChild("PrivateServer"))
            if ps then
                ps:FireServer("serverlock", {})
            end
        end
    end)

    if Context and Context.SendLog then
        Context.SendLog(string.format("Private Server Lock: %s", enable and "TERKUNCI 🔒" or "TERBUKA 🔓"), "INFO")
    end
end

return SafetyFeature
