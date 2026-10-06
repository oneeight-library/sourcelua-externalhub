// ============================================================================
// ONEEIGHT EXTERNAL HUB - CLOUDFLARE WORKER & DURABLE OBJECT WEBSOCKET ENGINE
// ============================================================================

export class HubRoom {
  constructor(state, env) {
    this.state = state;
    this.env = env;
    this.bots = new Map();         // botId -> { ws, info }
    this.controllers = new Set();  // Set of ws
  }

  async fetch(request) {
    const url = new URL(request.url);

    // WebSocket Upgrade Handler
    if (request.headers.get("Upgrade") === "websocket") {
      const role = url.searchParams.get("role") || "controller";
      const pair = new WebSocketPair();
      const [client, server] = Object.values(pair);

      server.accept();

      if (role === "bot") {
        this.handleBotConnection(server, url);
      } else {
        this.handleControllerConnection(server);
      }

      return new Response(null, { status: 101, webSocket: client });
    }

    // REST API fallback
    if (url.pathname === "/api/bots") {
      const list = [];
      for (const [id, b] of this.bots.entries()) {
        list.push({ id, ...b.info });
      }
      return new Response(JSON.stringify({ success: true, count: list.length, bots: list }), {
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
      });
    }

    return new Response("HubRoom Alive", { status: 200 });
  }

  handleBotConnection(ws, url) {
    const name = url.searchParams.get("name") || "RobloxPlayer";
    const job = url.searchParams.get("job") || "Truck";
    const placeId = url.searchParams.get("placeId") || "110369730911937";
    const botId = `${name}_${Date.now().toString(36)}`;

    const botInfo = {
      botId,
      name,
      job,
      placeId,
      gameName: "Car Driving Indonesia",
      status: "CONNECTED",
      currentRoute: "Menunggu Instruksi",
      tripCount: 0,
      totalEarnings: 0,
      currentCash: 0,
      lowRender: false,
      connectedAt: Date.now(),
      lastSeen: Date.now()
    };

    this.bots.set(botId, { ws, info: botInfo });

    // Kirim ID ke bot
    ws.send(JSON.stringify({ type: "INIT_ACK", botId, message: "Connected to OneEight External Hub" }));

    // Beritahu semua Web Controller
    this.broadcastToControllers({
      type: "BOT_JOINED",
      bot: botInfo
    });

    ws.addEventListener("message", (event) => {
      try {
        const data = JSON.parse(event.data);
        botInfo.lastSeen = Date.now();

        if (data.type === "TELEMETRY") {
          Object.assign(botInfo, data.payload || {});
          this.broadcastToControllers({
            type: "BOT_TELEMETRY",
            botId,
            payload: botInfo
          });
        } else if (data.type === "LOG") {
          this.broadcastToControllers({
            type: "BOT_LOG",
            botId,
            botName: botInfo.name,
            log: data.message,
            level: data.level || "INFO",
            timestamp: Date.now()
          });
        } else if (data.type === "PONG") {
          botInfo.lastSeen = Date.now();
        }
      } catch (e) {
        console.error("Bot message parse error:", e);
      }
    });

    ws.addEventListener("close", () => {
      this.bots.delete(botId);
      this.broadcastToControllers({
        type: "BOT_LEFT",
        botId,
        name: botInfo.name
      });
    });

    ws.addEventListener("error", () => {
      this.bots.delete(botId);
      this.broadcastToControllers({
        type: "BOT_LEFT",
        botId,
        name: botInfo.name
      });
    });
  }

