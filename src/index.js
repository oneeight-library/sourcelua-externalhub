const THUMB_CACHE = new Map(); // assetId -> direct CDN url
import { robloxService } from "./services/roblox.js";
import { handleApiRequest } from "./api/router.js";
﻿import { getWebDashboardHTML } from "./dashboard.js";
import { getAgentLuaCode } from "./agent_code.js";

export class HubRoom {
  constructor(state, env) {
    this.state = state;
    this.env = env;
    this.bots = new Map();         // botId -> { ws, info }
    this.controllers = new Set();  // Set of ws
    this.recentLogs = [];          // ring buffer last 50 logs
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
    const userId = url.searchParams.get("userId") || "";
    const displayName = url.searchParams.get("displayName") || name;
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
      userId,
      displayName,
      avatarUrl: null,
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

    // Fetch avatar asynchronously tanpa memblokir koneksi WebSocket
    (async () => {
      let resolvedUserId = userId;
      if (!resolvedUserId && name) {
        const resolved = await robloxService.resolveUsername(name);
        if (resolved) {
          resolvedUserId = resolved.userId;
          botInfo.userId = resolved.userId;
          botInfo.displayName = resolved.displayName;
        }
      }
      if (resolvedUserId) {
        const avatar = await robloxService.getAvatarHeadshot(resolvedUserId, "150x150");
        if (avatar) {
          botInfo.avatarUrl = avatar;
          this.broadcastToControllers({
            type: "BOT_TELEMETRY",
            botId,
            payload: { avatarUrl: avatar, userId: resolvedUserId, displayName: botInfo.displayName }
          });
        }
      }
    })().catch(() => {});

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
        } else if (data.type === "DEALER_CARS_DATA") {
          const dealerKey = (data.payload?.dealer || data.dealer || "all").toLowerCase().replace(/\s+/g, "");
          const cars = data.payload?.cars || data.cars || [];
          if (!this.cachedDealerCatalog) this.cachedDealerCatalog = {};
          this.cachedDealerCatalog[dealerKey] = cars;

          this.broadcastToControllers({
            type: "DEALER_CARS_DATA",
            botId,
            dealer: data.payload?.dealer || data.dealer || "all",
            cars: cars
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
          const logItem = {
            id: Math.random().toString(36),
            botId,
            botName: botInfo.name,
            log: data.message,
            level: data.level || "INFO",
            timestamp: Date.now()
          };
          this.recentLogs.push(logItem);
          if (this.recentLogs.length > 50) this.recentLogs.shift();
          this.broadcastToControllers({
            type: "BOT_LOG",
            ...logItem
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

    if (this.recentLogs.length > 0) {
      ws.send(JSON.stringify({
        type: "LOG_HISTORY",
        logs: this.recentLogs
      }));
    }

    if (this.cachedDealerCatalog) {
      for (const [dKey, cars] of Object.entries(this.cachedDealerCatalog)) {
        ws.send(JSON.stringify({
          type: "DEALER_CARS_DATA",
          dealer: dKey,
          cars
        }));
      }
    }

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

    if (targetBotId === "ALL" || !targetBotId) {
      for (const [_, b] of this.bots.entries()) {
        try { b.ws.send(cmdPacket); } catch (_) {}
      }
      return;
    }

    let target = this.bots.get(targetBotId);
    if (!target) {
      const search = String(targetBotId).toLowerCase().trim();
      for (const [id, b] of this.bots.entries()) {
        if (id.toLowerCase() === search || (b.info && b.info.name && b.info.name.toLowerCase() === search)) {
          target = b;
          break;
        }
      }
    }

    if (target) {
      try { target.ws.send(cmdPacket); } catch (_) {}
    } else {
      for (const [_, b] of this.bots.entries()) {
        try { b.ws.send(cmdPacket); } catch (_) {}
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

    if (url.pathname === "/ws") {
      const id = env.HUB_ROOM.idFromName("GLOBAL_HUB");
      const obj = env.HUB_ROOM.get(id);
      return obj.fetch(request);
    }

    if (url.pathname === "/api/car-thumbnail") {
      const id = url.searchParams.get("id");
      if (!id) return new Response("Missing id", { status: 400 });

      // 1. Cek Cloudflare Edge Cache API (Mencegah hit ke Roblox sepenuhnya)
      const cache = caches.default;
      const cacheKey = new Request(url.toString(), request);
      try {
        const cached = await cache.match(cacheKey);
        if (cached) return cached;
      } catch (e) {}

      try {
        let imgUrl = THUMB_CACHE.get(id);

        // 2. Jika belum ada di memory cache, minta URL CDN ke Roblox
        if (!imgUrl) {
          const robloxRes = await fetch(`https://thumbnails.roblox.com/v1/assets?assetIds=${id}&size=420x420&format=Png&isCircular=false`);
          const data = await robloxRes.json();
          imgUrl = data.data?.[0]?.imageUrl;
          if (imgUrl) {
            THUMB_CACHE.set(id, imgUrl);
          }
        }

        // 3. Ambil binary dari CDN murni (tr.rbxcdn.com - tidak memiliki rate limit)
        if (imgUrl) {
          const imgRes = await fetch(imgUrl);
          const response = new Response(imgRes.body, {
            headers: {
              "Content-Type": "image/png",
              "Cache-Control": "public, max-age=2592000, s-maxage=2592000", // Edge cache 30 hari
              "Access-Control-Allow-Origin": "*"
            }
          });
          // Simpan ke edge cache secara asinkron
          ctx.waitUntil(cache.put(cacheKey, response.clone()));
          return response;
        }
      } catch (e) {}
      return new Response("Not Found", { status: 404 });
    }

    if (url.pathname.startsWith("/api/")) {
      return handleApiRequest(request, env);
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



    if (url.pathname === "/" || url.pathname === "/dashboard" || url.pathname.startsWith("/cdid_")) {
      return new Response(getWebDashboardHTML(url.origin), {
        headers: {
          "Content-Type": "text/html; charset=utf-8",
          "Cache-Control": "no-cache, no-store, must-revalidate, max-age=0",
          "Pragma": "no-cache",
          "Expires": "0"
        }
      });
    }

    return new Response("Not Found", { status: 404 });
  }
};
