--[[
    OneEight External Hub - CDID Main Menu & Server Gateway Module
    100% Exact Port of OneEight Hub Server Manager:
    - Realtime multi-source private server code detection (UI, GC Replica, NetworkEvent)
    - Free private server code generation (Network:FireServer("PrivateServer", "Create"))
    - Native map selection & controller synchronization (UIAnimation.SelectedMap)
    - Full bidirectional server code sync with Web Dashboard
    - Auto-Enter Jawa Timur with auto-code fallback & queue_on_teleport
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
    AutoJoinJatim = false,
    CurrentServerCode = "",
    SelectedMap = "JawaTimur",
    AutoJoinTimer = 5,
    CodeSource = "None"
}

local CDID_MAPS = {
    { Key = "JawaTimur",   Name = "Jawa Timur",   PlaceId = 110369730911937, Desc = "Pusat Truck Cargo Auto Farm", Icon = "truck", Primary = true },
    { Key = "Jakarta",     Name = "Jakarta",      PlaceId = 14005966837,     Desc = "Kurir BCA & Kanji Jiwa",  Icon = "building" },
    { Key = "Bandung",     Name = "Bandung",      PlaceId = 79488788685813,  Desc = "Kota Kembang",                Icon = "compass" },
    { Key = "JawaBarat",   Name = "Jawa Barat",   PlaceId = 9233343468,      Desc = "Tol & Pegunungan",            Icon = "compass" },
    { Key = "JawaTengah",  Name = "Jawa Tengah",  PlaceId = 9508940498,      Desc = "Semarang & Solo",             Icon = "compass" },
    { Key = "Bali",        Name = "Bali",         PlaceId = 118108582994420, Desc = "Pulau Dewata",               Icon = "palm-tree" },
    { Key = "Seasonal",    Name = "Seasonal",     PlaceId = 132986577553100, Desc = "Event Khusus",               Icon = "sparkles" }
}

-- Native CDID Network Helper
local CDID_Network = nil
local CDID_UIAnimation = nil

local function getCDIDNetwork()
    if CDID_Network then return CDID_Network end
    pcall(function()
        local shared = ReplicatedStorage:FindFirstChild("Shared")
        if shared and shared:FindFirstChild("Network") then
            CDID_Network = require(shared.Network)
        end
    end)
    return CDID_Network
end

local function getRealUIAnimation()
    local success, result = pcall(function()
        for _, v in ipairs(getgc(true)) do
            if type(v) == "table" and rawget(v, "SelectedMap") and rawget(v, "WindowModule") then
                return v
            end
        end
    end)
    return success and result or nil
end

-- ============================================================================
-- VALIDASI & PENERAPAN KODE SERVER (ONE-EIGHT HUB ALGORITHM)
-- ============================================================================
local function isValidServerCode(text)
    if not text or type(text) ~= "string" then return false end
    local clean = text:gsub("%s+", "")
    if clean == "" or clean == "ServerLabel" or clean == "nil" or clean == "InsertHere" then return false end
    local lower = clean:lower()
    if lower:find("ms") or lower:find("fps") or lower:find("singapore")
        or lower:find("unitedstates") or lower:find("indonesia") or lower:find(",") then
        return false
    end
    return (clean:len() >= 4 and clean:len() <= 35)
end

local function applyServerCode(code, source)
    if not isValidServerCode(code) then return false end
    local clean = tostring(code):gsub("%s+", "")
    if clean == State.CurrentServerCode then return false end

    State.CurrentServerCode = clean
    State.CodeSource = source or "Unknown"
    _G.OE_PRIVATE_SERVER_CODE = clean
    
    print(string.format("[OE-External CDID] 🔑 Kode Server Terdeteksi [%s]: %s", State.CodeSource, State.CurrentServerCode))

    if Context and Context.SendLog then
        Context.SendLog(string.format("Kode Server CDID terdeteksi (%s): %s", State.CodeSource, State.CurrentServerCode), "SUCCESS")
    end

    -- Update ke GUI CDID jika ada
    pcall(function()
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        local ps = pGui and pGui:FindFirstChild("Hub") and pGui.Hub.Container.Window:FindFirstChild("PrivateServer")
        if ps and ps:FindFirstChild("ServerLabel") then
            ps.ServerLabel.Text = State.CurrentServerCode
        end
    end)

    return true
end

-- ============================================================================
-- MULTI-SOURCE SCANNER (EXACT ONE-EIGHT HUB METHOD)
-- ============================================================================
local function scanAllSources()
    -- Sumber 1: Real UIAnimation dari GC
    local realUI = getRealUIAnimation()
    if realUI and realUI.WindowModule then
        local ps = realUI.WindowModule.PrivateServer
        if ps and ps.ServerLabel and isValidServerCode(ps.ServerLabel.Text) then
            return applyServerCode(ps.ServerLabel.Text, "UIAnimation")
        end
    end

    -- Sumber 2: Recursive scan di PlayerGui untuk ServerLabel
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    if pGui then
        for _, inst in ipairs(pGui:GetDescendants()) do
            if (inst:IsA("TextLabel") or inst:IsA("TextBox")) and inst.Name == "ServerLabel" then
                if isValidServerCode(inst.Text) then
                    return applyServerCode(inst.Text, "PlayerGui.ServerLabel")
                end
            end
        end
    end

    -- Sumber 3: ReplicaService Player Data State (GC scan)
    local replicaCode = nil
    pcall(function()
        for _, v in ipairs(getgc(true)) do
            if type(v) == "table" and type(rawget(v, "Class")) == "string" and rawget(v, "Class"):find("^Player_") and rawget(v, "Data") then
                local data = rawget(v, "Data")
                if data and data.PrivateServer and data.PrivateServer.Code and isValidServerCode(data.PrivateServer.Code) then
                    replicaCode = data.PrivateServer.Code
                    break
                end
            end
        end
    end)
    if replicaCode then
        return applyServerCode(replicaCode, "GCReplicaScan")
    end

    -- Sumber 4: Global Variable & Persisten File (Auto-Rejoin Bridge)
    local persistentCode = nil
    if _G.OE_PRIVATE_SERVER_CODE and isValidServerCode(_G.OE_PRIVATE_SERVER_CODE) then
        persistentCode = _G.OE_PRIVATE_SERVER_CODE
    elseif typeof(readfile) == "function" then
        pcall(function()
            if (typeof(isfile) == "function" and isfile("oe_cdid_ps_code.txt")) or true then
                local saved = readfile("oe_cdid_ps_code.txt")
                if isValidServerCode(saved) then
                    persistentCode = saved
                end
            end
        end)
    end
    if persistentCode then
        return applyServerCode(persistentCode, "PersistentFileOrGlobal")
    end

    return false
end

-- Request kode baru dari server game CDID
local function requestServerCode()
    print("[OE-External CDID] 🔄 Meminta pembuatan kode server private baru...")
    if Context and Context.SendLog then
        Context.SendLog("Meminta server CDID untuk generate kode private baru...", "INFO")
    end

    local triggered = false
    pcall(function()
        local ps = LocalPlayer.PlayerGui.Hub.Container.Window.PrivateServer
        local genBtn = ps and ps:FindFirstChild("GenerateButton") and ps.GenerateButton:FindFirstChild("TextButton")
        if genBtn then
            local conns = getconnections and getconnections(genBtn.MouseButton1Down) or {}
            for _, c in ipairs(conns) do
                if c.Function then
                    pcall(c.Function)
                    triggered = true
                end
            end
            if not triggered and typeof(firesignal) == "function" then
                firesignal(genBtn.MouseButton1Down)
                triggered = true
            end
        end
    end)

    local net = getCDIDNetwork()
    if not triggered and net and net.FireServer then
        pcall(function()
            net:FireServer("PrivateServer", "Create")
        end)
    end

    -- Polling agresif selama 5 detik
    for _ = 1, 15 do
        task.wait(0.3)
        if scanAllSources() then
            return State.CurrentServerCode
        end
    end
    return State.CurrentServerCode
end

-- ============================================================================
-- MAP SELECTION & JOIN DISPATCHER
-- ============================================================================
local function selectMapNative(mapKey)
    State.SelectedMap = mapKey

    -- 1. Klik tombol map asli di UI CDID (MouseButton1Down & Activated)
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
            local actConns = getconnections and getconnections(btn.Activated) or {}
            for _, c in ipairs(actConns) do
                if c.Function then pcall(c.Function) end
            end
        end
    end)

    -- 2. Sync ke real UIAnimation di GC & SetMapSelected
    local realUI = getRealUIAnimation()
    if realUI then
        realUI.SelectedMap = mapKey
        pcall(function()
            if realUI.WindowModule and realUI.WindowModule.HubContainer and realUI.WindowModule.HubContainer.SetMapSelected then
                realUI.WindowModule.HubContainer:SetMapSelected(mapKey:upper())
            end
        end)
    end

    -- 3. Sync ke Controller UIAnimation CDID
    pcall(function()
        local controller = ReplicatedStorage:FindFirstChild("Controller")
        if controller and controller:FindFirstChild("UIAnimation") then
            local uiMod = require(controller.UIAnimation)
            if uiMod then uiMod.SelectedMap = mapKey end
        end
    end)