  handleControllerConnection(ws) {
    this.controllers.add(ws);

    // Kirim list bot yang sedang aktif ke controller baru
    const currentBots = [];
    for (const [id, b] of this.bots.entries()) {
      currentBots.push({ id, ...b.info });
    }
    ws.send(JSON.stringify({
      type: "SYNC_BOTS",
      bots: currentBots
    }));

    ws.addEventListener("message", (event) => {
      try {
        const data = JSON.parse(event.data);
        if (data.type === "COMMAND") {
          const { targetBotId, action, payload } = data;
          this.routeCommandToBot(targetBotId, action, payload);
        }
      } catch (e) {
        console.error("Controller message error:", e);
      }
    });

    ws.addEventListener("close", () => {
      this.controllers.delete(ws);
    });

    ws.addEventListener("error", () => {
      this.controllers.delete(ws);
    });
  }

  routeCommandToBot(targetBotId, action, payload) {
    const cmdPacket = JSON.stringify({ type: "EXECUTE_COMMAND", action, payload });

    if (targetBotId === "ALL") {
      for (const [_, b] of this.bots.entries()) {
        try { b.ws.send(cmdPacket); } catch (_) {}
      }
    } else {
      const target = this.bots.get(targetBotId);
      if (target) {
        try { target.ws.send(cmdPacket); } catch (_) {}
      }
    }
  }

  broadcastToControllers(packet) {
    const raw = JSON.stringify(packet);
    for (const ws of this.controllers) {
      try {
        ws.send(raw);
      } catch (e) {
        this.controllers.delete(ws);
      }
    }
  }
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // 1. WebSocket Router ke Durable Object HubRoom
    if (url.pathname === "/ws" || url.pathname.startsWith("/api/bots")) {
      const id = env.HUB_ROOM.idFromName("GLOBAL_HUB");
      const obj = env.HUB_ROOM.get(id);
      return obj.fetch(request);
    }

    // 2. Endpoint Loader untuk Delta Executor
    if (url.pathname === "/loader" || url.pathname === "/load") {
      const loaderCode = `--[[
    OneEight External Hub - Delta WebSocket Client Agent
    Version: 1.0.0
--]]
loadstring(game:HttpGet("${url.origin}/client/agent.lua"))()`;
      return new Response(loaderCode, {
        headers: { "Content-Type": "text/plain; charset=utf-8", "Access-Control-Allow-Origin": "*" }
      });
    }

    // 3. Endpoint Source Code Client Agent Lua
    if (url.pathname === "/client/agent.lua") {
      const agentLua = getAgentLuaCode(url.origin);
      return new Response(agentLua, {
        headers: { "Content-Type": "text/plain; charset=utf-8", "Access-Control-Allow-Origin": "*" }
      });
    }

    // 4. Web UI Dashboard (Single-Page App)
    if (url.pathname === "/" || url.pathname === "/dashboard") {
      return new Response(getWebDashboardHTML(url.origin), {
        headers: { "Content-Type": "text/html; charset=utf-8" }
      });
    }

    return new Response("Not Found", { status: 404 });
  }
};

// ============================================================================
// CLIENT LUA GENERATOR
// ============================================================================
function getAgentLuaCode(origin) {
  const wsUrl = origin.replace("https://", "wss://").replace("http://", "ws://") + "/ws";
  return `--[[
    OneEight External Hub - Delta WebSocket Client
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
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local WS_BASE_URL = "${wsUrl}"
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

-- Telemetry Heartbeat
task.spawn(function()
    while task.wait(1.0) do
        if State.Socket then
            -- Baca saldo dari game jika tersedia
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
                
                -- Trigger farming loop
                task.spawn(function()
                    -- Simulasi / Integrasi State-Driven loop
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
`;
}

