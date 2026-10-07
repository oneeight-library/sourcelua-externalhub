import { getWebDashboardHTML } from "./dashboard.js";
import { getAgentLuaCode } from "./agent_code.js";

export class HubRoom {
  constructor(state, env) {
    this.state = state;
    this.env = env;
    this.bots = new Map();         // botId -> { ws, info }
    this.controllers = new Set();  // Set of ws
  }

  async fetch(request) {
    const url = new URL(request.url);

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

    if (url.pathname === "/api/bots") {
      const list = [];
      for (const [id, b] of this.bots.entries()) {
        list.push({ id, ...b.info });
      }
      return new Response(JSON.stringify({ success: true, count: list.length, bots: list }), {
        headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }
      });
    }

    return new Response("HubRoom OK", { status: 200 });
  }

  handleBotConnection(ws, url) {
    const name = url.searchParams.get("name") || "RobloxPlayer";
    const job = url.searchParams.get("job") || "Truck";
    const placeId = url.searchParams.get("placeId") || "110369730911937";
    const gameId = url.searchParams.get("gameId") || "cdid";
    const gameName = url.searchParams.get("gameName") || "Car Driving Indonesia";
    const botId = `${name}_${Date.now().toString(36)}`;

    // 1. PENTING: Bersihkan koneksi lama dengan username yang sama (mencegah double bot saat teleport/reconnect)
    for (const [existingId, existingBot] of this.bots.entries()) {
      if (existingBot.info && existingBot.info.name && existingBot.info.name.toLowerCase() === name.toLowerCase()) {
        try {
          existingBot.ws.close(1000, "Session replaced by new connection");
        } catch (e) {}
        this.bots.delete(existingId);
        this.broadcastToControllers({
          type: "BOT_LEFT",
          botId: existingId,
          name: name
        });
      }
    }

    const botInfo = {
      botId,
      name,
      job,
      placeId,
      gameId,
      gameName,
      status: "CONNECTED",
      isKicked: false,
      kickReason: null,
      currentRoute: "Menunggu Instruksi",
      tripCount: 0,
      totalEarnings: 0,
      currentCash: 0,
      minDistance: 100000,
      lowRender: false,
      isFarming: false,
      connectedAt: Date.now(),
      lastSeen: Date.now()
    };

    this.bots.set(botId, { ws, info: botInfo });

    ws.send(JSON.stringify({ type: "INIT_ACK", botId, message: "Connected to OneEight External Hub" }));

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
        } else if (data.type === "CLIENT_KICKED") {
          botInfo.isKicked = true;
          botInfo.kickReason = data.payload?.reason || "Roblox Disconnected";
          botInfo.status = `KICKED (${botInfo.kickReason})`;
          botInfo.isFarming = false;
          this.broadcastToControllers({
            type: "BOT_LOG",
            botId,
            botName: botInfo.name,
            log: `ROBLOX KICK / DISCONNECT: ${botInfo.kickReason}`,
            level: "ERROR",
            timestamp: Date.now()
          });
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
        }
      } catch (e) {}
    });

    const cleanup = () => {
      this.bots.delete(botId);
      this.broadcastToControllers({
        type: "BOT_LEFT",
        botId,
        name: botInfo.name
      });
    };

    ws.addEventListener("close", cleanup);
    ws.addEventListener("error", cleanup);
  }

  handleControllerConnection(ws) {
    this.controllers.add(ws);

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
      } catch (e) {}
    });

    const cleanup = () => this.controllers.delete(ws);
    ws.addEventListener("close", cleanup);
    ws.addEventListener("error", cleanup);
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

    if (url.pathname === "/ws" || url.pathname.startsWith("/api/bots")) {
      const id = env.HUB_ROOM.idFromName("GLOBAL_HUB");
      const obj = env.HUB_ROOM.get(id);
      return obj.fetch(request);
    }

    if (url.pathname === "/loader" || url.pathname === "/load") {
      const loaderCode = `--[[
    OneEight External Hub - Delta WebSocket Client Agent
    Version: 2.0.0
--]]
local src = game:HttpGet("${url.origin}/client/agent.lua")
src = src:gsub("^\\239\\187\\191", "")
local fn, err = loadstring(src, "OE_ExternalAgent")
if not fn then
    error("[OE-External Loader Error]: " .. tostring(err))
end
fn()`;
      return new Response(loaderCode, {
        headers: { "Content-Type": "text/plain; charset=utf-8", "Access-Control-Allow-Origin": "*" }
      });
    }

    if (url.pathname === "/client/agent.lua") {
      const agentLua = getAgentLuaCode(url.origin);
      return new Response(agentLua, {
        headers: { "Content-Type": "text/plain; charset=utf-8", "Access-Control-Allow-Origin": "*" }
      });
    }

    if (url.pathname === "/" || url.pathname === "/dashboard") {
      return new Response(getWebDashboardHTML(url.origin), {
        headers: { "Content-Type": "text/html; charset=utf-8" }
      });
    }

    return new Response("Not Found", { status: 404 });
  }
};
