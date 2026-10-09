import * as React from "react";
import { Card, CardHeader, CardTitle, CardContent } from "@/ui/card.jsx";
import { Button } from "@/ui/button.jsx";
import { Badge } from "@/ui/badge.jsx";
import { Switch } from "@/ui/switch.jsx";
import {
  Truck,
  Gamepad2,
  Coffee,
  Play,
  Square,
  Trophy,
  Package,
  Swords,
  Crown,
  Bot,
  Gift,
  Sparkles,
  MapPin,
  Navigation,
  CheckCircle2,
  AlertTriangle,
  RotateCcw
} from "lucide-react";
import { JobProgressView } from "@/components/JobProgressView.jsx";

export function CDIDFarmTab({ bot, onSendCommand }) {
  // SSOT: Single Source of Truth
  const features = bot.features || {};

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

  const placeLower = (bot.placeName || "").toLowerCase();
  const isJakarta = placeLower.includes("jakarta") || bot.placeId === "14005966837" || bot.placeId === 14005966837;
  const isJatim = placeLower.includes("jawa timur") || bot.placeId === "110369730911937" || bot.placeId === 110369730911937;

  // Mode default berdasarkan map & status bot
  const initialMode = isJatim
    ? "truck"
    : isBaristaActive
    ? "kanji_jawa"
    : isMinigameActive
    ? "minigame"
    : isJakarta
    ? "kanji_jawa"
    : "truck";

  const [jobMode, setJobMode] = React.useState(initialMode);
  const [role, setRole] = React.useState(bot.minigame?.role || "Winner");
  const [autoOpenBox, setAutoOpenBox] = React.useState(bot.minigame?.autoOpenBox || false);

  React.useEffect(() => {
    if (isBaristaActive) {
      setJobMode("kanji_jawa");
    } else if (isMinigameActive) {
      setJobMode("minigame");
    }
  }, [isBaristaActive, isMinigameActive]);

  React.useEffect(() => {
    if (bot.minigame?.role) setRole(bot.minigame.role);
    if (bot.minigame?.autoOpenBox !== undefined) setAutoOpenBox(bot.minigame.autoOpenBox);
  }, [bot.minigame]);

  const handleStartMinigame = () => {
    onSendCommand(bot.botId, "START_MINIGAME_FARM", {
      role: role,
      autoOpenBox: autoOpenBox
    });
  };

  const handleStopMinigame = () => {
    onSendCommand(bot.botId, "STOP_MINIGAME_FARM");
  };

  const handleBuyBox = () => {
    onSendCommand(bot.botId, "BUY_MINIGAME_BOX");
  };

  const handleStartBarista = () => {
    onSendCommand(bot.botId, "START_KANJI_JAWA_FARM");
  };

  const handleStopBarista = () => {
    onSendCommand(bot.botId, "STOP_KANJI_JAWA_FARM");
  };

  const handleTeleportCafe = () => {
    onSendCommand(bot.botId, "TELEPORT_CAFE");
  };

  const mg = bot.minigame || {};
  const barista = bot.barista || {};

  const formatRupiah = (val) => {
    const num = Number(val) || 0;
    return "Rp " + num.toLocaleString("id-ID");
  };

  return (
    <div className="space-y-4">
      {/* Dynamic Place & Job Context Header */}
      {isJakarta ? (
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 p-3 rounded-xl bg-amber-950/20 border border-amber-800/30 text-xs">
          <div className="flex items-center gap-2.5">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-amber-500/20 text-amber-400 shrink-0">
              {jobMode === "kanji_jawa" ? <Coffee className="h-4 w-4" /> : <Gamepad2 className="h-4 w-4" />}
            </div>
            <div>
              <span className="font-bold text-amber-200 block">Map CDID Jakarta Terdeteksi</span>
              <span className="text-[11px] text-zinc-400">Pilih job: Kanji Jiwa (Barista) atau Minigames Sumo Arena</span>
            </div>
          </div>

          {/* Selector Job di Map Jakarta */}
          <div className="flex items-center gap-1.5 p-1 rounded-lg bg-zinc-900/90 border border-zinc-800 shrink-0">
            <button
              onClick={() => setJobMode("kanji_jawa")}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-md text-xs font-bold transition-all ${
                jobMode === "kanji_jawa"
                  ? "bg-amber-600 text-white shadow-sm"
                  : "text-zinc-400 hover:text-amber-300"
              }`}
            >
              <Coffee className="h-3.5 w-3.5" />
              <span>Kanji Jiwa</span>
              {isBaristaActive && <span className="h-1.5 w-1.5 rounded-full bg-emerald-400 animate-pulse" />}
            </button>
            <button
              onClick={() => setJobMode("minigame")}
              className={`flex items-center gap-1.5 px-3 py-1.5 rounded-md text-xs font-bold transition-all ${
                jobMode === "minigame"
                  ? "bg-cyan-600 text-white shadow-sm"
                  : "text-zinc-400 hover:text-cyan-300"
              }`}
            >
              <Gamepad2 className="h-3.5 w-3.5" />
              <span>Minigames Sumo</span>
              {isMinigameActive && <span className="h-1.5 w-1.5 rounded-full bg-cyan-400 animate-pulse" />}
            </button>
          </div>
        </div>
      ) : isJatim ? (
        <div className="flex items-center justify-between p-3 rounded-xl bg-emerald-950/40 border border-emerald-800/40 text-xs">
          <div className="flex items-center gap-2.5">
            <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-emerald-500/20 text-emerald-400">
              <Truck className="h-4 w-4" />
            </div>
            <div>
              <span className="font-bold text-emerald-200 block">Map Jawa Timur Terdeteksi</span>
              <span className="text-[11px] text-zinc-400">Job Tersedia: Pengiriman Truk Kargo</span>
            </div>
          </div>
          <Badge variant="outline" className="border-emerald-700/60 text-emerald-300 bg-emerald-950/60 text-[10px] font-semibold">
            CARGO EXPEDITION
          </Badge>
        </div>
      ) : (
        /* Jika di map lain / custom, sediakan 3 tab switch antar job */
        <div className="flex items-center gap-2 p-1.5 rounded-xl bg-zinc-900/60 border border-zinc-800/80 backdrop-blur-sm overflow-x-auto">
          <button
            onClick={() => setJobMode("kanji_jawa")}
            className={`flex-1 flex items-center justify-center gap-2 py-2 px-3 rounded-lg text-xs font-bold transition-all whitespace-nowrap ${
              jobMode === "kanji_jawa"
                ? "bg-zinc-800 text-amber-400 shadow-sm border border-zinc-700/60"
                : "text-zinc-400 hover:text-zinc-200 hover:bg-zinc-850/50"
            }`}
          >
            <Coffee className="h-4 w-4" />
            <span>Kanji Jiwa (Barista)</span>
            {isBaristaActive && (
              <span className="h-1.5 w-1.5 rounded-full bg-amber-400 animate-pulse" />
            )}
          </button>

          <button
            onClick={() => setJobMode("truck")}
            className={`flex-1 flex items-center justify-center gap-2 py-2 px-3 rounded-lg text-xs font-bold transition-all whitespace-nowrap ${
              jobMode === "truck"
                ? "bg-zinc-800 text-emerald-400 shadow-sm border border-zinc-700/60"
                : "text-zinc-400 hover:text-zinc-200 hover:bg-zinc-850/50"
            }`}
          >
            <Truck className="h-4 w-4" />
            <span>Truk Kargo (Jatim)</span>
            {isTruckFarming && (
              <span className="h-1.5 w-1.5 rounded-full bg-emerald-400 animate-pulse" />
            )}
          </button>

          <button
            onClick={() => setJobMode("minigame")}
            className={`flex-1 flex items-center justify-center gap-2 py-2 px-3 rounded-lg text-xs font-bold transition-all whitespace-nowrap ${
              jobMode === "minigame"
                ? "bg-zinc-800 text-cyan-400 shadow-sm border border-zinc-700/60"
                : "text-zinc-400 hover:text-zinc-200 hover:bg-zinc-850/50"
            }`}
          >
            <Gamepad2 className="h-4 w-4" />
            <span>Minigames Sumo (Jakarta)</span>
            {isMinigameActive && (
              <span className="h-1.5 w-1.5 rounded-full bg-cyan-400 animate-pulse" />
            )}
          </button>
        </div>
      )}

      {/* =========================================================================
          MODE 1: CAFE KANJI JAWA / BARISTA (MAP JAKARTA)
          ========================================================================= */}
      {(jobMode === "kanji_jawa" || (isJakarta && jobMode !== "minigame" && !isJatim)) && (
        <>
        <Card className="border-zinc-800 bg-gradient-to-br from-zinc-900/60 via-amber-950/10 to-zinc-950/60">
          <CardHeader className="p-4 pb-3 flex flex-row items-center justify-between">
            <CardTitle className="text-sm font-bold flex items-center gap-2">
              <Coffee className="h-4 w-4 text-amber-400" />
              Kontrol Auto Farm Kanji Jiwa (Barista)
            </CardTitle>
            <div className="flex items-center gap-2">
              <Badge variant={isBaristaActive ? "amber" : "secondary"} className={isBaristaActive ? "bg-amber-500/20 text-amber-300 border-amber-500/30" : ""}>
                {isBaristaActive ? "BARISTA BEKERJA" : "STANDBY"}
              </Badge>
            </div>
          </CardHeader>
          <CardContent className="p-4 pt-1 space-y-4">
            <div className="flex items-center gap-3 flex-wrap">
              <Button
                variant={isBaristaActive ? "destructive" : "amber"}
                className={`flex-1 font-bold text-sm h-11 gap-2 shadow-lg ${!isBaristaActive ? "bg-amber-600 hover:bg-amber-500 text-white" : ""}`}
                onClick={isBaristaActive ? handleStopBarista : handleStartBarista}
              >
                {isBaristaActive ? <Square className="h-4 w-4" /> : <Play className="h-4 w-4" />}
                {isBaristaActive ? "Hentikan Barista Farm" : "Mulai Auto Farm Kanji Jiwa"}
              </Button>

              <Button
                variant="outline"
                size="sm"
                className="h-11 px-4 border-zinc-700 text-zinc-300 hover:text-amber-300 hover:bg-zinc-800 font-semibold gap-2"
                onClick={handleTeleportCafe}
              >
                <MapPin className="h-4 w-4 text-amber-400" />
                Teleport ke Kafe
              </Button>
            </div>

            {/* Live Progress Barista Card */}
            {barista.currentOrder?.MenuId && (
              <div className="p-3 rounded-xl bg-amber-950/30 border border-amber-700/40 text-xs space-y-1.5">
                <div className="flex items-center justify-between font-bold text-amber-200">
                  <span className="flex items-center gap-1.5">
                    <Sparkles className="h-3.5 w-3.5 text-amber-400" />
                    Sedang Meracik: {barista.currentOrder.MenuId}
                    {barista.currentOrder.Flavour && ` (${barista.currentOrder.Flavour})`}
                  </span>
                  <span className="text-[11px] text-amber-400/90 font-mono">
                    Langkah: {barista.currentOrder.DoneCount || 0} / {barista.currentOrder.StepCount || "?"}
                  </span>
                </div>
                <div className="flex items-center justify-between text-[11px] text-zinc-400">
                  <span>Stasiun Berikutnya: <strong className="text-zinc-200">{barista.currentOrder.NextStation || barista.currentOrder.NextStep || "Selesai"}</strong></span>
                  <span>Customer: <strong className="text-zinc-200">{barista.currentCustomer || "-"}</strong></span>
                </div>
              </div>
            )}

            <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5 pt-1">
              <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800">
                <span className="text-[10px] font-semibold uppercase text-zinc-400 block flex items-center gap-1">
                  <CheckCircle2 className="h-3 w-3 text-emerald-400" /> Cup Selesai
                </span>
                <span className="text-xs font-bold text-emerald-400 tabular-nums block mt-0.5">
                  {barista.totalOrders || 0} Cup
                </span>
                <span className="text-[10px] text-zinc-500 block">
                  {barista.ruinedOrders ? `${barista.ruinedOrders} Rusak (Dibuang)` : "100% Sempurna"}
                </span>
              </div>

              <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800">
                <span className="text-[10px] font-semibold uppercase text-zinc-400 block flex items-center gap-1">
                  <Coffee className="h-3 w-3 text-amber-400" /> Gaji Terakhir
                </span>
                <span className="text-xs font-bold text-amber-300 tabular-nums block mt-0.5">
                  {formatRupiah(barista.lastGaji || 0)}
                </span>
                <span className="text-[10px] text-zinc-500 block">
                  Per Cup Selesai
                </span>
              </div>

              <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800">
                <span className="text-[10px] font-semibold uppercase text-zinc-400 block">
                  Hasil Sesi Ini
                </span>
                <span className="text-xs font-bold text-emerald-400 tabular-nums block mt-0.5">
                  +{formatRupiah(barista.totalEarned || 0)}
                </span>
                <span className="text-[10px] text-zinc-500 block">
                  {barista.avgPerHour ? `${formatRupiah(barista.avgPerHour)}/jam` : "Menghitung rate..."}
                </span>
              </div>

              <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800">
                <span className="text-[10px] font-semibold uppercase text-zinc-400 block">
                  Fase Aktivitas
                </span>
                <span className="text-xs font-bold text-zinc-100 truncate block mt-0.5">
                  {barista.phase || (isBaristaActive ? "Aktif" : "Standby")}
                </span>
                <span className="text-[10px] text-zinc-500 truncate block">
                  {barista.currentCustomer && barista.currentCustomer !== "-" ? `Cust: ${barista.currentCustomer}` : "Siap melayani"}
                </span>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Level Progress & Klaim Hadiah Barista */}
        <JobProgressView bot={bot} onSendCommand={onSendCommand} />
        </>
      )}

      {/* =========================================================================
          MODE 2: TRUK KARGO (HANYA DITAMPILKAN JIKA BUKAN DI JAKARTA / MODE TRUCK)
          ========================================================================= */}
      {(!isJakarta && (isJatim || jobMode === "truck")) && (
        <Card className="border-zinc-800 bg-gradient-to-br from-zinc-900/50 to-zinc-950/50">
          <CardHeader className="p-4 pb-3 flex flex-row items-center justify-between">
            <CardTitle className="text-sm font-bold flex items-center gap-2">
              <Truck className="h-4 w-4 text-emerald-400" />
              Kontrol Auto Farm Truk Kargo
            </CardTitle>
            <Badge variant={isTruckFarming ? "emerald" : "secondary"}>
              {isTruckFarming ? "SEDANG AKTIF" : "STANDBY"}
            </Badge>
          </CardHeader>
          <CardContent className="p-4 pt-1 space-y-4">
            <div className="flex items-center gap-3">
              <Button
                variant={isTruckFarming ? "destructive" : "emerald"}
                className="flex-1 font-bold text-sm h-11 gap-2 shadow-lg"
                onClick={() => onSendCommand(bot.botId, isTruckFarming ? "STOP_FARM" : "START_FARM", { jobType: "truck" })}
              >
                {isTruckFarming ? <Square className="h-4 w-4" /> : <Play className="h-4 w-4" />}
                {isTruckFarming ? "Hentikan Auto Farm Truk" : "Mulai Auto Farm Truk Kargo"}
              </Button>
            </div>

            <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5 pt-1">
              <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800">
                <span className="text-[10px] font-semibold uppercase text-zinc-400 block">Status Rute</span>
                <span className="text-xs font-bold text-zinc-100 truncate block mt-0.5">{(bot.currentRoute || "Menunggu Instruksi").replace(/\s*\(.*?\)/g, "").trim()}</span>
              </div>
              <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800">
                <span className="text-[10px] font-semibold uppercase text-zinc-400 block">Total Pengiriman</span>
                <span className="text-xs font-bold text-emerald-400 tabular-nums block mt-0.5">{bot.tripCount || 0} Pengiriman</span>
              </div>
              <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800">
                <span className="text-[10px] font-semibold uppercase text-zinc-400 block">Kecepatan Truk</span>
                <span className="text-xs font-bold text-zinc-100 tabular-nums block mt-0.5">{bot.speed || 0} KM/H</span>
              </div>
              <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800">
                <span className="text-[10px] font-semibold uppercase text-zinc-400 block">Jarak Tujuan</span>
                <span className="text-xs font-bold text-zinc-100 tabular-nums block mt-0.5">{bot.distRemaining || "0m"}</span>
              </div>
            </div>
          </CardContent>
        </Card>
      )}

      {/* =========================================================================
          MODE 3: MINIGAMES SUMO (HANYA DITAMPILKAN JIKA BUKAN DI JATIM / MODE MINIGAME)
          ========================================================================= */}
      {(!isJatim && (jobMode === "minigame")) && (
        <Card className="border-zinc-800 bg-gradient-to-br from-zinc-900/50 to-zinc-950/50">
          <CardHeader className="p-4 pb-3 flex flex-row items-center justify-between">
            <CardTitle className="text-sm font-bold flex items-center gap-2">
              <Gamepad2 className="h-4 w-4 text-cyan-400" />
              Kontrol Minigames Sumo (Jakarta)
            </CardTitle>
            <Badge variant={isMinigameActive ? "cyan" : "secondary"} className={isMinigameActive ? "bg-cyan-500/20 text-cyan-300 border-cyan-500/30" : ""}>
              {isMinigameActive ? "MINIGAME AKTIF" : "STANDBY"}
            </Badge>
          </CardHeader>
          <CardContent className="p-4 pt-1 space-y-4">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 p-3 rounded-xl bg-zinc-900/60 border border-zinc-800">
              <div>
                <label className="text-xs font-bold text-zinc-300 mb-1.5 flex items-center gap-1.5">
                  <Crown className="h-3.5 w-3.5 text-amber-400" />
                  Pilih Peran Akun (Role)
                </label>
                <div className="flex items-center gap-2">
                  <Button
                    type="button"
                    variant={role === "Winner" ? "emerald" : "outline"}
                    size="sm"
                    className="flex-1 text-xs font-bold h-8 gap-1.5"
                    onClick={() => setRole("Winner")}
                  >
                    <Crown className="h-3.5 w-3.5" /> Winner (Menang)
                  </Button>
                  <Button
                    type="button"
                    variant={role === "Loser" ? "destructive" : "outline"}
                    size="sm"
                    className="flex-1 text-xs font-bold h-8 gap-1.5"
                    onClick={() => setRole("Loser")}
                  >
                    <Bot className="h-3.5 w-3.5" /> Loser (Bot Mengalah)
                  </Button>
                </div>
                <span className="text-[10px] text-zinc-500 mt-1 block">
                  {role === "Winner" ? "Akun Utama: Bertahan di ring untuk panen poin & koin." : "Akun Bot: Cepat gugur ronde agar match selesai instan."}
                </span>
              </div>

              <div className="flex flex-col justify-between pt-1 sm:pt-0 sm:border-l sm:border-zinc-800 sm:pl-3">
                <div className="flex items-center justify-between">
                  <span className="text-xs font-semibold text-zinc-200 flex items-center gap-1.5">
                    <Gift className="h-3.5 w-3.5 text-cyan-400" />
                    Auto Buka Box (20 Poin)
                  </span>
                  <Switch
                    checked={autoOpenBox}
                    onCheckedChange={(checked) => setAutoOpenBox(checked)}
                  />
                </div>
                <div className="pt-2">
                  <Button
                    variant="outline"
                    size="sm"
                    className="w-full text-xs font-semibold h-7 border-zinc-700 text-cyan-300 hover:bg-zinc-800 gap-1.5"
                    onClick={handleBuyBox}
                  >
                    <Gift className="h-3 w-3 text-cyan-400" />
                    Beli 1 Box Sekarang (-20 Poin)
                  </Button>
                </div>
              </div>
            </div>

            <div className="flex items-center gap-3">
              <Button
                variant={isMinigameActive ? "destructive" : "emerald"}
                className="flex-1 font-bold text-sm h-11 gap-2 shadow-lg"
                onClick={isMinigameActive ? handleStopMinigame : handleStartMinigame}
              >
                {isMinigameActive ? <Square className="h-4 w-4" /> : <Play className="h-4 w-4" />}
                {isMinigameActive ? "Hentikan Minigame Sumo" : "Mulai Minigame Sumo Sekarang"}
              </Button>
            </div>

            <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5 pt-1">
              <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800">
                <span className="text-[10px] font-semibold uppercase text-zinc-400 block flex items-center gap-1">
                  <Trophy className="h-3 w-3 text-amber-400" /> Poin Minigame
                </span>
                <span className="text-xs font-bold text-amber-400 tabular-nums block mt-0.5">
                  {mg.points || 0} Poin
                </span>
                <span className="text-[10px] text-zinc-500 block">
                  +{mg.pointsEarned || 0} didapat
                </span>
              </div>

              <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800">
                <span className="text-[10px] font-semibold uppercase text-zinc-400 block flex items-center gap-1">
                  <Swords className="h-3 w-3 text-emerald-400" /> Rekor Match
                </span>
                <span className="text-xs font-bold text-zinc-100 tabular-nums block mt-0.5">
                  {mg.wins || 0}W / {mg.losses || 0}L
                </span>
                <span className="text-[10px] text-zinc-500 block">
                  {mg.lastResult || "-"}
                </span>
              </div>

              <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800">
                <span className="text-[10px] font-semibold uppercase text-zinc-400 block flex items-center gap-1">
                  <Package className="h-3 w-3 text-cyan-400" /> Box Terbuka
                </span>
                <span className="text-xs font-bold text-cyan-400 tabular-nums block mt-0.5">
                  {mg.boxes || 0} Box
                </span>
                <span className="text-[10px] text-zinc-500 block">
                  {autoOpenBox ? "Auto Aktif" : "Manual"}
                </span>
              </div>

              <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800">
                <span className="text-[10px] font-semibold uppercase text-zinc-400 block flex items-center gap-1">
                  <Sparkles className="h-3 w-3 text-purple-400" /> Fase Permainan
                </span>
                <span className="text-xs font-bold text-zinc-200 truncate block mt-0.5">
                  {mg.phase || "Standby"}
                </span>
                <span className="text-[10px] text-zinc-500 block">
                  Ronde: {mg.round || 0}/{mg.maxRounds || 10}
                </span>
              </div>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