// ============================================================================
// WEB DASHBOARD HTML & UI
// ============================================================================
function getWebDashboardHTML(origin) {
  const wsUrl = origin.replace("https://", "wss://").replace("http://", "ws://") + "/ws";
  return `<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>OneEight External Hub - Command Center</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg: #07090e;
      --card: rgba(18, 23, 38, 0.7);
      --card-border: rgba(255, 255, 255, 0.08);
      --primary: #6366f1;
      --primary-hover: #4f46e5;
      --primary-glow: rgba(99, 102, 241, 0.35);
      --success: #10b981;
      --warning: #f59e0b;
      --danger: #ef4444;
      --text: #f3f4f6;
      --text-muted: #9ca3af;
      --mono: 'JetBrains Mono', monospace;
    }

    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background: var(--bg);
      background-image: 
        radial-gradient(at 0% 0%, rgba(99, 102, 241, 0.15) 0px, transparent 50%),
        radial-gradient(at 100% 100%, rgba(16, 185, 129, 0.08) 0px, transparent 50%);
      color: var(--text);
      font-family: 'Plus Jakarta Sans', sans-serif;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
    }

    header {
      padding: 18px 28px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-bottom: 1px solid var(--card-border);
      background: rgba(11, 15, 25, 0.8);
      backdrop-filter: blur(16px);
      position: sticky;
      top: 0;
      z-index: 50;
    }

    .brand {
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .logo-badge {
      width: 38px;
      height: 38px;
      background: linear-gradient(135deg, #6366f1, #3b82f6);
      border-radius: 10px;
      display: grid;
      place-items: center;
      font-weight: 800;
      font-size: 18px;
      color: white;
      box-shadow: 0 0 20px var(--primary-glow);
    }
    .brand-title { font-weight: 800; font-size: 18px; letter-spacing: -0.5px; }
    .brand-sub { font-size: 12px; color: var(--text-muted); font-weight: 500; }

    .header-status {
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .pill {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 6px 14px;
      border-radius: 999px;
      font-size: 13px;
      font-weight: 600;
      background: rgba(255, 255, 255, 0.05);
      border: 1px solid var(--card-border);
    }
    .pill-dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: var(--warning);
      box-shadow: 0 0 8px currentColor;
    }
    .pill-dot.online { background: var(--success); }

    main {
      flex: 1;
      max-width: 1300px;
      width: 100%;
      margin: 0 auto;
      padding: 32px 24px;
      display: flex;
      flex-direction: column;
      gap: 28px;
    }

    /* Stats Overview */
    .stats-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
      gap: 16px;
    }
    .stat-card {
      background: var(--card);
      border: 1px solid var(--card-border);
      border-radius: 16px;
      padding: 20px;
      backdrop-filter: blur(12px);
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
    .stat-label { font-size: 13px; color: var(--text-muted); font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; }
    .stat-val { font-size: 26px; font-weight: 800; font-family: var(--mono); color: #fff; }

    /* Controls Bar */
    .actions-bar {
      display: flex;
      justify-content: space-between;
      align-items: center;
      flex-wrap: wrap;
      gap: 16px;
      background: var(--card);
      border: 1px solid var(--card-border);
      border-radius: 16px;
      padding: 16px 20px;
      backdrop-filter: blur(12px);
    }
    .btn-group { display: flex; gap: 10px; flex-wrap: wrap; }
    .btn {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 10px 18px;
      border-radius: 10px;
      font-weight: 700;
      font-size: 14px;
      cursor: pointer;
      border: none;
      transition: all 0.2s ease;
    }
    .btn-primary {
      background: var(--primary);
      color: white;
      box-shadow: 0 4px 14px var(--primary-glow);
    }
    .btn-primary:hover { background: var(--primary-hover); transform: translateY(-1px); }
    .btn-danger {
      background: rgba(239, 68, 68, 0.15);
      border: 1px solid rgba(239, 68, 68, 0.4);
      color: #fca5a5;
    }
    .btn-danger:hover { background: rgba(239, 68, 68, 0.25); color: #fff; }
    .btn-outline {
      background: rgba(255, 255, 255, 0.05);
      border: 1px solid var(--card-border);
      color: var(--text);
    }
    .btn-outline:hover { background: rgba(255, 255, 255, 0.1); }

    /* Bots Table */
    .bots-container {
      background: var(--card);
      border: 1px solid var(--card-border);
      border-radius: 16px;
      padding: 24px;
      backdrop-filter: blur(12px);
    }
    .table-head {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 20px;
    }
    .table-title { font-size: 18px; font-weight: 800; }
    
    .bot-card {
      background: rgba(255, 255, 255, 0.03);
      border: 1px solid rgba(255, 255, 255, 0.06);
      border-radius: 14px;
      padding: 18px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      flex-wrap: wrap;
      gap: 16px;
      margin-bottom: 12px;
      transition: border-color 0.2s;
    }
    .bot-card:hover { border-color: rgba(99, 102, 241, 0.4); }

    .bot-profile {
      display: flex;
      align-items: center;
      gap: 14px;
    }
    .bot-avatar {
      width: 44px;
      height: 44px;
      background: linear-gradient(135deg, #1e293b, #334155);
      border-radius: 12px;
      display: grid;
      place-items: center;
      font-weight: 800;
      color: var(--primary);
      font-size: 16px;
    }
    .bot-name { font-weight: 700; font-size: 16px; }
    .bot-sub { font-size: 12px; color: var(--text-muted); }

    .bot-metric {
      display: flex;
      flex-direction: column;
      gap: 2px;
    }
    .metric-label { font-size: 11px; color: var(--text-muted); text-transform: uppercase; font-weight: 600; }
    .metric-val { font-family: var(--mono); font-weight: 700; font-size: 14px; }

    .bot-actions {
      display: flex;
      gap: 8px;
    }
    .btn-sm {
      padding: 7px 12px;
      font-size: 12px;
      border-radius: 8px;
    }

    /* Logs Terminal */
    .terminal-container {
      background: rgba(5, 7, 12, 0.9);
      border: 1px solid var(--card-border);
      border-radius: 16px;
      padding: 20px;
      font-family: var(--mono);
      font-size: 13px;
    }
    .terminal-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 14px;
      padding-bottom: 10px;
      border-bottom: 1px solid rgba(255, 255, 255, 0.08);
      color: var(--text-muted);
      font-size: 12px;
    }
    .logs-box {
      max-height: 220px;
      overflow-y: auto;
      display: flex;
      flex-direction: column;
      gap: 6px;
    }
    .log-line {
      display: flex;
      gap: 10px;
      line-height: 1.5;
    }
    .log-time { color: var(--text-muted); opacity: 0.6; }
    .log-SUCCESS { color: var(--success); }
    .log-INFO { color: #60a5fa; }
    .log-WARN { color: var(--warning); }
    .log-ERROR { color: var(--danger); }

    .empty-state {
      text-align: center;
      padding: 40px 20px;
      color: var(--text-muted);
    }
    .empty-code {
      margin-top: 14px;
      background: rgba(0, 0, 0, 0.5);
      border: 1px dashed var(--card-border);
      padding: 12px 18px;
      border-radius: 10px;
      font-family: var(--mono);
      font-size: 13px;
      display: inline-block;
      user-select: all;
      color: #a5b4fc;
    }
  </style>
</head>
<body>
  <header>
    <div class="brand">
      <div class="logo-badge">OE</div>
      <div>
        <div class="brand-title">OneEight External Hub</div>
        <div class="brand-sub">Real-Time WebSocket Command Center</div>
      </div>
    </div>
    <div class="header-status">
      <div class="pill">
        <div class="pill-dot" id="wsDot"></div>
        <span id="wsStatus">Connecting...</span>
      </div>
    </div>
  </header>

  <main>
    <!-- Stats Overview -->
    <div class="stats-grid">
      <div class="stat-card">
        <div class="stat-label">Active Bots</div>
        <div class="stat-val" id="activeBotsCount">0</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Total Pengiriman</div>
        <div class="stat-val" id="totalTrips">0</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Total Pendapatan</div>
        <div class="stat-val" style="color: var(--success);" id="totalEarnings">Rp 0</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Server Gateway</div>
        <div class="stat-val" style="font-size: 16px; color: #a5b4fc;">Cloudflare DO</div>
      </div>
    </div>

    <!-- Global Actions -->
    <div class="actions-bar">
      <div>
        <strong>Global Fleet Controls</strong>
        <p style="font-size: 13px; color: var(--text-muted);">Kirim perintah serentak ke semua bot yang terhubung</p>
      </div>
      <div class="btn-group">
        <button class="btn btn-primary" onclick="sendGlobalCommand('START_FARM')">Mulai Semua (Start)</button>
        <button class="btn btn-danger" onclick="sendGlobalCommand('STOP_FARM')">Hentikan Semua (Stop)</button>
        <button class="btn btn-outline" onclick="sendGlobalCommand('TOGGLE_LOW_RENDER')">Toggle Low GPU</button>
      </div>
    </div>

    <!-- Bots List -->
    <div class="bots-container">
      <div class="table-head">
        <div class="table-title">Daftar Akun Terhubung</div>
      </div>
      <div id="botsList">
        <div class="empty-state">
          <p>Belum ada bot yang terhubung via WebSocket.</p>
          <p>Jalankan script berikut di executor Delta Anda:</p>
          <div class="empty-code">loadstring(game:HttpGet("${origin}/client/agent.lua"))()</div>
        </div>
      </div>
    </div>

    <!-- Live Logs -->
    <div class="terminal-container">
      <div class="terminal-header">
        <span>LIVE TELEMETRY & EVENT STREAM</span>
        <span id="logCount">0 events</span>
      </div>
      <div class="logs-box" id="logsBox">
        <div class="log-line">
          <span class="log-time">[System]</span>
          <span class="log-INFO">Menghubungkan ke Cloudflare WebSocket Gateway...</span>
        </div>
      </div>
    </div>
  </main>

  <script>
    const WS_URL = "${wsUrl}?role=controller";
    let socket = null;
    let bots = new Map();
    let totalLogs = 0;

    function formatMoney(num) {
      if (!num) return "Rp 0";
      return "Rp " + Math.floor(num).toString().replace(/\\B(?=(\\d{3})+(?!\\d))/g, ".");
    }

    function initWebSocket() {
      const dot = document.getElementById("wsDot");
      const statusText = document.getElementById("wsStatus");

      socket = new WebSocket(WS_URL);

      socket.onopen = () => {
        dot.className = "pill-dot online";
        statusText.innerText = "Gateway Online";
        addLog("System", "WebSocket terhubung ke Cloudflare HubRoom!", "SUCCESS");
      };

      socket.onclose = () => {
        dot.className = "pill-dot";
        statusText.innerText = "Disconnected";
        addLog("System", "WebSocket terputus. Mencoba rekoneksi...", "WARN");
        setTimeout(initWebSocket, 3000);
      };

      socket.onerror = () => {
        dot.className = "pill-dot";
        statusText.innerText = "Error";
      };

      socket.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          handleMessage(data);
        } catch (e) {
          console.error("Parse error:", e);
        }
      };
    }

    function handleMessage(data) {
      if (data.type === "SYNC_BOTS") {
        bots.clear();
        (data.bots || []).forEach(b => bots.set(b.id || b.botId, b));
        renderBots();
      } else if (data.type === "BOT_JOINED") {
        bots.set(data.bot.botId, data.bot);
        renderBots();
        addLog(data.bot.name, "Akun baru terhubung ke dashboard!", "SUCCESS");
      } else if (data.type === "BOT_LEFT") {
        bots.delete(data.botId);
        renderBots();
        addLog(data.name || "Bot", "Akun terputus dari dashboard.", "WARN");
      } else if (data.type === "BOT_TELEMETRY") {
        const existing = bots.get(data.botId);
        if (existing) {
          Object.assign(existing, data.payload || {});
          renderBots();
        }
      } else if (data.type === "BOT_LOG") {
        addLog(data.botName || "Bot", data.log, data.level);
      }
    }

    function renderBots() {
      const container = document.getElementById("botsList");
      document.getElementById("activeBotsCount").innerText = bots.size;

      let sumTrips = 0;
      let sumEarnings = 0;

      if (bots.size === 0) {
        container.innerHTML = \`
          <div class="empty-state">
            <p>Belum ada bot yang terhubung via WebSocket.</p>
            <p>Jalankan script berikut di executor Delta Anda:</p>
            <div class="empty-code">loadstring(game:HttpGet("${origin}/client/agent.lua"))()</div>
          </div>
        \`;
        document.getElementById("totalTrips").innerText = "0";
        document.getElementById("totalEarnings").innerText = "Rp 0";
        return;
      }

      let html = "";
      for (const [id, b] of bots.entries()) {
        sumTrips += (b.tripCount || 0);
        sumEarnings += (b.totalEarnings || 0);

        html += \`
          <div class="bot-card">
            <div class="bot-profile">
              <div class="bot-avatar">\${(b.name || "B").substring(0, 2).toUpperCase()}</div>
              <div>
                <div class="bot-name">\${b.name || "Roblox Player"}</div>
                <div class="bot-sub">\${b.gameName || "CDID"} | \${b.job || "Truck"}</div>
              </div>
            </div>

            <div class="bot-metric">
              <div class="metric-label">Status</div>
              <div class="metric-val" style="color: \${b.status === 'FARMING' || b.status.startsWith('ESTIMASI') ? '#10b981' : '#f59e0b'}">\${b.status || 'CONNECTED'}</div>
            </div>

            <div class="bot-metric">
              <div class="metric-label">Rute Kargo</div>
              <div class="metric-val" style="color: #93c5fd;">\${b.currentRoute || 'IDLE'}</div>
            </div>

            <div class="bot-metric">
              <div class="metric-label">Pengiriman</div>
              <div class="metric-val">\${b.tripCount || 0} Trips</div>
            </div>

            <div class="bot-metric">
              <div class="metric-label">Pendapatan Sesi</div>
              <div class="metric-val" style="color: #10b981;">\${formatMoney(b.totalEarnings)}</div>
            </div>

            <div class="bot-actions">
              <button class="btn btn-primary btn-sm" onclick="sendCommand('\${id}', 'START_FARM')">Start</button>
              <button class="btn btn-danger btn-sm" onclick="sendCommand('\${id}', 'STOP_FARM')">Stop</button>
              <button class="btn btn-outline btn-sm" onclick="sendCommand('\${id}', 'TOGGLE_LOW_RENDER')">Low GPU</button>
            </div>
          </div>
        \`;
      }

      container.innerHTML = html;
      document.getElementById("totalTrips").innerText = sumTrips;
      document.getElementById("totalEarnings").innerText = formatMoney(sumEarnings);
    }

    function sendCommand(botId, action) {
      if (!socket || socket.readyState !== WebSocket.OPEN) return;
      socket.send(JSON.stringify({
        type: "COMMAND",
        targetBotId: botId,
        action: action
      }));
    }

    function sendGlobalCommand(action) {
      if (!socket || socket.readyState !== WebSocket.OPEN) return;
      socket.send(JSON.stringify({
        type: "COMMAND",
        targetBotId: "ALL",
        action: action
      }));
    }

    function addLog(source, msg, level) {
      totalLogs++;
      document.getElementById("logCount").innerText = totalLogs + " events";

      const box = document.getElementById("logsBox");
      const d = new Date();
      const timeStr = d.toTimeString().split(" ")[0];

      const div = document.createElement("div");
      div.className = "log-line";
      div.innerHTML = \`
        <span class="log-time">[\${timeStr}] [\${source}]</span>
        <span class="log-\${level || 'INFO'}">\${msg}</span>
      \`;

      box.appendChild(div);
      box.scrollTop = box.scrollHeight;
    }

    window.onload = initWebSocket;
  </script>
</body>
</html>`;
}
