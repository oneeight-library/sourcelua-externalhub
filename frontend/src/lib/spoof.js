import * as React from "react";

export function getBotDisplayName(bot) {
  if (!bot) return "Bot";
  try {
    const key = (bot.name || bot.botId || "").toLowerCase();
    const isWebSpoofed = typeof window !== "undefined" && localStorage.getItem(`oe_spoof_web_${key}`) === "true";
    if (isWebSpoofed) {
      return bot.config?.spoofedName || bot.streamerMode?.spoofedName || "Warga_Sipil";
    }
  } catch (e) {}
  return bot.name || "Roblox Player";
}

export function isBotWebSpoofed(bot) {
  if (!bot) return false;
  try {
    const key = (bot.name || bot.botId || "").toLowerCase();
    return typeof window !== "undefined" && localStorage.getItem(`oe_spoof_web_${key}`) === "true";
  } catch (e) {}
  return false;
}

export function useSpoofWebListener() {
  const [tick, setTick] = React.useState(0);
  React.useEffect(() => {
    const handler = () => setTick((t) => t + 1);
    window.addEventListener("oe_spoof_changed", handler);
    window.addEventListener("storage", handler);
    return () => {
      window.removeEventListener("oe_spoof_changed", handler);
      window.removeEventListener("storage", handler);
    };
  }, []);
  return tick;
}
