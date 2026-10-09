import * as React from "react";
import { Card, CardHeader, CardTitle, CardContent } from "@/ui/card.jsx";
import { Button } from "@/ui/button.jsx";
import { Badge } from "@/ui/badge.jsx";
import { Avatar, AvatarImage, AvatarFallback } from "@/ui/avatar.jsx";
import { Switch } from "@/ui/switch.jsx";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/ui/select.jsx";
import { ConsoleTab } from "@/components/tabs/ConsoleTab.jsx";
import { CDIDMenuTab } from "@/components/tabs/CDIDMenuTab.jsx";
import { DealershipPage } from "@/components/DealershipPage.jsx";
import { JobProgressView } from "@/components/JobProgressView.jsx";
import { getGameConfig } from "@/config/games.js";
import { 
  Play, 
  Square, 
  RotateCcw,
  Clock, 
  ShieldCheck, 
  Coins, 
  Gauge, 
  Navigation, 
  SlidersHorizontal,
  Briefcase,
  AlertTriangle,
  Info,
  MapPin,
  Store,
  Gamepad2,
  Truck,
  Coffee,
  CheckCircle2,
  Trophy,
  Package,
  Swords,
  Crown,
  Bot,
  Gift,
  Sparkles,
  Lock,
  Unlock,
  Sun,
  EyeOff,
  Send,
  Terminal,
  Zap
} from "lucide-react";

