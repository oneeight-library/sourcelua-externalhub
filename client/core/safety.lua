--[[
    OneEight External Hub - Core Safety & Kick Detection Engine
    Handles:
    1. Anti-AFK (20-minute idle bypass)
    2. Real-time Kick / Disconnect detection (GuiService & RobloxPromptGui)
    3. Auto-Rejoin subsystem with queue_on_teleport
--]]

local Safety = {}
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

Safety.AutoRejoin = true
Safety.RejoinDelay = 5
Safety.IsKicked = false
Safety.KickReason = nil
Safety.OnKickedCallback = nil

-- 1. Anti-AFK (Native VirtualUser simulation)
function Safety.StartAntiAFK()
    LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.zero)
        end)
    end)
end

-- 2. Trigger Kick Handler
local function handleKick(reason)
    if Safety.IsKicked then return end
    Safety.IsKicked = true
    Safety.KickReason = reason or "Roblox Disconnected"

    warn("[OE-External Safety] DISCONNECT / KICK DETECTED: " .. tostring(Safety.KickReason))

    if Safety.OnKickedCallback then
        pcall(Safety.OnKickedCallback, Safety.KickReason)
    end

    if Safety.AutoRejoin then
        task.spawn(function()
            print(string.format("[OE-External Safety] Auto-Rejoin aktif! Menghubungkan ulang dalam %d detik...", Safety.RejoinDelay))
            task.wait(Safety.RejoinDelay)
            Safety.RejoinNow()
        end)
    end
end

-- 3. Install Kick & Error Dialog Listeners
function Safety.InitKickDetector(onKickedCallback)
    Safety.OnKickedCallback = onKickedCallback

    -- Listener A: GuiService ErrorMessageChanged
    pcall(function()
        GuiService.ErrorMessageChanged:Connect(function(errMsg)
            if errMsg and #errMsg > 0 then
                handleKick(errMsg)
            end
        end)
    end)

    -- Listener B: CoreGui RobloxPromptGui promptOverlay
    pcall(function()
        local promptGui = CoreGui:WaitForChild("RobloxPromptGui", 10)
        local overlay = promptGui and promptGui:WaitForChild("promptOverlay", 10)
        if overlay then
            overlay.ChildAdded:Connect(function(child)
                if child.Name == "ErrorPrompt" then
                    local msgLabel = child:FindFirstChild("ErrorMessage", true)
                    local msg = msgLabel and msgLabel.Text or "Roblox Disconnected"
                    handleKick(msg)
                end
            end)
        end
    end)

    -- Listener C: Teleport Failures
    pcall(function()
        TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errMsg)
            if player == LocalPlayer then
                handleKick("Teleport Gagal: " .. tostring(errMsg or teleportResult))
            end
        end)
    end)
end

-- 4. Rejoin Server Now (Private Server & CDID Gateway Aware)
function Safety.RejoinNow(loaderUrl)
    loaderUrl = loaderUrl or "https://externalhub.oneeight-project18.workers.dev/loader"

    local currentPlaceId = game.PlaceId
    local HttpService = game:GetService("HttpService")

    -- 1. Deteksi apakah ini game CDID dan berada di Private Server
    local CDID_PLACE_MAP = {
        [14005966837] = "Jakarta",
        [110369730911937] = "JawaTimur",
        [9233343468] = "JawaBarat",
        [9508940498] = "JawaTengah",
        [79488788685813] = "Bandung",
        [118108582994420] = "Bali",
        [132986577553100] = "Seasonal"
    }

    local currentMapKey = CDID_PLACE_MAP[currentPlaceId]
    local isCDID = (currentMapKey ~= nil) or (currentPlaceId == 6911148748)

    local psCode = nil
    pcall(function()
        if typeof(getgc) == "function" then
            for _, v in ipairs(getgc(true)) do
                if typeof(v) == "table" and rawget(v, "Code") and #tostring(rawget(v, "Code")) >= 4 and rawget(v, "Jakarta") then
                    psCode = tostring(rawget(v, "Code"))
                    break
                end
            end
        end
    end)

    if not psCode and _G.OE_PRIVATE_SERVER_CODE then
        psCode = _G.OE_PRIVATE_SERVER_CODE
    end

    if not psCode and typeof(readfile) == "function" then
        pcall(function()
            if typeof(isfile) == "function" and isfile("oe_cdid_ps_code.txt") then
                local saved = readfile("oe_cdid_ps_code.txt")
                if saved and #saved >= 4 then
                    psCode = saved
                end
            end
        end)
    end

    -- 2. Setup queue_on_teleport agar loader & connector otomatis aktif
    local queue_teleport = (syn and syn.queue_on_teleport) or queue_on_teleport or (fluxus and fluxus.queue_on_teleport) or queueonteleport
    if queue_teleport then
        pcall(function()
            queue_teleport(string.format([[
                task.wait(2)
                pcall(function()
                    loadstring(game:HttpGet("http://localhost:16384/script.luau"))()
                end)
                task.wait(2)
                pcall(function()
                    loadstring(game:HttpGet("%s"))()
                end)
            ]], loaderUrl))
        end)
    end

    -- 3. Logika Rejoin CDID Private Server
    -- Di CDID, Private Server adalah Reserved Server. Roblox memblokir TeleportToPlaceInstance langsung dari client (Error 773).
    -- Jalur resmi & 100%% berhasil masuk ke Private Server CDID adalah melalui Lobby Gateway (PlaceId: 6911148748).
    if isCDID and psCode and currentMapKey and currentPlaceId ~= 6911148748 then
        print(string.format("[OE-External Safety] CDID Private Server terdeteksi (Kode: %s, Map: %s). Menjadwalkan gateway rejoin via Lobby...", tostring(psCode), currentMapKey))

        pcall(function()
            if typeof(writefile) == "function" then
                writefile("oe_cdid_ps_code.txt", tostring(psCode))
                writefile("oe_cdid_rejoin_target.json", HttpService:JSONEncode({
                    code = tostring(psCode),
                    map = currentMapKey
                }))
            end
        end)
        _G.OE_PRIVATE_SERVER_CODE = psCode

        print("[OE-External Safety] Berpindah ke CDID Main Menu untuk routing ke Private Server...")
        TeleportService:Teleport(6911148748, LocalPlayer)
        return
    end

    -- 4. Fallback jika bukan CDID Private Server atau sudah di Lobby
    print(string.format("[OE-External Safety] Melakukan Teleport ke PlaceId: %d...", currentPlaceId))
    pcall(function()
        TeleportService:Teleport(currentPlaceId, LocalPlayer)
    end)
end

return Safety