import * as React from "react";
import { Card, CardHeader, CardTitle, CardContent } from "@/ui/card.jsx";
import { Button } from "@/ui/button.jsx";
import { Badge } from "@/ui/badge.jsx";
import { Switch } from "@/ui/switch.jsx";
import {
  Truck,
  Gamepad2,
  Play,
  Square,
  Trophy,
  Package,
  Swords,
  Crown,
  Bot,
  Gift,
  Sparkles
} from "lucide-react";

export function CDIDFarmTab({ bot, onSendCommand }) {
  const isFarming = bot.isFarming;
  const isMinigameActive = bot.job && bot.job.includes("Minigame");

  const [jobMode, setJobMode] = React.useState(isMinigameActive ? "minigame" : "truck");
  const [role, setRole] = React.useState(bot.minigame?.role || "Winner");
  const [autoOpenBox, setAutoOpenBox] = React.useState(bot.minigame?.autoOpenBox || false);

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

  const mg = bot.minigame || {};

  return (
    <div className="space-y-4">
      {/* Job Mode Selector Tabs */}
      <div className="flex items-center gap-2 p-1.5 rounded-xl bg-zinc-900/60 border border-zinc-800/80 backdrop-blur-sm">
        <button
          onClick={() => setJobMode("truck")}
          className={`flex-1 flex items-center justify-center gap-2 py-2 px-3 rounded-lg text-xs font-bold transition-all ${
            jobMode === "truck"
              ? "bg-zinc-800 text-emerald-400 shadow-sm border border-zinc-700/60"
              : "text-zinc-400 hover:text-zinc-200 hover:bg-zinc-850/50"
          }`}
        >
          <Truck className="h-4 w-4" />
          <span>Truk Kargo (Jatim)</span>
          {isFarming && !isMinigameActive && (
            <span className="h-1.5 w-1.5 rounded-full bg-emerald-400 animate-pulse" />
          )}
        </button>

        <button
          onClick={() => setJobMode("minigame")}
          className={`flex-1 flex items-center justify-center gap-2 py-2 px-3 rounded-lg text-xs font-bold transition-all ${
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

      {/* MODE 1: TRUK KARGO (JAWA TIMUR) */}
      {jobMode === "truck" && (
        <Card className="border-zinc-800 bg-gradient-to-br from-zinc-900/50 to-zinc-950/50">
          <CardHeader className="p-4 pb-3 flex flex-row items-center justify-between">
            <CardTitle className="text-sm font-bold flex items-center gap-2">
              <Truck className="h-4 w-4 text-emerald-400" />
              Kontrol Auto Farm Truk Kargo
            </CardTitle>
            <Badge variant={isFarming && !isMinigameActive ? "emerald" : "secondary"}>
              {isFarming && !isMinigameActive ? "SEDANG AKTIF" : "STANDBY"}
            </Badge>
          </CardHeader>
          <CardContent className="p-4 pt-1 space-y-4">
            <div className="flex items-center gap-3">
              <Button
                variant={isFarming && !isMinigameActive ? "destructive" : "emerald"}
                className="flex-1 font-bold text-sm h-11 gap-2 shadow-lg"
                onClick={() => onSendCommand(bot.botId, isFarming ? "STOP_FARM" : "START_FARM", { jobType: "truck" })}
              >
                {isFarming && !isMinigameActive ? <Square className="h-4 w-4" /> : <Play className="h-4 w-4" />}
                {isFarming && !isMinigameActive ? "Hentikan Auto Farm Truk" : "Mulai Auto Farm Truk Kargo"}
              </Button>
            </div>

            <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5 pt-1">
              <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800">
                <span className="text-[10px] font-semibold uppercase text-zinc-400 block">Status Rute</span>
                <span className="text-xs font-bold text-zinc-100 truncate block mt-0.5">{(bot.currentRoute || "Menunggu Instruksi").replace(/\s*\(.*?\)/g, "").trim()}</span>
              </div>
              <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800">
                <span className="text-[10px] font-semibold uppercase text-zinc-400 block">Total Pengiriman</span>
                <span className="text-xs font-bold text-emerald-400 font-mono block mt-0.5">{bot.tripCount || 0} Pengiriman</span>
              </div>
              <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800">
                <span className="text-[10px] font-semibold uppercase text-zinc-400 block">Kecepatan Truk</span>
                <span className="text-xs font-bold text-zinc-100 font-mono block mt-0.5">{bot.speed || 0} KM/H</span>
              </div>
              <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800">
                <span className="text-[10px] font-semibold uppercase text-zinc-400 block">Jarak Tujuan</span>
                <span className="text-xs font-bold text-zinc-100 font-mono block mt-0.5">{bot.distRemaining || "0m"}</span>
              </div>
            </div>
          </CardContent>
        </Card>
      )}

      {/* MODE 2: MINIGAMES SUMO (JAKARTA) */}
      {jobMode === "minigame" && (
        <Card className="border-zinc-800 bg-gradient-to-br from-zinc-900/50 to-zinc-950/50">
          <CardHeader className="p-4 pb-3 flex flex-row items-center justify-between">
            <CardTitle className="text-sm font-bold flex items-center gap-2">
              <Gamepad2 className="h-4 w-4 text-cyan-400" />
              Kontrol Minigames Sumo (Jakarta)
            </CardTitle>
            <Badge variant={isMinigameActive ? "emerald" : "secondary"}>
              {isMinigameActive ? "MINIGAME AKTIF" : "STANDBY"}
            </Badge>
          </CardHeader>
          <CardContent className="p-4 pt-1 space-y-4">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 p-3 rounded-xl bg-zinc-900/60 border border-zinc-800">
              <div>
                <label className="text-xs font-bold text-zinc-300 block mb-1.5 flex items-center gap-1.5">
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
                <span className="text-xs font-bold text-amber-400 font-mono block mt-0.5">
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
                <span className="text-xs font-bold text-zinc-100 font-mono block mt-0.5">
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
                <span className="text-xs font-bold text-cyan-400 font-mono block mt-0.5">
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