export function BotDetailView({ 
  bot, 
  activeTab: propActiveTab, 
  onTabChange, 
  logs, 
  onClearLogs, 
  onSendCommand, 
  onRejoinBot,
  dealerCatalog = {},
  onFetchCars,
  onBuyCar,
  buyCarResult
}) {
  const gameCfg = getGameConfig(bot.gameId);
  const isKicked = bot.isKicked;
  const isLobby = bot.gameId === "cdid_menu";
  const initial = (bot.name || "B").substring(0, 2).toUpperCase();
  // SSOT: Single Source of Truth
  const features = bot.features || {};
  const config = bot.config || {};

  const isTruckFarming = features.truck !== undefined 
    ? !!features.truck 
    : (!!bot.isFarming && !(bot.job && bot.job.includes("Minigame")) && !(bot.job && (bot.job.includes("Barista") || bot.job.includes("Kanji"))));

  const isBaristaActive = features.kanjiJiwa !== undefined
    ? !!features.kanjiJiwa
    : ((bot.job && (bot.job.includes("Barista") || bot.job.includes("Kanji Jawa") || bot.job.includes("Kanji Jiwa"))) || !!bot.barista?.isFarming);

  const isMinigameActive = features.minigame !== undefined
    ? !!features.minigame
    : (bot.job && bot.job.includes("Minigame") || !!bot.minigame?.isFarming);

  const isFarming = isTruckFarming || isBaristaActive || isMinigameActive || !!bot.isFarming;

  // Deteksi Map Akun
  const placeLower = (bot.placeName || "").toLowerCase();
  const isJakarta = placeLower.includes("jakarta") || bot.placeId === "14005966837" || bot.placeId === 14005966837;
  const isJatim = placeLower.includes("jawa timur") || bot.placeId === "110369730911937" || bot.placeId === 110369730911937;

  // Persistent Tab State (Disimpan di localStorage agar refresh tidak reset)
  const storageKey = `oe_active_tab_${bot.gameId || "cdid"}`;
  const defaultTab = isLobby
    ? "gateway"
    : isJakarta
    ? isBaristaActive
      ? "barista"
      : "minigames"
    : isJatim
    ? "truck"
    : "minigames";

  const [activeTab, setActiveTab] = React.useState(() => {
    try {
      const saved = localStorage.getItem(storageKey);
      if (saved) return saved;
    } catch (e) {}
    return defaultTab;
  });

  const handleSelectTab = (tabId) => {
    setActiveTab(tabId);
    try {
      localStorage.setItem(storageKey, tabId);
    } catch (e) {}
    if (onTabChange) onTabChange(tabId);
  };

  // Drag to scroll horizontal mouse support
  const tabsContainerRef = React.useRef(null);
  const isDraggingRef = React.useRef(false);
  const startXRef = React.useRef(0);
  const scrollLeftRef = React.useRef(0);

  const handleMouseDown = (e) => {
    if (!tabsContainerRef.current) return;
    isDraggingRef.current = true;
    startXRef.current = e.pageX - tabsContainerRef.current.offsetLeft;
    scrollLeftRef.current = tabsContainerRef.current.scrollLeft;
  };
  const handleMouseLeave = () => { isDraggingRef.current = false; };
  const handleMouseUp = () => { isDraggingRef.current = false; };
  const handleMouseMove = (e) => {
    if (!isDraggingRef.current || !tabsContainerRef.current) return;
    e.preventDefault();
    const x = e.pageX - tabsContainerRef.current.offsetLeft;
    const walk = (x - startXRef.current) * 1.5;
    tabsContainerRef.current.scrollLeft = scrollLeftRef.current - walk;
  };

  // State Minigames (SSOT Direct Sync)
  const [role, setRole] = React.useState(config.minigameRole || bot.minigame?.role || "Winner");
  const autoOpenBox = features.autoOpenBox !== undefined ? !!features.autoOpenBox : !!bot.minigame?.autoOpenBox;

  React.useEffect(() => {
    if (config.minigameRole) setRole(config.minigameRole);
    else if (bot.minigame?.role) setRole(bot.minigame.role);
  }, [config.minigameRole, bot.minigame?.role]);

  // State Proteksi & Lighting (SSOT Direct Sync)
  const autoRejoin = bot.autoRejoin !== false;
  const lowRender = features.lowRender !== undefined ? !!features.lowRender : !!bot.lowRender;
  const playerDetector = features.playerDetector !== undefined ? !!features.playerDetector : !!bot.safety?.PlayerDetectorEnabled;
  const emergencyAction = config.emergencyAction || bot.safety?.EmergencyAction || "Warn Only";
  const ignoreFriends = config.ignoreFriends !== undefined ? config.ignoreFriends : (bot.safety?.IgnoreFriends !== false);
  const serverLocked = features.serverLocked !== undefined ? !!features.serverLocked : !!bot.safety?.ServerLocked;
  const fullbright = features.fullbright !== undefined ? !!features.fullbright : !!bot.lighting?.Fullbright;
  const noFog = features.noFog !== undefined ? !!features.noFog : !!bot.lighting?.NoFog;

  const handleToggleAutoRejoin = (checked) => {
    setAutoRejoin(checked);
    onSendCommand(bot.botId, "TOGGLE_AUTO_REJOIN", { enabled: checked });
  };

  const handleToggleLowRender = (checked) => {
    setLowRender(checked);
    onSendCommand(bot.botId, "TOGGLE_LOW_RENDER", { enabled: checked });
  };

  const handleSafetyUpdate = (newDetector, newAction, newIgnore) => {
    const d = newDetector !== undefined ? newDetector : playerDetector;
    const a = newAction !== undefined ? newAction : emergencyAction;
    const ig = newIgnore !== undefined ? newIgnore : ignoreFriends;
    if (newDetector !== undefined) setPlayerDetector(newDetector);
    if (newAction !== undefined) setEmergencyAction(newAction);
    if (newIgnore !== undefined) setIgnoreFriends(newIgnore);
    onSendCommand(bot.botId, "SET_SAFETY_CONFIG", {
      playerDetector: d,
      emergencyAction: a,
      ignoreFriends: ig
    });
  };

  const handleToggleServerLock = () => {
    const next = !serverLocked;
    setServerLocked(next);
    onSendCommand(bot.botId, "TOGGLE_SERVER_LOCK", { locked: next });
  };

  const handleToggleFullbright = (checked) => {
    setFullbright(checked);
    onSendCommand(bot.botId, "SET_LIGHTING_CONFIG", { fullbright: checked, noFog });
  };

  const handleToggleNoFog = (checked) => {
    setNoFog(checked);
    onSendCommand(bot.botId, "SET_LIGHTING_CONFIG", { fullbright, noFog: checked });
  };

  // Streamer Mode (Name Spoofing)
  const streamerMode = features.streamerMode !== undefined ? !!features.streamerMode : (bot.streamerMode?.enabled !== false);
  const spoofedName = config.spoofedName || bot.streamerMode?.spoofedName || "Warga_Sipil";
  const [customSpoofInput, setCustomSpoofInput] = React.useState(spoofedName);

  React.useEffect(() => {
    if (spoofedName) setCustomSpoofInput(spoofedName);
  }, [spoofedName]);

  const handleToggleStreamerMode = (checked) => {
    onSendCommand(bot.botId, "TOGGLE_STREAMER_MODE", { enabled: checked, spoofedName: customSpoofInput || spoofedName });
  };

  const handleSendCustomSpoof = (e) => {
    if (e) e.preventDefault();
    const val = customSpoofInput ? customSpoofInput.trim() : "";
    if (!val) return;
    onSendCommand(bot.botId, "SET_SPOOFED_NAME", { spoofedName: val });
  };

  // Format Waktu
  const formatTime = (secs) => {
    if (!secs || isNaN(secs)) return "00:00:00";
    const h = Math.floor(secs / 3600);
    const m = Math.floor((secs % 3600) / 60);
    const s = Math.floor(secs % 60);
    return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  };

  const truck = bot.truck || {};
  const trips = truck.tripCount !== undefined ? truck.tripCount : (bot.tripCount || 0);
  const truckEarnings = isTruckFarming 
    ? (truck.earnings !== undefined ? truck.earnings : (bot.truckEarnings !== undefined ? bot.truckEarnings : (bot.totalEarnings || 0)))
    : (trips > 0 ? (truck.earnings !== undefined ? truck.earnings : (bot.truckEarnings !== undefined ? bot.truckEarnings : 0)) : 0);

  const truckDurationSec = truck.duration !== undefined ? truck.duration : (isTruckFarming && bot.farmDuration ? bot.farmDuration : (trips > 0 ? trips * 50 : 0));
  const truckActiveTime = isTruckFarming || trips > 0 ? formatTime(truckDurationSec) : "00:00:00";

  const barista = bot.barista || {};
  const baristaDurationSec = barista.duration !== undefined ? barista.duration : (isBaristaActive && bot.farmDuration ? bot.farmDuration : 0);
  const baristaActiveTime = isBaristaActive ? formatTime(baristaDurationSec) : "00:00:00";

  const truckRoute = isTruckFarming ? (truck.currentRoute || bot.currentRoute || "IDLE").replace(/\s*\(.*?\)/g, "").trim() : "IDLE";
  const truckStatus = isTruckFarming ? (truck.status || bot.status || "Aktif") : "Standby";
  const truckSpeed = isTruckFarming ? (truck.speed !== undefined ? truck.speed : (bot.speed || 0)) : 0;
  const truckDistRemaining = isTruckFarming ? (truck.distRemaining || bot.distRemaining || "0m") : "0m";

  let avgPerHourStr = "Menghitung...";
  if (isTruckFarming && trips > 0 && truckEarnings > 0) {
    const effectiveHours = Math.max(truckDurationSec / 3600, (trips * 50) / 3600);
    const hourlyRate = Math.round(truckEarnings / effectiveHours);
    avgPerHourStr = gameCfg.formatMoney ? gameCfg.formatMoney(hourlyRate) + " / jam" : `${hourlyRate.toLocaleString()} / jam`;
  } else if (!isTruckFarming && trips === 0) {
    avgPerHourStr = "Job Standby";
  } else if (truckDurationSec >= 15 && truckEarnings === 0) {
    avgPerHourStr = gameCfg.formatMoney ? gameCfg.formatMoney(0) + " / jam" : "0 / jam";
  }

  const mg = bot.minigame || {};

  return (
    <div className="space-y-6">
      
      {/* =========================================================================
          1. HEADER AKUN (PURE INFO AKUN - STATUS DINAMIS MAP & JOB)
          ========================================================================= */}
      <Card className="border-zinc-800 bg-gradient-to-r from-zinc-900/90 via-zinc-900/50 to-zinc-950/80 shadow-md">
        <div className="p-4 sm:p-5 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          
          <div className="flex items-center gap-4">
            <Avatar className="h-14 w-14 border-2 border-zinc-700 shadow-xl rounded-2xl shrink-0">
              {(bot.avatarUrl || (typeof window !== "undefined" && localStorage.getItem(`oe_avatar_${(bot.name || "").toLowerCase()}`))) && (
                <AvatarImage src={bot.avatarUrl || localStorage.getItem(`oe_avatar_${(bot.name || "").toLowerCase()}`)} alt={bot.name} />
              )}
              <AvatarFallback className="rounded-2xl text-base font-black">
                {initial}
              </AvatarFallback>
            </Avatar>

            <div>
              <div className="flex items-center gap-2.5 flex-wrap">
                <h2 className="text-lg sm:text-xl font-extrabold tracking-tight text-zinc-100">
                  {bot.name || "Roblox Player"}
                </h2>
              </div>

              <div className="flex items-center gap-3 mt-1.5 text-xs text-zinc-400 flex-wrap">
                <span className="flex items-center gap-1.5 font-medium text-zinc-300">
                  <MapPin className="h-3.5 w-3.5 text-blue-400" />
                  {bot.placeName || "Car Driving Indonesia"}
                </span>
                <span className="text-zinc-600">•</span>
                <span className="flex items-center gap-1.5">
                  <Briefcase className="h-3.5 w-3.5 text-amber-400" />
                  {bot.job || "Unemployed"}
                </span>
              </div>
            </div>
          </div>

          <div className="flex items-center gap-3 self-end sm:self-center">
            {isKicked && (
              <Button
                variant="outline"
                size="sm"
                className="text-xs h-9 font-semibold gap-1.5 border-rose-800/60 text-rose-300 hover:bg-rose-950/40"
                onClick={() => onRejoinBot && onRejoinBot(bot.botId)}
              >
                <RotateCcw className="h-3.5 w-3.5 text-rose-400" />
                Rejoin Server
              </Button>
            )}
          </div>

        </div>
      </Card>

      {/* =========================================================================
          2. NAVIGASI TAB UTAMA (SCROLL HORIZONTAL DENGAN DRAG MOUSE)
          ========================================================================= */}
      <div 
        ref={tabsContainerRef}
        onMouseDown={handleMouseDown}
        onMouseLeave={handleMouseLeave}
        onMouseUp={handleMouseUp}
        onMouseMove={handleMouseMove}
        className="w-full overflow-x-auto pb-1 scrollbar-none cursor-grab active:cursor-grabbing select-none"
      >
        <div className="flex items-center gap-2 p-1.5 rounded-2xl bg-zinc-900/60 border border-zinc-800/80 backdrop-blur-md w-max min-w-full">
          {isLobby ? (
            <>
              {/* TAB KHUSUS LOBI GATEWAY */}
              <button
                type="button"
                onClick={() => handleSelectTab("gateway")}
                className={`flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-bold transition-all whitespace-nowrap shrink-0 ${
                  activeTab === "gateway"
                    ? "bg-blue-600 text-white shadow-md shadow-blue-500/25 ring-1 ring-blue-400/40"
                    : "text-zinc-400 hover:text-blue-300 hover:bg-zinc-800/60"
                }`}
              >
                <MapPin className="h-4 w-4 text-blue-400" />
                <span>Gateway Lobi</span>
              </button>

              <button
                type="button"
                onClick={() => handleSelectTab("dealership")}
                className={`flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-bold transition-all whitespace-nowrap shrink-0 ${
                  activeTab === "dealership"
                    ? "bg-amber-600 text-white shadow-md shadow-amber-500/25 ring-1 ring-amber-400/40"
                    : "text-zinc-400 hover:text-amber-300 hover:bg-zinc-800/60"
                }`}
              >
                <Store className="h-4 w-4 text-amber-400" />
                <span>Dealerships</span>
              </button>

              <button
                type="button"
                onClick={() => handleSelectTab("safety")}
                className={`flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-bold transition-all whitespace-nowrap shrink-0 ${
                  activeTab === "safety"
                    ? "bg-zinc-700 text-white shadow-md"
                    : "text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800/60"
                }`}
              >
                <ShieldCheck className="h-4 w-4 text-emerald-400" />
                <span>Proteksi</span>
              </button>

              <button
                type="button"
                onClick={() => handleSelectTab("console")}
                className={`flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-bold transition-all whitespace-nowrap shrink-0 ${
                  activeTab === "console"
                    ? "bg-zinc-700 text-white shadow-md"
                    : "text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800/60"
                }`}
              >
                <Terminal className="h-4 w-4 text-purple-400" />
                <span>Live Konsol</span>
              </button>
            </>
          ) : (
            <>
              {/* TAB 1: MINIGAMES SUMO (JAKARTA) */}
              <button
                type="button"
                onClick={() => handleSelectTab("minigames")}
                className={`flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-bold transition-all whitespace-nowrap shrink-0 ${
                  activeTab === "minigames"
                    ? "bg-cyan-600 text-white shadow-md shadow-cyan-500/25 ring-1 ring-cyan-400/40"
                    : "text-zinc-400 hover:text-cyan-300 hover:bg-zinc-800/60"
                }`}
              >
                <Gamepad2 className="h-4 w-4 text-cyan-400" />
                <span>Minigames</span>
                {isMinigameActive && <span className="h-1.5 w-1.5 rounded-full bg-cyan-400 animate-pulse" />}
              </button>

              {/* TAB 2: CAFE KANJI JAWA / BARISTA (JAKARTA) */}
              <button
                type="button"
                onClick={() => handleSelectTab("barista")}
                className={`flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-bold transition-all whitespace-nowrap shrink-0 ${
                  activeTab === "barista"
                    ? "bg-amber-600 text-white shadow-md shadow-amber-500/25 ring-1 ring-amber-400/40"
                    : "text-zinc-400 hover:text-amber-300 hover:bg-zinc-800/60"
                }`}
              >
                <Coffee className="h-4 w-4 text-amber-400" />
                <span>Kanji Jiwa</span>
                {isBaristaActive && <span className="h-1.5 w-1.5 rounded-full bg-amber-400 animate-pulse" />}
              </button>

              {/* TAB 3: TRUK KARGO (JAWA TIMUR) */}
              <button
                type="button"
                onClick={() => handleSelectTab("truck")}
                className={`flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-bold transition-all whitespace-nowrap shrink-0 ${
                  activeTab === "truck"
                    ? "bg-emerald-600 text-white shadow-md shadow-emerald-500/25 ring-1 ring-emerald-400/40"
                    : "text-zinc-400 hover:text-emerald-300 hover:bg-zinc-800/60"
                }`}
              >
                <Truck className="h-4 w-4 text-emerald-400" />
                <span>Truk Kargo</span>
                {isTruckFarming && <span className="h-1.5 w-1.5 rounded-full bg-emerald-400 animate-pulse" />}
              </button>

              {/* TAB 4: DEALERSHIPS */}
              <button
                type="button"
                onClick={() => handleSelectTab("dealership")}
                className={`flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-bold transition-all whitespace-nowrap shrink-0 ${
                  activeTab === "dealership"
                    ? "bg-amber-600 text-white shadow-md shadow-amber-500/25 ring-1 ring-amber-400/40"
                    : "text-zinc-400 hover:text-amber-300 hover:bg-zinc-800/60"
                }`}
              >
                <Store className="h-4 w-4 text-amber-400" />
                <span>Dealerships</span>
              </button>

              {/* TAB 5: PROTEKSI KEAMANAN */}
              <button
                type="button"
                onClick={() => handleSelectTab("safety")}
                className={`flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-bold transition-all whitespace-nowrap shrink-0 ${
                  activeTab === "safety"
                    ? "bg-zinc-700 text-white shadow-md ring-1 ring-zinc-500/40"
                    : "text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800/60"
                }`}
              >
                <ShieldCheck className="h-4 w-4 text-emerald-400" />
                <span>Proteksi Keamanan</span>
              </button>

              {/* TAB 6: KONSOL & OPTIMASI */}
              <button
                type="button"
                onClick={() => handleSelectTab("console")}
                className={`flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-bold transition-all whitespace-nowrap shrink-0 ${
                  activeTab === "console"
                    ? "bg-purple-700 text-white shadow-md shadow-purple-500/25 ring-1 ring-purple-400/40"
                    : "text-zinc-400 hover:text-purple-300 hover:bg-zinc-800/60"
                }`}
              >
                <Terminal className="h-4 w-4 text-purple-400" />
                <span>Konsol & Optimasi</span>
              </button>
            </>
          )}
        </div>
      </div>

      {/* =========================================================================
          3. KONTEN TAB SPESIFIK (TELEMETRI & KONTROL TERISOLASI)
          ========================================================================= */}

      {/* A. TAMPILAN SHOWROOM CDID */}
      {activeTab === "dealership" && (
        <DealershipPage
          activeBot={bot}
          dealerCatalog={dealerCatalog}
          onFetchCars={onFetchCars}
          onBuyCar={onBuyCar}
          buyCarResult={buyCarResult}
          isEmbedded={true}
          isSingleBotMode={true}
          onBackToDashboard={() => handleSelectTab(defaultTab)}
        />
      )}

      {/* B. TAMPILAN GATEWAY LOBI */}
      {isLobby && activeTab === "gateway" && (
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
          <div className="lg:col-span-5 space-y-5">
            <Card className="border-zinc-800">
              <CardHeader className="p-4 pb-2 border-b border-zinc-800/60">
                <CardTitle className="text-xs font-semibold uppercase tracking-wider text-zinc-400 flex items-center gap-2">
                  <Info className="h-4 w-4 text-blue-400" />
                  Status Gerbang Lobi
                </CardTitle>
              </CardHeader>
              <CardContent className="p-4 space-y-3">
                <div className="p-3.5 rounded-xl bg-zinc-900/40 border border-zinc-800 text-xs text-zinc-300 leading-relaxed">
                  Akun berada di <span className="font-semibold text-zinc-100">CDID Main Menu</span>. Silakan gunakan panel di sebelah kanan untuk memilih map tujuan dan menyetel kode server.
                </div>
                <div className="flex items-center justify-between p-3 rounded-xl bg-zinc-900/40 border border-zinc-800">
                  <span className="text-xs text-zinc-400">Status Gateway</span>
                  <Badge variant="emerald" className="text-[10px] font-bold">
                    {bot.status || "LOBBY_READY"}
                  </Badge>
                </div>
              </CardContent>
            </Card>
          </div>
          <div className="lg:col-span-7">
            <CDIDMenuTab bot={bot} onSendCommand={onSendCommand} />
          </div>
        </div>
      )}

      {/* C1. TAMPILAN MINIGAMES (JAKARTA) */}
      {!isLobby && activeTab === "minigames" && (
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
          
          {/* Kolom Kiri: Live Telemetri Minigames */}
          <div className="lg:col-span-6 space-y-5">
            
            {/* Card Saldo & Poin Minigame */}
            <Card className="border-zinc-800">
              <CardHeader className="p-4 pb-2 border-b border-zinc-800/60 flex flex-row items-center justify-between">
                <CardTitle className="text-xs font-bold uppercase tracking-wider text-cyan-400 flex items-center gap-2">
                  <Trophy className="h-4 w-4 text-cyan-400" />
                  Keuangan & Hadiah Minigames
                </CardTitle>
                <Badge variant={isMinigameActive ? "cyan" : "secondary"} className="text-[10px] font-bold">
                  {isMinigameActive ? "AKTIF" : "STANDBY"}
                </Badge>
              </CardHeader>
              <CardContent className="p-4">
                <div className="grid grid-cols-2 gap-3">
                  <div className="p-3.5 rounded-xl bg-zinc-900/60 border border-zinc-800/80">
                    <span className="text-[10px] font-bold uppercase tracking-wider text-zinc-400 block">Saldo Akun</span>
                    <div className="text-base sm:text-lg font-black text-emerald-400 tabular-nums tracking-tight mt-0.5">
                      {gameCfg.formatMoney(bot.currentCash)}
                    </div>
                  </div>

                  <div className="p-3.5 rounded-xl bg-cyan-950/20 border border-cyan-800/40">
                    <span className="text-[10px] font-bold uppercase tracking-wider text-cyan-400 block">Poin Minigame</span>
                    <div className="text-base sm:text-lg font-black text-cyan-300 tabular-nums tracking-tight mt-0.5">
                      {mg.points || 0} Poin
                    </div>
                    <span className="text-[10px] text-cyan-500/90 font-medium tabular-nums block mt-0.5">
                      +{mg.pointsEarned || 0} didapat sesi ini
                    </span>
                  </div>

                  <div className="p-3.5 rounded-xl bg-zinc-900/60 border border-zinc-800/80">
                    <span className="text-[10px] font-bold uppercase tracking-wider text-zinc-400 block">Box Terbuka</span>
                    <div className="text-base sm:text-lg font-black text-purple-400 tabular-nums tracking-tight mt-0.5">
                      {mg.boxes || 0} Box
                    </div>
                    <span className="text-[10px] text-zinc-500 font-medium block mt-0.5">
                      {autoOpenBox ? "Auto Beli: AKTIF" : "Manual"}
                    </span>
                  </div>

                  <div className="p-3.5 rounded-xl bg-zinc-900/60 border border-zinc-800/80">
                    <span className="text-[10px] font-bold uppercase tracking-wider text-zinc-400 block">Uang Didapat</span>
                    <div className="text-base sm:text-lg font-black text-emerald-400 tabular-nums tracking-tight mt-0.5">
                      +{gameCfg.formatMoney(mg.cashEarned || 0)}
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Card Status Sumo Arena */}
            <Card className="border-zinc-800">
              <CardHeader className="p-4 pb-2 border-b border-zinc-800/60">
                <CardTitle className="text-xs font-bold uppercase tracking-wider text-zinc-400 flex items-center gap-2">
                  <Swords className="h-4 w-4 text-cyan-400" />
                  Status & Rekor Pertandingan
                </CardTitle>
              </CardHeader>
              <CardContent className="p-4">
                <div className="grid grid-cols-2 gap-3">
                  <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800">
                    <span className="text-[10px] font-bold uppercase text-zinc-400 block tracking-wider">Rekor Match</span>
                    <span className="text-xs font-bold text-zinc-100 tabular-nums mt-0.5 block">
                      {mg.wins || 0} Menang / {mg.losses || 0} Kalah
                    </span>
                    <span className="text-[10px] text-zinc-500 block mt-0.5">Hasil Akhir: {mg.lastResult || "-"}</span>
                  </div>

                  <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800">
                    <span className="text-[10px] font-bold uppercase text-zinc-400 block tracking-wider">Fase & Ronde</span>
                    <span className="text-xs font-bold text-cyan-400 mt-0.5 block truncate">
                      {mg.phase || "Standby"}
                    </span>
                    <span className="text-[10px] text-zinc-500 block mt-0.5">Ronde {mg.round || 0} / {mg.maxRounds || 10}</span>
                  </div>
                </div>
              </CardContent>
            </Card>

          </div>

          {/* Kolom Kanan: Kontrol Minigames */}
          <div className="lg:col-span-6 space-y-5">
            <Card className="border-zinc-800 bg-gradient-to-br from-zinc-900/70 to-zinc-950/70">
              <CardHeader className="p-4 pb-2 border-b border-zinc-800/60 flex flex-row items-center justify-between">
                <CardTitle className="text-xs font-bold uppercase tracking-wider text-cyan-400 flex items-center gap-2">
                  <Gamepad2 className="h-4 w-4 text-cyan-400" />
                  Kontrol Minigames
                </CardTitle>
                <Badge variant={isMinigameActive ? "cyan" : "secondary"} className="text-[10px] font-bold">
                  {isMinigameActive ? "BERJALAN" : "BERHENTI"}
                </Badge>
              </CardHeader>
              <CardContent className="p-4 space-y-4">
                
                {/* Pemilihan Role */}
                <div className="p-3.5 rounded-xl bg-zinc-900/70 border border-zinc-800/80">
                  <label className="text-xs font-bold text-zinc-200 block mb-2 flex items-center gap-1.5">
                    <Crown className="h-4 w-4 text-amber-400" />
                    Pilih Peran Akun (Role Pertandingan)
                  </label>
                  <div className="grid grid-cols-2 gap-2.5">
                    <Button
                      type="button"
                      variant={role === "Winner" ? "emerald" : "outline"}
                      className="font-bold text-xs h-10 gap-1.5"
                      onClick={() => setRole("Winner")}
                    >
                      <Crown className="h-4 w-4 text-amber-400" /> Winner (Panen)
                    </Button>
                    <Button
                      type="button"
                      variant={role === "Loser" ? "destructive" : "outline"}
                      className="font-bold text-xs h-10 gap-1.5"
                      onClick={() => setRole("Loser")}
                    >
                      <Bot className="h-4 w-4" /> Loser (Tumbal)
                    </Button>
                  </div>
                  <p className="text-[11px] text-zinc-400 mt-2 leading-relaxed">
                    {role === "Winner" 
                      ? "Akun Utama: Diam di tengah arena dan mengumpulkan poin kemenangan setiap ronde."
                      : "Akun Bot: Langsung gugur keluar ring agar setiap match selesai instan dalam hitungan detik."}
                  </p>
                </div>

                {/* Manajemen Hadiah Box */}
                <div className="p-3.5 rounded-xl bg-zinc-900/70 border border-zinc-800/80 space-y-3">
                  <div className="flex items-center justify-between">
                    <div>
                      <div className="font-semibold text-xs text-zinc-200 flex items-center gap-1.5">
                        <Gift className="h-4 w-4 text-purple-400" />
                        Otomatis Tukar Box Tiap 20 Poin
                      </div>
                      <div className="text-[11px] text-zinc-400">Tukarkan poin secara otomatis ke Minigame Box</div>
                    </div>
                    <Switch
                      checked={autoOpenBox}
                      onCheckedChange={(checked) => setAutoOpenBox(checked)}
                    />
                  </div>
                  <Button
                    variant="outline"
                    size="sm"
                    className="w-full text-xs font-semibold h-8 border-zinc-700 hover:bg-zinc-800 text-cyan-300 gap-1.5"
                    onClick={() => onSendCommand(bot.botId, "BUY_MINIGAME_BOX")}
                  >
                    <Gift className="h-3.5 w-3.5 text-cyan-400" />
                    Beli 1 Box Sekarang (-20 Poin)
                  </Button>
                </div>

                {/* Tombol Utama Start / Stop */}
                <Button
                  variant={isMinigameActive ? "destructive" : "cyan"}
                  className="w-full font-bold text-sm h-12 gap-2 shadow-lg"
                  onClick={() => {
                    if (isMinigameActive) {
                      onSendCommand(bot.botId, "STOP_MINIGAME_FARM");
                    } else {
                      onSendCommand(bot.botId, "START_MINIGAME_FARM", { role, autoOpenBox });
                    }
                  }}
                >
                  {isMinigameActive ? <Square className="h-4 w-4" /> : <Play className="h-4 w-4" />}
                  {isMinigameActive ? "Hentikan Minigames" : "Mulai Minigames Sekarang"}
                </Button>

              </CardContent>
            </Card>
          </div>

        </div>
      )}

      {/* C2. TAMPILAN CAFE KANJI JAWA / BARISTA (JAKARTA) */}
      {!isLobby && activeTab === "barista" && (
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
          
          {/* Kolom Kiri: Live Telemetri Barista */}
          <div className="lg:col-span-6 space-y-5">
            
            {/* Card Saldo & Performa Barista */}
            <Card className="border-zinc-800">
              <CardHeader className="p-4 pb-2 border-b border-zinc-800/60 flex flex-row items-center justify-between">
                <CardTitle className="text-xs font-bold uppercase tracking-wider text-amber-400 flex items-center gap-2">
                  <Coffee className="h-4 w-4 text-amber-400" />
                  Keuangan & Penjualan Kopi
                </CardTitle>
                <Badge variant={isBaristaActive ? "amber" : "secondary"} className={`text-[10px] font-bold ${isBaristaActive ? "bg-amber-500/20 text-amber-300 border border-amber-500/40" : ""}`}>
                  {isBaristaActive ? "BARISTA AKTIF" : "STANDBY"}
                </Badge>
              </CardHeader>
              <CardContent className="p-4">
                <div className="grid grid-cols-2 gap-3">
                  <div className="p-3.5 rounded-xl bg-zinc-900/60 border border-zinc-800/80">
                    <span className="text-[10px] font-bold uppercase tracking-wider text-zinc-400 block">Saldo Akun</span>
                    <div className="text-base sm:text-lg font-black text-emerald-400 tabular-nums tracking-tight mt-0.5">
                      {gameCfg.formatMoney(bot.currentCash)}
                    </div>
                  </div>

                  <div className="p-3.5 rounded-xl bg-amber-950/20 border border-amber-800/40">
                    <span className="text-[10px] font-bold uppercase tracking-wider text-amber-400 block">Cup Disajikan</span>
                    <div className="text-base sm:text-lg font-black text-amber-300 tabular-nums tracking-tight mt-0.5">
                      {barista.totalOrders || 0} Cup
                    </div>
                    <span className="text-[10px] text-zinc-500 font-medium tabular-nums block mt-0.5">
                      {barista.ruinedOrders ? `${barista.ruinedOrders} rusak dibuang` : "100% Sempurna"}
                    </span>
                  </div>

                  <div className="p-3.5 rounded-xl bg-zinc-900/60 border border-zinc-800/80">
                    <span className="text-[10px] font-bold uppercase tracking-wider text-zinc-400 block">Gaji Terakhir</span>
                    <div className="text-base sm:text-lg font-black text-amber-400 tabular-nums tracking-tight mt-0.5">
                      {gameCfg.formatMoney(barista.lastGaji || 0)}
                    </div>
                    <span className="text-[10px] text-zinc-500 font-medium block mt-0.5">
                      Per cup pesanan selesai
                    </span>
                  </div>

                  <div className="p-3.5 rounded-xl bg-zinc-900/60 border border-zinc-800/80">
                    <span className="text-[10px] font-bold uppercase tracking-wider text-zinc-400 block">Hasil Sesi Barista</span>
                    <div className="text-base sm:text-lg font-black text-emerald-400 tabular-nums tracking-tight mt-0.5">
                      +{gameCfg.formatMoney(barista.totalEarned || 0)}
                    </div>
                    <span className="text-[10px] text-emerald-500/90 font-medium block mt-0.5">
                      {barista.avgPerHour ? `${gameCfg.formatMoney(barista.avgPerHour)} / jam` : "Menghitung rate..."}
                    </span>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Card Status Pesanan Aktif */}
            <Card className="border-zinc-800">
              <CardHeader className="p-4 pb-2 border-b border-zinc-800/60">
                <CardTitle className="text-xs font-bold uppercase tracking-wider text-zinc-400 flex items-center gap-2">
                  <Sparkles className="h-4 w-4 text-amber-400" />
                  Status Pesanan & Racikan Meja Barista
                </CardTitle>
              </CardHeader>
              <CardContent className="p-4 space-y-3">
                <div className="grid grid-cols-2 gap-3">
                  <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800">
                    <span className="text-[10px] font-bold uppercase text-zinc-400 block tracking-wider">Fase / Aktivitas</span>
                    <span className="text-xs font-bold text-amber-300 mt-0.5 block truncate">
                      {barista.phase || (isBaristaActive ? "Berjalan" : "Standby")}
                    </span>
                    <span className="text-[10px] text-zinc-500 block mt-0.5">
                      Durasi: {baristaActiveTime}
                    </span>
                  </div>

                  <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800">
                    <span className="text-[10px] font-bold uppercase text-zinc-400 block tracking-wider">Customer Counter</span>
                    <span className="text-xs font-bold text-zinc-100 mt-0.5 block truncate">
                      {barista.currentCustomer && barista.currentCustomer !== "-" ? barista.currentCustomer : "Menunggu Customer"}
                    </span>
                    <span className="text-[10px] text-zinc-500 block mt-0.5">
                      {barista.currentOrder?.OrderId ? `Order ID #${barista.currentOrder.OrderId}` : "Meja Kasir"}
                    </span>
                  </div>
                </div>

                {barista.currentOrder?.MenuId && (
                  <div className="p-3.5 rounded-xl bg-amber-950/30 border border-amber-800/40 text-xs space-y-1.5">
                    <div className="flex items-center justify-between font-bold text-amber-200">
                      <span>Menu: {barista.currentOrder.MenuId} {barista.currentOrder.Flavour && `(${barista.currentOrder.Flavour})`}</span>
                      <span className="font-mono text-amber-400">Progres: {barista.currentOrder.DoneCount || 0} / {barista.currentOrder.StepCount || "?"}</span>
                    </div>
                    <div className="text-[11px] text-zinc-400 flex items-center justify-between">
                      <span>Stasiun Tujuan: <strong className="text-zinc-200">{barista.currentOrder.NextStation || barista.currentOrder.NextStep || "Selesai"}</strong></span>
                      <span className="text-emerald-400 font-semibold">{barista.currentOrder.Done ? "Siap Disajikan!" : "Sedang Diracik..."}</span>
                    </div>
                  </div>
                )}
              </CardContent>
            </Card>

          </div>

          {/* Kolom Kanan: Kontrol Barista & Klaim Hadiah */}
          <div className="lg:col-span-6 space-y-5">
            <Card className="border-zinc-800 bg-gradient-to-br from-zinc-900/70 to-zinc-950/70">
              <CardHeader className="p-4 pb-2 border-b border-zinc-800/60 flex flex-row items-center justify-between">
                <CardTitle className="text-xs font-bold uppercase tracking-wider text-amber-400 flex items-center gap-2">
                  <Coffee className="h-4 w-4 text-amber-400" />
                  Kontrol Kanji Jiwa
                </CardTitle>
                <Badge variant={isBaristaActive ? "amber" : "secondary"} className={`text-[10px] font-bold ${isBaristaActive ? "bg-amber-500/20 text-amber-300 border border-amber-500/40" : ""}`}>
                  {isBaristaActive ? "BERJALAN" : "BERHENTI"}
                </Badge>
              </CardHeader>
              <CardContent className="p-4 space-y-4">
                
                <Button
                  variant="outline"
                  size="sm"
                  className="w-full text-xs font-semibold h-9 border-zinc-800 bg-zinc-900/60 hover:bg-zinc-800 text-amber-300 gap-1.5"
                  onClick={() => onSendCommand(bot.botId, "TELEPORT_CAFE")}
                >
                  <MapPin className="h-3.5 w-3.5 text-amber-400" />
                  Teleport Cepat ke Kanji Jiwa
                </Button>

                {/* Tombol Utama Start / Stop Barista */}
                <Button
                  variant={isBaristaActive ? "destructive" : "amber"}
                  className={`w-full font-bold text-sm h-12 gap-2 shadow-lg ${!isBaristaActive ? "bg-amber-600 hover:bg-amber-500 text-white" : ""}`}
                  onClick={() => {
                    if (isBaristaActive) {
                      onSendCommand(bot.botId, "STOP_KANJI_JAWA_FARM");
                    } else {
                      onSendCommand(bot.botId, "START_KANJI_JAWA_FARM");
                    }
                  }}
                >
                  {isBaristaActive ? <Square className="h-4 w-4" /> : <Play className="h-4 w-4" />}
                  {isBaristaActive ? "Hentikan Auto Farm Kanji Jiwa" : "Mulai Auto Farm Kanji Jiwa"}
                </Button>

              </CardContent>
            </Card>

            {/* Progres Level & Claim Hadiah (Ditempatkan di Bawah Kontrol Kanji Jiwa) */}
            <JobProgressView bot={bot} onSendCommand={onSendCommand} />
          </div>

        </div>
      )}

      {/* D. TAMPILAN TRUK KARGO (JAWA TIMUR) */}
      {!isLobby && activeTab === "truck" && (
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
          
          {/* Kolom Kiri: Telemetri Pengiriman Truk */}
          <div className="lg:col-span-6 space-y-5">
            <Card className="border-zinc-800">
              <CardHeader className="p-4 pb-2 border-b border-zinc-800/60 flex flex-row items-center justify-between">
                <CardTitle className="text-xs font-bold uppercase tracking-wider text-emerald-400 flex items-center gap-2">
                  <Truck className="h-4 w-4 text-emerald-400" />
                  Keuangan & Ekspedisi Kargo
                </CardTitle>
                <Badge variant={isTruckFarming ? "emerald" : "secondary"} className="text-[10px] font-bold">
                  {isTruckFarming ? "BEKERJA" : "STANDBY"}
                </Badge>
              </CardHeader>
              <CardContent className="p-4">
                <div className="grid grid-cols-2 gap-3">
                  <div className="p-3.5 rounded-xl bg-zinc-900/60 border border-zinc-800/80">
                    <span className="text-[10px] font-bold uppercase tracking-wider text-zinc-400 block">Saldo Akun</span>
                    <div className="text-base sm:text-lg font-black text-emerald-400 tabular-nums tracking-tight mt-0.5">
                      {gameCfg.formatMoney(bot.currentCash)}
                    </div>
                  </div>

                  <div className="p-3.5 rounded-xl bg-zinc-900/60 border border-zinc-800/80">
                    <div className="flex items-center justify-between">
                      <span className="text-[10px] font-bold uppercase tracking-wider text-zinc-400 block">Hasil Sesi</span>
                      <span className="text-[10px] text-emerald-400 bg-emerald-950/40 px-1.5 py-0.5 rounded border border-emerald-800/40 font-bold tabular-nums">
                        {trips} Trips
                      </span>
                    </div>
                    <div className="text-base sm:text-lg font-black text-emerald-400 tabular-nums tracking-tight mt-0.5">
                      +{gameCfg.formatMoney(truckEarnings)}
                    </div>
                  </div>

                  <div className="p-3.5 rounded-xl bg-zinc-900/60 border border-zinc-800/80">
                    <span className="text-[10px] font-bold uppercase tracking-wider text-zinc-400 block">Durasi Jalan</span>
                    <div className="text-base sm:text-lg font-black text-zinc-200 tabular-nums tracking-tight mt-0.5">
                      {truckActiveTime}
                    </div>
                  </div>

                  <div className="p-3.5 rounded-xl bg-zinc-900/60 border border-zinc-800/80">
                    <span className="text-[10px] font-bold uppercase tracking-wider text-zinc-400 block">Avg / Jam</span>
                    <div className="text-xs sm:text-sm font-black text-emerald-400 tabular-nums tracking-tight mt-1">
                      {avgPerHourStr}
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card className="border-zinc-800">
              <CardHeader className="p-4 pb-2 border-b border-zinc-800/60">
                <CardTitle className="text-xs font-bold uppercase tracking-wider text-zinc-400 flex items-center gap-2">
                  <Navigation className="h-4 w-4 text-blue-400" />
                  Telemetri Operasional Rute
                </CardTitle>
              </CardHeader>
              <CardContent className="p-4">
                <div className="grid grid-cols-2 gap-3">
                  <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800">
                    <span className="text-[10px] font-bold uppercase text-zinc-400 block tracking-wider">Status Rute</span>
                    <span className="text-xs font-bold text-zinc-100 mt-0.5 block truncate" title={truckRoute}>
                      {truckRoute}
                    </span>
                  </div>

                  <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800">
                    <span className="text-[10px] font-bold uppercase text-zinc-400 block tracking-wider">Kecepatan Truk</span>
                    <span className="text-xs font-bold text-emerald-400 tabular-nums mt-0.5 block">
                      {truckSpeed} KM/H
                    </span>
                  </div>

                  <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800">
                    <span className="text-[10px] font-bold uppercase text-zinc-400 block tracking-wider">Sisa Jarak</span>
                    <span className="text-xs font-bold text-zinc-100 tabular-nums mt-0.5 block">
                      {truckDistRemaining}
                    </span>
                  </div>

                  <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800">
                    <span className="text-[10px] font-bold uppercase text-zinc-400 block tracking-wider">Status Kendaraan</span>
                    <span className="text-xs font-bold text-zinc-100 mt-0.5 block">
                      {truckStatus}
                    </span>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Kolom Kanan: Kontrol Truk Kargo */}
          <div className="lg:col-span-6 space-y-5">
            <Card className="border-zinc-800 bg-gradient-to-br from-zinc-900/70 to-zinc-950/70">
              <CardHeader className="p-4 pb-2 border-b border-zinc-800/60 flex flex-row items-center justify-between">
                <CardTitle className="text-xs font-bold uppercase tracking-wider text-emerald-400 flex items-center gap-2">
                  <Truck className="h-4 w-4 text-emerald-400" />
                  Kontrol Truk Kargo (Jawa Timur)
                </CardTitle>
                <Badge variant={isTruckFarming ? "emerald" : "secondary"} className="text-[10px] font-bold">
                  {isTruckFarming ? "BERJALAN" : "BERHENTI"}
                </Badge>
              </CardHeader>
              <CardContent className="p-4 space-y-3">
                <Button
                  variant={isTruckFarming ? "destructive" : "emerald"}
                  className="w-full font-bold text-sm h-12 gap-2 shadow-lg"
                  onClick={() => onSendCommand(bot.botId, isTruckFarming ? "STOP_FARM" : "START_FARM", { jobType: "truck" })}
                >
                  {isTruckFarming ? <Square className="h-4 w-4" /> : <Play className="h-4 w-4" />}
                  {isTruckFarming ? "Hentikan Truk Kargo" : "Mulai Truk Kargo Sekarang"}
                </Button>
              </CardContent>
            </Card>
          </div>

        </div>
      )}

      {/* E. TAMPILAN PROTEKSI KEAMANAN */}
      {activeTab === "safety" && (
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
          <div className="lg:col-span-6 space-y-5">
            
            {/* Spoofing Name Card */}
            <Card className="border-purple-800/60 bg-gradient-to-br from-purple-950/20 via-zinc-900/60 to-zinc-950/80 shadow-lg">
              <CardHeader className="p-4 pb-2 border-b border-purple-900/40 flex flex-row items-center justify-between">
                <CardTitle className="text-xs font-bold uppercase tracking-wider text-purple-400 flex items-center gap-2">
                  <EyeOff className="h-4 w-4 text-purple-400" />
                  Spoofing Name
                </CardTitle>
                <Badge variant={streamerMode ? "purple" : "secondary"} className={`text-[10px] font-bold ${streamerMode ? "bg-purple-500/20 text-purple-300 border border-purple-500/40" : ""}`}>
                  {streamerMode ? "AKTIF" : "NONAKTIF"}
                </Badge>
              </CardHeader>
              <CardContent className="p-4 space-y-3">
                <div className="flex items-center justify-between p-3.5 rounded-xl bg-zinc-900/50 border border-zinc-800/80">
                  <div className="font-semibold text-xs text-zinc-100 flex items-center gap-2">
                    <span>Spoofing Name</span>
                    <span className="bg-purple-950/80 border border-purple-700/60 text-purple-300 font-mono text-[10px] px-2 py-0.5 rounded-md font-bold">
                      {spoofedName}
                    </span>
                  </div>
                  <Switch 
                    checked={streamerMode} 
                    onCheckedChange={handleToggleStreamerMode} 
                  />
                </div>

                <form onSubmit={handleSendCustomSpoof} className="flex items-center gap-2">
                  <input
                    type="text"
                    value={customSpoofInput}
                    onChange={(e) => setCustomSpoofInput(e.target.value)}
                    placeholder="Masukkan custom spoof name..."
                    className="flex-1 bg-zinc-950/80 border border-zinc-800 rounded-lg px-3 py-2 text-xs text-zinc-100 placeholder:text-zinc-500 focus:outline-none focus:border-purple-500 font-mono"
                  />
                  <Button
                    type="submit"
                    size="sm"
                    className="h-8 px-3.5 text-xs font-bold gap-1.5 bg-purple-600 hover:bg-purple-500 text-white shrink-0 shadow-md"
                  >
                    <Send className="h-3.5 w-3.5" />
                    <span>Send</span>
                  </Button>
                </form>
              </CardContent>
            </Card>

            <Card className="border-zinc-800">
              <CardHeader className="p-4 pb-2 border-b border-zinc-800/60">
                <CardTitle className="text-xs font-bold uppercase tracking-wider text-emerald-400 flex items-center gap-2">
                  <ShieldCheck className="h-4 w-4 text-emerald-400" />
                  Gembok Server Private (Server Lock)
                </CardTitle>
              </CardHeader>
              <CardContent className="p-4 space-y-3">
                <div className="flex items-center justify-between p-3.5 rounded-xl bg-zinc-900/40 border border-zinc-800">
                  <div className="space-y-0.5">
                    <div className="font-semibold text-xs text-zinc-200 flex items-center gap-2">
                      {serverLocked ? <Lock className="h-3.5 w-3.5 text-rose-400" /> : <Unlock className="h-3.5 w-3.5 text-zinc-400" />}
                      <span>Status Gembok Server</span>
                    </div>
                    <div className="text-[11px] text-zinc-400">
                      {serverLocked ? "Server digembok, orang lain tidak bisa join" : "Server terbuka untuk umum"}
                    </div>
                  </div>
                  <Button
                    variant={serverLocked ? "destructive" : "outline"}
                    size="sm"
                    className="h-8 text-xs font-bold gap-1.5"
                    onClick={handleToggleServerLock}
                  >
                    {serverLocked ? <Lock className="h-3.5 w-3.5" /> : <Unlock className="h-3.5 w-3.5" />}
                    <span>{serverLocked ? "Buka Gembok" : "Kunci Server"}</span>
                  </Button>
                </div>

                <div className="flex items-center justify-between p-3.5 rounded-xl bg-zinc-900/40 border border-zinc-800">
                  <div>
                    <div className="font-semibold text-xs text-zinc-200">Auto Rejoin Saat Kick</div>
                    <div className="text-[11px] text-zinc-400">Otomatis masuk kembali jika Roblox disconnect</div>
                  </div>
                  <Switch checked={autoRejoin} onCheckedChange={handleToggleAutoRejoin} />
                </div>
              </CardContent>
            </Card>
          </div>

          <div className="lg:col-span-6 space-y-5">
            <Card className="border-zinc-800">
              <CardHeader className="p-4 pb-2 border-b border-zinc-800/60">
                <CardTitle className="text-xs font-bold uppercase tracking-wider text-zinc-400 flex items-center gap-2">
                  <ShieldCheck className="h-4 w-4 text-amber-400" />
                  Player Detector & Aksi Darurat
                </CardTitle>
              </CardHeader>
              <CardContent className="p-4 space-y-3">
                <div className="flex items-center justify-between p-3 rounded-xl bg-zinc-900/40 border border-zinc-800">
                  <div>
                    <div className="font-semibold text-xs text-zinc-200">Deteksi Pemain Mendekat</div>
                    <div className="text-[11px] text-zinc-400">Deteksi jika ada player lain di sekitar bot</div>
                  </div>
                  <Switch
                    checked={playerDetector}
                    onCheckedChange={(checked) => handleSafetyUpdate(checked, undefined, undefined)}
                  />
                </div>

                <div className="flex items-center justify-between p-3 rounded-xl bg-zinc-900/40 border border-zinc-800">
                  <div>
                    <div className="font-semibold text-xs text-zinc-200">Abaikan Teman Roblox</div>
                    <div className="text-[11px] text-zinc-400">Tidak memicu alarm jika yang mendekat teman</div>
                  </div>
                  <Switch
                    checked={ignoreFriends}
                    onCheckedChange={(checked) => handleSafetyUpdate(undefined, undefined, checked)}
                  />
                </div>

                <div className="p-3 rounded-xl bg-zinc-900/40 border border-zinc-800 space-y-1.5">
                  <label className="text-xs font-semibold text-zinc-200 block">Aksi Darurat Jika Terdeteksi</label>
                  <Select
                    value={emergencyAction}
                    onValueChange={(val) => handleSafetyUpdate(undefined, val, undefined)}
                  >
                    <SelectTrigger className="h-9 text-xs bg-zinc-950 border-zinc-700">
                      <SelectValue placeholder="Pilih Aksi" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="Warn Only">Peringatan Saja (Warn Only)</SelectItem>
                      <SelectItem value="Server Hop">Pindah Server (Server Hop)</SelectItem>
                      <SelectItem value="Kick Self">Keluar Game (Kick Self)</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </CardContent>
            </Card>
          </div>
        </div>
      )}

      {/* F. TAMPILAN KONSOL & OPTIMASI */}
      {activeTab === "console" && (
        <div className="space-y-5">
          {/* Baris Optimasi Tampilan */}
          <Card className="border-zinc-800">
            <CardHeader className="p-4 pb-2 border-b border-zinc-800/60">
              <CardTitle className="text-xs font-bold uppercase tracking-wider text-purple-400 flex items-center gap-2">
                <Zap className="h-4 w-4 text-purple-400" />
                Optimasi Grafis & Tampilan (GPU Saver)
              </CardTitle>
            </CardHeader>
            <CardContent className="p-4">
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div className="flex items-center justify-between p-3 rounded-xl bg-zinc-900/40 border border-zinc-800">
                  <div>
                    <div className="font-semibold text-xs text-zinc-200 flex items-center gap-1.5">
                      <Gauge className="h-3.5 w-3.5 text-amber-400" /> Low Render (GPU)
                    </div>
                    <div className="text-[10px] text-zinc-400">Turunkan beban FPS / GPU</div>
                  </div>
                  <Switch checked={lowRender} onCheckedChange={handleToggleLowRender} />
                </div>

                <div className="flex items-center justify-between p-3 rounded-xl bg-zinc-900/40 border border-zinc-800">
                  <div>
                    <div className="font-semibold text-xs text-zinc-200 flex items-center gap-1.5">
                      <Sun className="h-3.5 w-3.5 text-yellow-400" /> Fullbright
                    </div>
                    <div className="text-[10px] text-zinc-400">Pencahayaan terang maksimal</div>
                  </div>
                  <Switch checked={fullbright} onCheckedChange={handleToggleFullbright} />
                </div>

                <div className="flex items-center justify-between p-3 rounded-xl bg-zinc-900/40 border border-zinc-800">
                  <div>
                    <div className="font-semibold text-xs text-zinc-200 flex items-center gap-1.5">
                      <EyeOff className="h-3.5 w-3.5 text-blue-400" /> No Fog
                    </div>
                    <div className="text-[10px] text-zinc-400">Hapus kabut lingkungan</div>
                  </div>
                  <Switch checked={noFog} onCheckedChange={handleToggleNoFog} />
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Terminal Live Logs */}
          <ConsoleTab bot={bot} logs={logs} onClearLogs={onClearLogs} onSendCommand={onSendCommand} />
        </div>
      )}

    </div>
  );
}
