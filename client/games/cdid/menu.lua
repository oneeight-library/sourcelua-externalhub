--[[
    OneEight External Hub - CDID Main Menu & Server Gateway Module
    Active when player is in CDID Main Menu / Lobby (PlaceId: 6911148748).
    Handles:
    - Quick map selection & teleport to Jawa Timur, Jakarta, etc.
    - Free Private Server generation & Public join
    - Auto-Enter Jawa Timur (crucial for unattended 24/7 farming)
--]]

local CDIDMenu = {}
CDIDMenu.GameId = "cdid_menu"
CDIDMenu.GameName = "CDID Main Menu"
CDIDMenu.CurrencyUnit = "Rp"
CDIDMenu.MetricUnit = "Maps"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

local Context = nil
local State = {
    Status = "LOBBY_READY",
    AutoJoinJatim = true,
    CurrentServerCode = "",
    SelectedMap = "JawaTimur",
    AutoJoinTimer = 5
}

local CDID_MAPS = {
    { Key = "JawaTimur",   Name = "Jawa Timur",   PlaceId = 110369730911937, Desc = "Pusat Truck Cargo Auto Farm", Icon = "truck", Primary = true },
    { Key = "Jakarta",     Name = "Jakarta",      PlaceId = 14005966837,     Desc = "Kurir BCA & Cafe Kanji Jawa",  Icon = "building" },
    { Key = "Bandung",     Name = "Bandung",      PlaceId = 79488788685813,  Desc = "Kota Kembang",                Icon = "compass" },
    { Key = "JawaBarat",   Name = "Jawa Barat",   PlaceId = 9233343468,      Desc = "Tol & Pegunungan",            Icon = "compass" },
    { Key = "JawaTengah",  Name = "Jawa Tengah",  PlaceId = 9508940498,      Desc = "Semarang & Solo",             Icon = "compass" },
    { Key = "Bali",        Name = "Bali",         PlaceId = 118108582994420, Desc = "Pulau Dewata",               Icon = "palm-tree" },
    { Key = "Seasonal",    Name = "Seasonal",     PlaceId = 132986577553100, Desc = "Event Khusus",               Icon = "sparkles" }
}

-- Native CDID Network Helper
local function getCDIDNetwork()
    local net = nil
    pcall(function()
        local shared = ReplicatedStorage:FindFirstChild("Shared")
        if shared and shared:FindFirstChild("Network") then
            net = require(shared.Network)
        end
    end)
    return net
end

-- Helper Trigger Native Map Select (100% OneEight Hub Compatible)
local function selectMapNative(mapKey)
    -- 1. Sync ke Controller UIAnimation CDID (OneEight Hub exact method)
    pcall(function()
        local controller = ReplicatedStorage:FindFirstChild("Controller")
        if controller and controller:FindFirstChild("UIAnimation") then
            local uiMod = require(controller.UIAnimation)
            if uiMod then
                uiMod.SelectedMap = mapKey
            end
        end
    end)

    -- 2. Trigger tombol map di PlayerGui.Hub
    pcall(function()
        local mapWin = LocalPlayer.PlayerGui.Hub.Container.Window:FindFirstChild("MapSelection")
        local targetMapFrame = mapWin and mapWin:FindFirstChild(mapKey)
        local btn = targetMapFrame and targetMapFrame:FindFirstChild("TextButton")
        if btn then
            local conns = getconnections and getconnections(btn.MouseButton1Down) or {}
            for _, c in ipairs(conns) do
                if c.Function then pcall(c.Function) end
            end
            if typeof(firesignal) == "function" then
                pcall(firesignal, btn.MouseButton1Down)
            end
        end
    end)
end

