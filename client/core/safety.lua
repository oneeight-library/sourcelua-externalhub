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

-- 4. Rejoin Server Now (Private Server & Specific Instance Aware)
function Safety.RejoinNow(loaderUrl)
    loaderUrl = loaderUrl or "https://externalhub.oneeight-project18.workers.dev/loader"

    local currentPlaceId = game.PlaceId
    local currentJobId = game.JobId

    -- 1. Deteksi dan Amankan Kode Private Server (Khusus CDID)
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

    if psCode then
        _G.OE_PRIVATE_SERVER_CODE = psCode
        pcall(function()
            if typeof(writefile) == "function" then
                writefile("oe_cdid_ps_code.txt", tostring(psCode))
            end
        end)
    end

    -- 2. Setup queue_on_teleport agar loader & auto-rejoin berjalan di server berikutnya
    local queue_teleport = (syn and syn.queue_on_teleport) or queue_on_teleport or (fluxus and fluxus.queue_on_teleport) or queueonteleport
    if queue_teleport then
        pcall(function()
            queue_teleport(string.format([[
                task.wait(3.5)
                loadstring(game:HttpGet("%s"))()
            ]], loaderUrl))
        end)
    end

    -- 3. Eksekusi Rejoin: Prioritaskan Instance Sama (Private Server Instance)
    local rejoined = false
    if currentJobId and #currentJobId > 0 then
        print(string.format("[OE-External Safety] Rejoining instance: %s (Place: %d)...", currentJobId, currentPlaceId))
        local ok, err = pcall(function()
            TeleportService:TeleportToPlaceInstance(currentPlaceId, currentJobId, LocalPlayer)
        end)
        if ok then
            rejoined = true
        else
            warn("[OE-External Safety] TeleportToPlaceInstance error: " .. tostring(err))
        end
    end

    -- 4. Fallback jika JobId kosong atau TeleportToPlaceInstance gagal
    if not rejoined then
        print("[OE-External Safety] Fallback ke Teleport biasa...")
        pcall(function()
            TeleportService:Teleport(currentPlaceId, LocalPlayer)
        end)
    end
end

return Safety
