import * as React from "react";
import { Card, CardHeader, CardTitle, CardContent } from "@/ui/card.jsx";
import { Button } from "@/ui/button.jsx";
import { Badge } from "@/ui/badge.jsx";
import { Play, Square, Navigation, Truck, Zap } from "lucide-react";
import { formatRupiah } from "@/lib/utils.js";

export function CDIDFarmTab({ bot, onSendCommand }) {
  const isFarming = bot.isFarming;

  return (
    <div className="space-y-4">
      
      {/* Control Card */}
      <Card className="border-zinc-800 bg-gradient-to-br from-zinc-900/50 to-zinc-950/50">
        <CardHeader className="p-4 pb-3 flex flex-row items-center justify-between">
          <CardTitle className="text-sm font-bold flex items-center gap-2">
            <Truck className="h-4 w-4 text-emerald-400" />
            Kontrol Auto Farm Truk Kargo
          </CardTitle>
          <Badge variant={isFarming ? "emerald" : "secondary"}>
            {isFarming ? "SEDANG AKTIF" : "STANDBY"}
          </Badge>
        </CardHeader>
        <CardContent className="p-4 pt-1 space-y-4">
          <div className="flex items-center gap-3">
            <Button
              variant={isFarming ? "destructive" : "emerald"}
              className="flex-1 font-bold text-sm h-11 gap-2 shadow-lg"
              onClick={() => onSendCommand(bot.botId, isFarming ? "STOP_FARM" : "START_FARM")}
            >
              {isFarming ? <Square className="h-4 w-4" /> : <Play className="h-4 w-4" />}
              {isFarming ? "Hentikan Auto Farm" : "Mulai Auto Farm Truk"}
            </Button>
          </div>

          {/* Telemetry Status Grid */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5 pt-1">
            <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800">
              <span className="text-[10px] font-semibold uppercase text-zinc-400 block">Status Rute</span>
              <span className="text-xs font-bold text-zinc-100 truncate block mt-0.5">{bot.currentRoute || "Menunggu Instruksi"}</span>
            </div>
            <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800">
              <span className="text-[10px] font-semibold uppercase text-zinc-400 block">Total Pengiriman</span>
              <span className="text-xs font-bold text-emerald-400 font-mono block mt-0.5">{bot.tripCount || 0} Pengiriman</span>
            </div>
            <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800">
              <span className="text-[10px] font-semibold uppercase text-zinc-400 block">Kecepatan Truk</span>
              <span className="text-xs font-bold text-zinc-100 font-mono block mt-0.5">{bot.speed || 0} KP/H</span>
            </div>
            <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800">
              <span className="text-[10px] font-semibold uppercase text-zinc-400 block">Jarak Tujuan</span>
              <span className="text-xs font-bold text-zinc-100 font-mono block mt-0.5">{bot.distRemaining || "0m"}</span>
            </div>
          </div>
        </CardContent>
      </Card>

    </div>
  );
}