end

local function joinMap(mapKey, serverCode)
    mapKey = mapKey or State.SelectedMap or "JawaTimur"
    State.Status = "JOINING_" .. string.upper(mapKey)

    -- Setup queue_on_teleport agar loader kembali berjalan di server tujuan (Maksimal 1 kali agar tidak menumpuk)
    if not _G.OE_TeleportQueued then
        _G.OE_TeleportQueued = true
        local queue_teleport = (syn and syn.queue_on_teleport) or queue_on_teleport or (fluxus and fluxus.queue_on_teleport) or queueonteleport
        if queue_teleport then
            pcall(function()
                queue_teleport([[
                    task.wait(3.5)
                    loadstring(game:HttpGet("https://externalhub.oneeight-project18.workers.dev/loader"))()
                ]])
            end)
        end
    end

    -- 1. Pastikan Kode Server Terisi
    local codeToUse = serverCode
    if not codeToUse or codeToUse == "" then
        codeToUse = State.CurrentServerCode
    end

    if not codeToUse or codeToUse == "" then
        scanAllSources()
        codeToUse = State.CurrentServerCode
    end

    -- Jika masih belum ada, minta server buatkan kode otomatis sekarang juga
    if not codeToUse or codeToUse == "" then
        codeToUse = requestServerCode()
    end

    print(string.format("[OE-External CDID] 🚀 Melakukan Join ke %s dengan Kode: '%s'...", mapKey, tostring(codeToUse)))
    if Context and Context.SendLog then
        Context.SendLog(string.format("Menghubungkan ke %s (Kode: %s)...", mapKey, tostring(codeToUse)), "WARN")
    end

    selectMapNative(mapKey)
    task.wait(0.5)

    -- Pemicu 1: Klik tombol Join asli game via connections
    pcall(function()
        local ps = LocalPlayer.PlayerGui.Hub.Container.Window.PrivateServer
        if ps and ps:FindFirstChild("ServerLabel") and codeToUse and #codeToUse > 0 then
            ps.ServerLabel.Text = tostring(codeToUse)
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
            local actConns = getconnections and getconnections(joinBtn.Activated) or {}
            for _, c in ipairs(actConns) do
                if c.Function then pcall(c.Function) end
            end
        end
    end)

    -- Pemicu 2: Backup langsung via Network Remote
    local net = getCDIDNetwork()
    if net and net.FireServer and codeToUse and codeToUse ~= "" then
        pcall(function()
            net:FireServer("PrivateServer", "Join", tostring(codeToUse), mapKey)
        end)
    end
