--[[
    CDID Feature: Safety, Anti-Staff & Server Lock (100% Native In-Game Sync)
--]]
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SafetyFeature = {
    PlayerDetectorEnabled = false,
    EmergencyAction = "Warn Only",
    IgnoreFriends = true,
    ServerLocked = false, -- Default false (terbuka), sesuai state awal in-game
    Connection = nil
}

local function GetPrivateServerRemote()
    local net = ReplicatedStorage:FindFirstChild("NetworkContainer")
    if net then
        local remotes = net:FindFirstChild("RemoteEvents")
        if remotes then
            local ps = remotes:FindFirstChild("Private Server") or remotes:FindFirstChild("PrivateServer")
            if ps then return ps end
        end
    end

    for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
        if desc:IsA("RemoteEvent") and (desc.Name == "Private Server" or desc.Name == "PrivateServer") then
            return desc
        end
    end
    return nil
end

local function TriggerNativeCDIDToggle(enable)
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    local panel = pGui and pGui:FindFirstChild("PrivateServerPanel")
    local serverFrame = panel and panel:FindFirstChild("MainFrame") and panel.MainFrame:FindFirstChild("Main") and panel.MainFrame.Main:FindFirstChild("Server")

    if serverFrame then
        for _, c in ipairs(serverFrame:GetChildren()) do
            local title = c:FindFirstChild("OptionTitle")
            if title and title.Text == "Server Lock" then
                local toggleBtn = c:FindFirstChild("ToggleButton")
                local switch = toggleBtn and toggleBtn:FindFirstChild("ToggleSwitch")

                -- Cek posisi saat ini: 0.05 = OFF, 0.52 = ON
                local isCurrentlyOn = switch and (switch.Position.X.Scale > 0.3)
                local conns = (typeof(getconnections) == "function" and getconnections(toggleBtn.MouseButton1Down)) or {}

                if #conns > 0 and conns[1].Function then
                    if isCurrentlyOn ~= enable then
                        local ok = pcall(conns[1].Function)
                        if ok then return true end
                    end

                    local ups = typeof(debug.getupvalues) == "function" and debug.getupvalues(conns[1].Function)
                    if ups and typeof(ups[4]) == "function" then
                        local ok = pcall(ups[4], "Server Lock", enable and "Enable" or "Disable")
                        if ok then return true end
                    end
                end
            end
        end
    end
    return false
end

function SafetyFeature.CheckCurrentLockState()
    pcall(function()
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        local panel = pGui and pGui:FindFirstChild("PrivateServerPanel")
        local serverFrame = panel and panel:FindFirstChild("MainFrame") and panel.MainFrame:FindFirstChild("Main") and panel.MainFrame.Main:FindFirstChild("Server")
        if serverFrame then
            for _, c in ipairs(serverFrame:GetChildren()) do
                local title = c:FindFirstChild("OptionTitle")
                if title and title.Text == "Server Lock" then
                    local toggleBtn = c:FindFirstChild("ToggleButton")
                    local switch = toggleBtn and toggleBtn:FindFirstChild("ToggleSwitch")
                    if switch then
                        SafetyFeature.ServerLocked = (switch.Position.X.Scale > 0.3)
                    end
                end
            end
        end
    end)
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

    -- Vector 1: Native CDID toggle
    local nativeOk = TriggerNativeCDIDToggle(enable)

    -- Vector 2: RemoteEvent CDID: serverlock (Lock) atau serverunlock (Unlock)
    local psRemote = GetPrivateServerRemote()
    if psRemote then
        pcall(function()
            if enable then
                psRemote:FireServer("serverlock", {})
            else
                psRemote:FireServer("serverunlock", {})
            end
        end)
    end

    SafetyFeature.ServerLocked = enable

    if Context and Context.SendLog then
        Context.SendLog(string.format("Private Server Lock: %s", enable and "TERKUNCI 🔒" or "TERBUKA 🔓"), "INFO")
    end
end

return SafetyFeature
