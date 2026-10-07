import * as React from "react";
import { Card, CardHeader, CardTitle, CardContent } from "@/ui/card.jsx";
import { Button } from "@/ui/button.jsx";
import { Badge } from "@/ui/badge.jsx";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/ui/tabs.jsx";
import { Avatar, AvatarImage, AvatarFallback } from "@/ui/avatar.jsx";
import { Switch } from "@/ui/switch.jsx";
import { ConsoleTab } from "@/components/tabs/ConsoleTab.jsx";
import { CDIDMenuTab } from "@/components/tabs/CDIDMenuTab.jsx";
import { getGameConfig } from "@/config/games.js";
import { 
  Play, 
  Square, 
  RotateCcw,
  Clock, 
  ShieldCheck, 
  Zap, 
  Activity, 
  Coins, 
  Gauge, 
  Navigation, 
  SlidersHorizontal,
  Sliders,
  Briefcase
} from "lucide-react";

export function BotDetailView({ bot, activeTab, onTabChange, logs, onClearLogs, onSendCommand, onRejoinBot }) {
  const gameCfg = getGameConfig(bot.gameId);
  const isKicked = bot.isKicked;
  const isLobby = bot.gameId === "cdid_menu";
  const initial = (bot.name || "B").substring(0, 2).toUpperCase();
  const isFarming = !!bot.isFarming;
  const [autoRejoin, setAutoRejoin] = React.useState(bot.autoRejoin !== false);
  const [lowRender, setLowRender] = React.useState(!!bot.lowRender);

  const handleToggleAutoRejoin = (checked) => {
    setAutoRejoin(checked);
    onSendCommand(bot.botId, "TOGGLE_AUTO_REJOIN", { enabled: checked });
  };

  const handleToggleLowRender = (checked) => {
    setLowRender(checked);
    onSendCommand(bot.botId, "TOGGLE_LOW_RENDER", { enabled: checked });
  };

  // Durasi Job Aktif (Pause jika autofarm berhenti, resume saat jalan)
  const farmActiveTime = bot.farmActiveTime || (isFarming ? (bot.sessionTime || "00:00:00") : "00:00:00");
  const farmActiveSeconds = bot.farmActiveSeconds || (isFarming ? (bot.sessionSeconds || 0) : 0);

  // Estimasi Rata-Rata per Jam berbasis durasi farm aktif (sangat presisi!)
  const totalEarnings = bot.totalEarnings || 0;
  let avgPerHourStr = "Menghitung...";
  if (farmActiveSeconds >= 30 && totalEarnings > 0) {
    const hourly = Math.floor((totalEarnings / farmActiveSeconds) * 3600);
    avgPerHourStr = gameCfg.formatMoney(hourly) + " / Jam";
  } else if (totalEarnings === 0 && farmActiveSeconds >= 45) {
    avgPerHourStr = "Rp 0 / Jam";
  }

  return (
    <div className="space-y-6">
      
      {/* =========================================================================
          1. HEADER PURE AKUN (100% Bersih dari Telemetri & Job Controls)
          ========================================================================= */}
      <Card className="border-zinc-800 bg-gradient-to-br from-zinc-900/90 to-zinc-950/90 shadow-md">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 p-4 sm:p-5">
          
          <div className="flex items-center gap-4">
            <Avatar className="h-14 w-14 border-2 border-zinc-700 shadow-xl rounded-2xl shrink-0">
              {bot.avatarUrl && <AvatarImage src={bot.avatarUrl} alt={bot.name} />}
              <AvatarFallback className="rounded-2xl text-base font-black">
                {isKicked ? "🚨" : initial}
              </AvatarFallback>
            </Avatar>

            <div>
              <div className="flex items-center gap-2.5 flex-wrap">
                <h2 className="text-lg sm:text-xl font-extrabold tracking-tight text-zinc-100">
                  {bot.name || "Roblox Player"}
                </h2>
                {isKicked ? (
                  <Badge variant="rose" className="text-[11px] font-bold">🚨 Terputus</Badge>
                ) : (
                  <Badge variant={isFarming ? "emerald" : "secondary"} className="text-[11px] font-bold">
                    <span className={`h-1.5 w-1.5 rounded-full mr-1.5 ${isFarming ? 'bg-emerald-400 animate-pulse' : 'bg-amber-400'}`} />
                    {isFarming ? "Sedang Bekerja" : "Standby"}
                  </Badge>
                )}
              </div>

              {/* Pure Info Game & Job */}
              <div className="flex flex-wrap items-center gap-2 mt-1.5">
                <Badge variant="outline" className="border-zinc-700/80 bg-zinc-900/60 text-zinc-300 font-medium text-xs gap-1.5 px-2.5 py-0.5">
                  <span>{gameCfg.icon}</span>
                  <span>{gameCfg.name}</span>
                </Badge>
                
                <Badge variant="secondary" className="bg-zinc-800 text-zinc-300 font-medium text-xs gap-1.5 px-2.5 py-0.5">
                  <Briefcase className="h-3 w-3 text-zinc-400" />
                  <span>Job: {bot.job || gameCfg.defaultJob}</span>
                </Badge>
              </div>
            </div>
          </div>

          {/* Quick Kick Rejoin if Disconnected */}
          {isKicked && (
            <div className="flex items-center gap-2 shrink-0">
              <Button
                variant="destructive"
                size="sm"
                className="gap-1.5 font-bold text-xs h-9 shadow-lg"
                onClick={() => onRejoinBot(bot.botId)}
              >
                <RotateCcw className="h-3.5 w-3.5" />
                Rejoin Sekarang
              </Button>
            </div>
          )}

        </div>
      </Card>

      {/* =========================================================================
          2. DUA GRID (KIRI: INFO TELEMETRI | KANAN: CONTROL HUB)
          ========================================================================= */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">

        {/* -----------------------------------------------------------------------
            GRID KIRI: INFO TELEMETRI (Mata / Observability / Real-time Data)
            ----------------------------------------------------------------------- */}
        <div className="lg:col-span-6 space-y-5">
          
          {/* Card A: Keuangan & Metrik Sesi */}
          <Card className="border-zinc-800">
            <CardHeader className="p-4 pb-2 border-b border-zinc-800/60 flex flex-row items-center justify-between">
              <CardTitle className="text-xs font-bold uppercase tracking-wider text-zinc-400 flex items-center gap-2">
                <Coins className="h-4 w-4 text-emerald-400" />
                Keuangan & Metrik Sesi
              </CardTitle>
              <Badge 
                variant={isFarming ? "emerald" : "secondary"} 
                className="text-[10px] font-mono font-bold flex items-center gap-1.5 px-2 py-0.5 border"
                title={isFarming ? "Durasi Job Berjalan" : "Durasi Job Dijeda (Pause)"}
              >
                <span className={`h-1.5 w-1.5 rounded-full ${isFarming ? 'bg-emerald-400 animate-pulse' : 'bg-amber-400'}`} />
                <span>{farmActiveTime}</span>
                <span className="text-[9px] uppercase tracking-wider text-zinc-400 font-sans font-semibold">
                  {isFarming ? "Aktif" : "Pause"}
                </span>
              </Badge>
            </CardHeader>
            <CardContent className="p-4">
              <div className="grid grid-cols-2 gap-3">
                
                <div className="p-3.5 rounded-xl bg-zinc-900/60 border border-zinc-800/80">
                  <span className="text-[10px] font-bold uppercase tracking-wider text-zinc-400 block">Saldo Akun</span>
                  <div className="text-base sm:text-lg font-black text-emerald-400 font-mono mt-0.5">
                    {gameCfg.formatMoney(bot.currentCash)}
                  </div>
                </div>

                <div className="p-3.5 rounded-xl bg-zinc-900/60 border border-zinc-800/80">
                  <span className="text-[10px] font-bold uppercase tracking-wider text-zinc-400 block">Hasil Sesi Ini</span>
                  <div className="text-base sm:text-lg font-black text-emerald-400 font-mono mt-0.5">
                    +{gameCfg.formatMoney(bot.totalEarnings)}
                  </div>
                </div>

                <div className="p-3.5 rounded-xl bg-zinc-900/60 border border-zinc-800/80">
                  <span className="text-[10px] font-bold uppercase tracking-wider text-zinc-400 block">
                    {gameCfg.metricLabel || "Selesai"}
                  </span>
                  <div className="text-sm sm:text-base font-extrabold text-zinc-100 font-mono mt-0.5">
                    {bot.tripCount || 0} {gameCfg.metricUnit}
                  </div>
                </div>

                <div className="p-3.5 rounded-xl bg-zinc-900/60 border border-zinc-800/80">
                  <span className="text-[10px] font-bold uppercase tracking-wider text-zinc-400 block">Avg / Jam (Estimasi)</span>
                  <div className="text-sm sm:text-base font-extrabold text-emerald-400 font-mono mt-0.5 truncate" title={avgPerHourStr}>
                    {avgPerHourStr}
                  </div>
                </div>

              </div>
            </CardContent>
          </Card>

          {/* Card B: Telemetri Operasional Rute / Map */}
          <Card className="border-zinc-800">
            <CardHeader className="p-4 pb-2 border-b border-zinc-800/60">
              <CardTitle className="text-xs font-bold uppercase tracking-wider text-zinc-400 flex items-center gap-2">
                <Navigation className="h-4 w-4 text-blue-400" />
                Telemetri Operasional Rute
              </CardTitle>
            </CardHeader>
            <CardContent className="p-4">
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-2.5">
                
                <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800 sm:col-span-3">
                  <span className="text-[10px] font-bold uppercase text-zinc-400 block tracking-wider">Status Rute</span>
                  <span className="text-xs font-bold text-zinc-100 mt-0.5 block truncate">
                    {bot.currentRoute || (isLobby ? "Standby di Lobi" : "Menunggu Instruksi")}
                  </span>
                </div>

                <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800">
                  <span className="text-[10px] font-bold uppercase text-zinc-400 block tracking-wider">Kecepatan</span>
                  <span className="text-xs font-bold text-zinc-100 font-mono mt-0.5 block">
                    {bot.speed || 0} KP/H
                  </span>
                </div>

                <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800">
                  <span className="text-[10px] font-bold uppercase text-zinc-400 block tracking-wider">Jarak Sisa</span>
                  <span className="text-xs font-bold text-zinc-100 font-mono mt-0.5 block">
                    {bot.distRemaining || "0m"}
                  </span>
                </div>

                <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800">
                  <span className="text-[10px] font-bold uppercase text-zinc-400 block tracking-wider">Status Gerak</span>
                  <span className="text-xs font-bold text-emerald-400 mt-0.5 block truncate">
                    {bot.status || "Standby"}
                  </span>
                </div>

              </div>
            </CardContent>
          </Card>

          {/* Card C: Live Konsol Log Stream (Per Akun) */}
          <ConsoleTab bot={bot} logs={logs} onClearLogs={onClearLogs} />

        </div>

        {/* -----------------------------------------------------------------------
            GRID KANAN: CONTROL HUB (Tangan / Aksi / Pengaturan / Switches)
            ----------------------------------------------------------------------- */}
        <div className="lg:col-span-6 space-y-5">
          
          {/* Section 1: Kontrol Utama Job (Mulai / Hentikan Farm) */}
          <Card className="border-zinc-800 bg-gradient-to-br from-zinc-900/70 to-zinc-950/70">
            <CardHeader className="p-4 pb-2 border-b border-zinc-800/60 flex flex-row items-center justify-between">
              <CardTitle className="text-xs font-bold uppercase tracking-wider text-zinc-400 flex items-center gap-2">
                <SlidersHorizontal className="h-4 w-4 text-indigo-400" />
                Kontrol Utama Autofarm
              </CardTitle>
              <Badge variant={isFarming ? "emerald" : "secondary"} className="text-[10px] font-bold">
                {isFarming ? "BERJALAN" : "BERHENTI"}
              </Badge>
            </CardHeader>
            <CardContent className="p-4 space-y-3">
              
              <Button
                variant={isFarming ? "destructive" : "emerald"}
                className="w-full font-bold text-sm h-12 gap-2 shadow-lg"
                onClick={() => onSendCommand(bot.botId, isFarming ? "STOP_FARM" : "START_FARM")}
              >
                {isFarming ? <Square className="h-4 w-4" /> : <Play className="h-4 w-4" />}
                {isFarming ? "Hentikan Autofarm" : "Mulai Autofarm Sekarang"}
              </Button>

              {/* Khusus Game Truk CDID: Tombol Depot HQ */}
              {!isLobby && (
                <div className="flex items-center justify-between p-3 rounded-xl bg-zinc-900/40 border border-zinc-800">
                  <div>
                    <div className="font-semibold text-xs text-zinc-200">Teleport Depot Truk (HQ)</div>
                    <div className="text-[11px] text-zinc-400">Pindahkan karakter langsung ke pangkalan truk</div>
                  </div>
                  <Button
                    variant="outline"
                    size="sm"
                    className="h-8 text-xs font-semibold"
                    onClick={() => onSendCommand(bot.botId, "TELEPORT_HQ")}
                  >
                    Teleport HQ
                  </Button>
                </div>
              )}

            </CardContent>
          </Card>

          {/* Section 2: Khusus CDID Menu / Lobi (Portal Gerbang Server & Map) */}
          {isLobby && (
            <CDIDMenuTab bot={bot} onSendCommand={onSendCommand} />
          )}

          {/* Section 3: Proteksi & Rejoin Otomatis */}
          <Card className="border-zinc-800">
            <CardHeader className="p-4 pb-2 border-b border-zinc-800/60">
              <CardTitle className="text-xs font-bold uppercase tracking-wider text-zinc-400 flex items-center gap-2">
                <ShieldCheck className="h-4 w-4 text-emerald-400" />
                Proteksi Koneksi & Server
              </CardTitle>
            </CardHeader>
            <CardContent className="p-4 space-y-3">
              
              <div className="flex items-center justify-between p-3 rounded-xl bg-zinc-900/40 border border-zinc-800">
                <div>
                  <div className="font-semibold text-xs text-zinc-200">Auto Rejoin Saat Kick</div>
                  <div className="text-[11px] text-zinc-400">Otomatis masuk kembali ke server jika terkena disconnect</div>
                </div>
                <Switch checked={autoRejoin} onCheckedChange={handleToggleAutoRejoin} />
              </div>

              <div className="flex items-center justify-between p-3 rounded-xl bg-zinc-900/40 border border-zinc-800">
                <div>
                  <div className="font-semibold text-xs text-zinc-200">Paksa Rejoin Server Baru</div>
                  <div className="text-[11px] text-zinc-400">Pindahkan akun ke instance server baru sekarang</div>
                </div>
                <Button
                  variant="destructive"
                  size="sm"
                  className="gap-1.5 h-8 text-xs font-semibold"
                  onClick={() => onRejoinBot(bot.botId)}
                >
                  <RotateCcw className="h-3 w-3" />
                  Rejoin
                </Button>
              </div>

            </CardContent>
          </Card>

          {/* Section 4: Optimasi Performa & Hemat GPU */}
          <Card className="border-zinc-800">
            <CardHeader className="p-4 pb-2 border-b border-zinc-800/60">
              <CardTitle className="text-xs font-bold uppercase tracking-wider text-zinc-400 flex items-center gap-2">
                <Zap className="h-4 w-4 text-amber-400" />
                Optimasi Performa & GPU
              </CardTitle>
            </CardHeader>
            <CardContent className="p-4">
              <div className="flex items-center justify-between p-3 rounded-xl bg-zinc-900/40 border border-zinc-800">
                <div>
                  <div className="font-semibold text-xs text-zinc-200">Mode Hemat Layar (Black Screen)</div>
                  <div className="text-[11px] text-zinc-400">Mematikan 3D rendering layar untuk menghemat CPU & GPU hingga 85%</div>
                </div>
                <Switch checked={lowRender} onCheckedChange={handleToggleLowRender} />
              </div>
            </CardContent>
          </Card>

        </div>

      </div>

    </div>
  );
}
