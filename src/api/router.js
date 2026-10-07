/**
 * Modular API Router
 * Dispatches HTTP requests matching /api/* routes cleanly.
 */

import { robloxService } from "../services/roblox.js";

const CORS_HEADERS = {
  "Content-Type": "application/json; charset=utf-8",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization"
};

export async function handleApiRequest(request, env) {
  const url = new URL(request.url);

  // Handle CORS preflight
  if (request.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  // Route: GET /api/roblox/avatar?userId=... or ?username=...
  if (url.pathname === "/api/roblox/avatar") {
    let userId = url.searchParams.get("userId");
    const username = url.searchParams.get("username");
    const size = url.searchParams.get("size") || "150x150";

    if (!userId && username) {
      const resolved = await robloxService.resolveUsername(username);
      if (resolved) userId = resolved.userId;
    }

    if (!userId) {
      return new Response(JSON.stringify({ success: false, error: "Missing userId or username" }), {
        status: 400,
        headers: CORS_HEADERS
      });
    }

    const avatarUrl = await robloxService.getAvatarHeadshot(userId, size);
    return new Response(JSON.stringify({
      success: !!avatarUrl,
      userId,
      avatarUrl
    }), {
      headers: CORS_HEADERS
    });
  }

  // Route: GET /api/roblox/profile?userId=... or ?username=...
  if (url.pathname === "/api/roblox/profile") {
    let userId = url.searchParams.get("userId");
    const username = url.searchParams.get("username");

    if (!userId && username) {
      const resolved = await robloxService.resolveUsername(username);
      if (resolved) userId = resolved.userId;
    }

    if (!userId) {
      return new Response(JSON.stringify({ success: false, error: "Missing userId or username" }), {
        status: 400,
        headers: CORS_HEADERS
      });
    }

    const [profile, avatarUrl] = await Promise.all([
      robloxService.getUserProfile(userId),
      robloxService.getAvatarHeadshot(userId, "150x150")
    ]);

    return new Response(JSON.stringify({
      success: true,
      userId,
      profile,
      avatarUrl
    }), {
      headers: CORS_HEADERS
    });
  }

  // Route: GET /api/bots -> proxy to Durable Object HubRoom
  if (url.pathname === "/api/bots") {
    const id = env.HUB_ROOM.idFromName("GLOBAL_HUB");
    const obj = env.HUB_ROOM.get(id);
    return obj.fetch(request);
  }

  return new Response(JSON.stringify({ success: false, error: "API route not found" }), {
    status: 404,
    headers: CORS_HEADERS
  });
}
