import { formatRupiah } from "@/lib/utils.js";

export const GameRegistry = {
  cdid_menu: {
    id: "cdid_menu",
    name: "CDID Main Menu",
    icon: "🏰",
    color: "#3b82f6",
    currency: "Rp",
    formatMoney: (num) => formatRupiah(num),
    metricLabel: "Status",
    metricUnit: "Lobby",
    defaultJob: "Server Gateway",
    tabs: [
      { id: "tab_server_gateway", label: "🌐 Gerbang Server" },
      { id: "tab_safety", label: "🛡️ Proteksi" },
      { id: "tab_logs", label: "📟 Konsol" },
    ]
  },
  cdid: {
    id: "cdid",
    name: "CDID Jawa Timur",
    icon: "🚚",
    color: "#10b981",
    currency: "Rp",
    formatMoney: (num) => formatRupiah(num),
    metricLabel: "Terkirim",
    metricUnit: "Trips",
    defaultJob: "Truk Kargo",
    tabs: [
      { id: "tab_autofarm", label: "📦 Auto Farm Truk" },
      { id: "tab_safety", label: "🛡️ Proteksi & Rejoin" },
      { id: "tab_perf", label: "⚡ Hemat GPU" },
      { id: "tab_logs", label: "📟 Konsol" },
    ]
  },
  dds: {
    id: "dds",
    name: "Drag Drive Simulator",
    icon: "🏁",
    color: "#f59e0b",
    currency: "Coins",
    formatMoney: (num) => (num || 0).toLocaleString() + " Coins",
    metricLabel: "Balapan",
    metricUnit: "Races",
    defaultJob: "Auto Race",
    tabs: [
      { id: "tab_autofarm", label: "🏁 Balap & Farm" },
      { id: "tab_safety", label: "🛡️ Proteksi & Rejoin" },
      { id: "tab_logs", label: "📟 Konsol" },
    ]
  }
};

export function getGameConfig(gameId) {
  return GameRegistry[gameId] || {
    id: "generic",
    name: "Roblox Game",
    icon: "🎮",
    color: "#6366f1",
    currency: "Poin",
    formatMoney: (num) => (num || 0).toLocaleString(),
    metricLabel: "Aktivitas",
    metricUnit: "Unit",
    defaultJob: "Auto Task",
    tabs: [
      { id: "tab_autofarm", label: "⚙️ Kontrol Farm" },
      { id: "tab_safety", label: "🛡️ Proteksi & Rejoin" },
      { id: "tab_logs", label: "📟 Konsol" },
    ]
  };
}