end

-- ============================================================================
-- MODUL INIT & BACKGROUND LISTENERS
-- ============================================================================
function CDIDMenu.Init(coreContext)
    Context = coreContext
    print("[OE-External CDID] Modul Main Menu / Lobby CDID aktif!")



    -- Initial scan kode server
    scanAllSources()

    -- Hook Remote Network jika sudah siap
    task.spawn(function()
        local net = getCDIDNetwork()
        if net and net.OnClientEvent then
            pcall(function()
                net.OnClientEvent("PrivateServer", function(action, arg1)
                    if isValidServerCode(arg1) then
                        applyServerCode(arg1, "NetworkEvent")
                    elseif isValidServerCode(action) then
                        applyServerCode(action, "NetworkEvent")
                    end
                end)
            end)
        end
    end)

    -- Realtime Hook pada PlayerGui ServerLabel
    task.spawn(function()
        local pGui = LocalPlayer:WaitForChild("PlayerGui", 10)
        if not pGui then return end

        local function checkInst(inst)
            if (inst:IsA("TextLabel") or inst:IsA("TextBox")) and inst.Name == "ServerLabel" then
                if isValidServerCode(inst.Text) then
                    applyServerCode(inst.Text, "ServerLabelHook")
                end
                inst:GetPropertyChangedSignal("Text"):Connect(function()
                    if isValidServerCode(inst.Text) then
                        applyServerCode(inst.Text, "ServerLabelChange")
                    end
                end)
            end
        end

        for _, inst in ipairs(pGui:GetDescendants()) do checkInst(inst) end
        pGui.DescendantAdded:Connect(checkInst)
    end)

    -- Background scanner berkala tiap 3 detik
    task.spawn(function()
        while _G.OE_ExternalRunning do
            task.wait(3)
            if State.CurrentServerCode == "" then
                scanAllSources()
            end
        end
    end)

    -- Auto-Enter Jawa Timur dinonaktifkan (User memegang kendali penuh)
    -- Bot tetap standby di lobi dan memindai kode server secara damai
    task.spawn(function()
        task.wait(1.5)
        if State.CurrentServerCode == "" then
            scanAllSources()
        end
    end)
end

function CDIDMenu.HandleCommand(action, payload)
    if action == "JOIN_MAP" then
        local mapKey = payload and payload.mapKey or "JawaTimur"
        local code = payload and payload.code or State.CurrentServerCode
        joinMap(mapKey, code)
        return true

    elseif action == "GENERATE_SERVER_CODE" then
        task.spawn(function()
            requestServerCode()
        end)
        return true

    elseif action == "SET_SERVER_CODE" then
        if payload and payload.code then
            applyServerCode(payload.code, "WebInput")
        end
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
        job = "Server Gateway",
        placeName = "CDID Main Menu",
        gameName = "CDID Main Menu",
        autoJoinJatim = State.AutoJoinJatim,
        selectedMap = State.SelectedMap,
        serverCode = State.CurrentServerCode,
        codeSource = State.CodeSource,
        currentRoute = "Di Lobi (Kode: " .. (State.CurrentServerCode ~= "" and State.CurrentServerCode or "Belum Ada") .. ")",
        tripCount = 0,
        totalEarnings = 0,
        currentCash = 0
    }
end

function CDIDMenu.Cleanup()
    State.AutoJoinJatim = false
end

return CDIDMenu
