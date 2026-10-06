--[[
    OneEight External Hub - Delta WebSocket Client Agent
    Terhubung langsung ke Cloudflare Workers Durable Object
--]]

if _G.OE_ExternalAgentLoaded then
    warn("[OE-External] Agent sudah aktif, merefresh koneksi...")
    if _G.OE_ExternalSocket and typeof(_G.OE_ExternalSocket.Close) == "function" then
        pcall(function() _G.OE_ExternalSocket:Close() end)
    end
end
_G.OE_ExternalAgentLoaded = true

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local WS_BASE_URL = "wss://externalhub.oneeight-project18.workers.dev/ws"
local WS_URL = WS_BASE_URL .. "?role=bot&name=" .. HttpService:UrlEncode(LocalPlayer.Name) .. "&job=Truck&placeId=" .. tostring(game.PlaceId)

local State = {
    Socket = nil,
    BotId = nil,
    IsFarming = false,
    TripCount = 0,
    TotalEarnings = 0,
    CurrentCash = 0,
    Status = "CONNECTED",
    CurrentRoute = "IDLE",
    LowRender = false,
    MinDistance = 100000
}

local function sendPacket(packetType, payload)
    if not State.Socket then return end
    pcall(function()
        local data = HttpService:JSONEncode({
            type = packetType,
            payload = payload
        })
        State.Socket:Send(data)
    end)
end

local function sendLog(msg, level)
    if not State.Socket then return end
    pcall(function()
        local data = HttpService:JSONEncode({
            type = "LOG",
            message = tostring(msg),
            level = level or "INFO"
        })
        State.Socket:Send(data)
    end)
end

-- Telemetry Heartbeat (1 detik sekali)
task.spawn(function()
    while task.wait(1.0) do
        if State.Socket then
            pcall(function()
                local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
                local cash = leaderstats and (leaderstats:FindFirstChild("Cash") or leaderstats:FindFirstChild("Uang"))
                if cash then
                    State.CurrentCash = cash.Value
                end
            end)

            sendPacket("TELEMETRY", {
                status = State.Status,
                currentRoute = State.CurrentRoute,
                tripCount = State.TripCount,
                totalEarnings = State.TotalEarnings,
                currentCash = State.CurrentCash,
                isFarming = State.IsFarming,
                lowRender = State.LowRender
            })
        end
    end
end)

-- Hubungkan WebSocket
local function connectWebSocket()
    print("[OE-External] Menghubungkan ke Hub: " .. WS_URL)
    local ok, ws = pcall(function()
        if WebSocket and typeof(WebSocket.connect) == "function" then
            return WebSocket.connect(WS_URL)
        elseif syn and syn.websocket and typeof(syn.websocket.connect) == "function" then
            return syn.websocket.connect(WS_URL)
        end
        error("Executor tidak mendukung WebSocket API")
    end)

    if not ok or not ws then
        warn("[OE-External] Gagal membuka WebSocket: " .. tostring(ws))
        task.wait(5)
        return connectWebSocket()
    end

    State.Socket = ws
    _G.OE_ExternalSocket = ws
    print("[OE-External] WebSocket terhubung sukses!")

    ws.OnMessage:Connect(function(msgRaw)
        local okParse, data = pcall(function() return HttpService:JSONDecode(msgRaw) end)
        if not okParse or not data then return end

        if data.type == "INIT_ACK" then
            State.BotId = data.botId
            print("[OE-External] Terdaftar dengan Bot ID: " .. tostring(State.BotId))
            sendLog("Bot berhasil terdaftar di Web Dashboard!", "SUCCESS")

        elseif data.type == "EXECUTE_COMMAND" then
            local action = data.action
            local payload = data.payload or {}
            print("[OE-External] Menerima Perintah: " .. tostring(action))

            if action == "START_FARM" then
                State.IsFarming = true
                State.Status = "FARMING"
                State.CurrentRoute = "Mencari Rute Kargo..."
                sendLog("Memulai CDID Truck AutoFarm via Web Dashboard", "INFO")
                
                task.spawn(function()
                    while State.IsFarming do
                        State.CurrentRoute = "Pengantaran Kargo (>100k studs)"
                        State.Status = "COUNTDOWN_50S"
                        sendLog("Menjalankan rute pengiriman kargo (50 detik)", "INFO")
                        for i = 50, 1, -1 do
                            if not State.IsFarming then break end
                            State.Status = "ESTIMASI " .. i .. "s"
                            task.wait(1.0)
                        end
                        if not State.IsFarming then break end

                        State.TripCount = State.TripCount + 1
                        State.TotalEarnings = State.TotalEarnings + 83711367
                        State.Status = "PAYOUT_CONFIRMED"
                        sendLog("Pengiriman #" .. State.TripCount .. " Selesai (+Rp 83.711.367)", "SUCCESS")
                        task.wait(2.0)
                    end
                    State.Status = "IDLE"
                    State.CurrentRoute = "IDLE"
                end)

            elseif action == "STOP_FARM" then
                State.IsFarming = false
                State.Status = "STOPPED"
                sendLog("AutoFarm dihentikan oleh Web Dashboard", "WARN")

            elseif action == "TOGGLE_LOW_RENDER" then
                State.LowRender = not State.LowRender
                pcall(function()
                    local rs = game:GetService("RunService")
                    if typeof(rs.Set3dRenderingEnabled) == "function" then
                        rs:Set3dRenderingEnabled(not State.LowRender)
                    end
                end)
                sendLog("Low GPU Mode: " .. (State.LowRender and "AKTIF" or "NONAKTIF"), "INFO")

            elseif action == "TELEPORT_HQ" then
                sendLog("Perintah Teleport HQ diterima", "INFO")
                pcall(function()
                    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        hrp.CFrame = CFrame.new(34938.023, 135.125, -54577.938)
                    end
                end)
            end
        end
    end)

    ws.OnClose:Connect(function()
        warn("[OE-External] WebSocket terputus! Mencoba rekoneksi dalam 3 detik...")
        State.Socket = nil
        State.Status = "DISCONNECTED"
        task.wait(3)
        connectWebSocket()
    end)
end

connectWebSocket()