-- Helper Join Map With Server Code / Public
local function joinMap(mapKey, serverCode)
    State.Status = "JOINING_" .. string.upper(mapKey)
    if Context and Context.SendLog then
        Context.SendLog("Menghubungkan ke server map: " .. tostring(mapKey) .. "...", "WARN")
    end

    -- Setup queue_on_teleport agar loader kembali jalan di server map tujuan
    local queue_teleport = (syn and syn.queue_on_teleport) or queue_on_teleport or (fluxus and fluxus.queue_on_teleport)
    if queue_teleport then
        pcall(function()
            queue_teleport([[
                task.wait(4)
                loadstring(game:HttpGet("https://externalhub.oneeight-project18.workers.dev/loader"))()
            ]])
        end)
    end

    selectMapNative(mapKey)
    task.wait(0.3)

    -- Pemicu 1: Klik tombol Join bawaan UI CDID
    pcall(function()
        local ps = LocalPlayer.PlayerGui.Hub.Container.Window.PrivateServer
        if ps and ps:FindFirstChild("ServerLabel") and serverCode and #serverCode > 0 then
            ps.ServerLabel.Text = tostring(serverCode)
        end

        local joinBtn = ps and ps:FindFirstChild("JoinButton") and ps.JoinButton:FindFirstChild("TextButton")
        if joinBtn then
            local conns = getconnections and getconnections(joinBtn.MouseButton1Down) or {}
            for _, c in ipairs(conns) do
                if c.Function then pcall(c.Function) end
            end
            if typeof(firesignal) == "function" then
                pcall(firesignal, joinBtn.MouseButton1Down)
            end
        end
    end)

    -- Pemicu 2: Native Network Remote CDID
    local net = getCDIDNetwork()
    if net and net.FireServer then
        pcall(function()
            net:FireServer("PrivateServer", "Join", tostring(serverCode or ""), mapKey)
        end)
    end

    -- Pemicu 3: TeleportService Fallback jika remote gagal
    task.wait(1.5)
    local targetPlaceId = nil
    for _, m in ipairs(CDID_MAPS) do
        if m.Key == mapKey then
            targetPlaceId = m.PlaceId
            break
        end
    end
    if targetPlaceId then
        pcall(function()
            TeleportService:Teleport(targetPlaceId, LocalPlayer)
        end)
    end
end

function CDIDMenu.Init(coreContext)
    Context = coreContext
    print("[OE-External CDID] Modul Main Menu / Lobby CDID aktif!")

    -- Auto-Enter Jawa Timur jika diaktifkan (Hitung mundur 5 detik)
    if State.AutoJoinJatim then
        task.spawn(function()
            for s = 5, 1, -1 do
                if not State.AutoJoinJatim then break end
                State.Status = string.format("AUTO_ENTER_JATIM (%ds)", s)
                task.wait(1)
            end
            if State.AutoJoinJatim then
                State.Status = "ENTERING_JAWA_TIMUR"
                joinMap("JawaTimur")
            end
        end)
    end
end

function CDIDMenu.HandleCommand(action, payload)
    if action == "JOIN_MAP" then
        local mapKey = payload and payload.mapKey or "JawaTimur"
        local code = payload and payload.code or ""
        joinMap(mapKey, code)
        return true

    elseif action == "TOGGLE_AUTO_JOIN_JATIM" then
        State.AutoJoinJatim = not State.AutoJoinJatim
        if Context and Context.SendLog then
            Context.SendLog("Auto-Enter Jawa Timur: " .. (State.AutoJoinJatim and "AKTIF" or "NONAKTIF"), "INFO")
        end
        return true
    end
    return false
end

function CDIDMenu.GetTelemetry()
    return {
        status = State.Status,
        isLobby = true,
        autoJoinJatim = State.AutoJoinJatim,
        selectedMap = State.SelectedMap,
        currentRoute = "Di Lobi (Pilih Map)",
        tripCount = 0,
        totalEarnings = 0,
        currentCash = 0
    }
end

function CDIDMenu.Cleanup()
    State.AutoJoinJatim = false
end

return CDIDMenu
