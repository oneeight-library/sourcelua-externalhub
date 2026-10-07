import * as React from "react";
import { Card, CardHeader, CardTitle, CardContent } from "@/ui/card.jsx";
import { Button } from "@/ui/button.jsx";
import { Badge } from "@/ui/badge.jsx";
import { Avatar, AvatarImage, AvatarFallback } from "@/ui/avatar.jsx";
import { Gamepad2, Play, Square, Users } from "lucide-react";
import { getGameConfig } from "@/config/games.js";

export function FleetOverview({ bots, onSelectBot, onSendCommand, onRejoinBot }) {
  let farmingCount = 0;
  let kickedCount = 0;
  for (const [_, b] of bots.entries()) {
    if (b.isFarming) farmingCount++;
    if (b.isKicked) kickedCount++;
  }

  return (
    <div className="space-y-6">
      
      {/* Hero Summary Card */}
      <Card className="border-zinc-800 bg-gradient-to-br from-zinc-900/80 to-zinc-950/80">
        <CardHeader className="p-5 md:p-6 pb-4">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div className="flex items-center gap-3.5">
              <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-indigo-500/10 border border-indigo-500/20 text-indigo-400"><Users className="h-6 w-6" /></div>
              <div>
                <CardTitle className="text-base md:text-lg font-bold">Ringkasan Seluruh Akun</CardTitle>
                <div className="flex items-center gap-2 mt-1">
                  <Badge variant="emerald" className="text-[11px]">
                    {farmingCount} / {bots.size} Bekerja
                  </Badge>
                  {kickedCount > 0 && (
                    <Badge variant="rose" className="text-[11px]">
                      {kickedCount} Terputus
                    </Badge>
                  )}
                </div>
              </div>
            </div>

            {/* Quick Fleet Actions */}
            <div className="flex items-center gap-2">
              <Button
                variant="emerald"
                size="sm"
                className="gap-1.5 font-semibold text-xs h-9"
                onClick={() => onSendCommand("ALL", "START_FARM")}
              >
                <Play className="h-3.5 w-3.5" />
                Mulai Semua
              </Button>
              <Button
                variant="destructive"
                size="sm"
                className="gap-1.5 font-semibold text-xs h-9"
                onClick={() => onSendCommand("ALL", "STOP_FARM")}
              >
                <Square className="h-3.5 w-3.5" />
                Stop Semua
              </Button>
            </div>
          </div>
        </CardHeader>
      </Card>

      {/* Account Cards */}
      <Card className="border-zinc-800">
        <CardHeader className="p-5 pb-3">
          <div className="flex items-center justify-between">
            <CardTitle className="text-sm font-bold flex items-center gap-2">
              <Users className="h-4 w-4 text-zinc-400" />
              Daftar Akun Roblox Aktif
            </CardTitle>
            <Badge variant="secondary" className="text-[10px]">{bots.size} Akun</Badge>
          </div>
        </CardHeader>
        
        <CardContent className="p-5 pt-0">
          {bots.size === 0 ? (
            <div className="text-center py-12 px-4 border border-dashed border-zinc-800 rounded-xl">
              <div className="text-zinc-600 mb-3 flex justify-center"><Gamepad2 className="h-10 w-10" /></div>
              <h4 className="font-bold text-sm text-zinc-200">Belum Ada Akun Terhubung</h4>
              <p className="text-xs text-zinc-400 max-w-sm mx-auto mt-1 leading-relaxed">
                Jalankan script loader di executor Roblox akun Anda untuk mulai mengontrol auto farm dari dashboard ini.
              </p>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              {Array.from(bots.entries()).map(([id, b]) => {
                const gameCfg = getGameConfig(b.gameId);
                const initial = (b.name || "B").substring(0, 2).toUpperCase();

                return (
                  <div
                    key={id}
                    onClick={() => onSelectBot(id)}
                    className={`flex items-center justify-between p-3.5 rounded-xl border transition-all cursor-pointer ${
                      b.isKicked 
                        ? "bg-rose-950/10 border-rose-900/30 hover:border-rose-800/60" 
                        : "bg-zinc-900/40 border-zinc-800 hover:border-zinc-700 hover:bg-zinc-900/60"
                    }`}
                  >
                    <div className="flex items-center gap-3 min-w-0">
                      <div className="relative shrink-0">
                        <Avatar className="h-11 w-11 border-zinc-700">
                          {b.avatarUrl && <AvatarImage src={b.avatarUrl} alt={b.name} />}
                          <AvatarFallback>{initial}</AvatarFallback>
                        </Avatar>
                        <span className={`absolute -bottom-0.5 -right-0.5 h-2.5 w-2.5 rounded-full border-2 border-zinc-950 ${
                          b.isKicked ? "bg-rose-500" : (b.isFarming ? "bg-emerald-500" : "bg-amber-500")
                        }`} />
                      </div>

                      <div className="min-w-0">
                        <div className="flex items-center gap-1.5">
                          <span className="font-bold text-xs text-zinc-100 truncate">{b.name || "Bot"}</span>
                          <span className="text-[11px]">{gameCfg.icon}</span>
                        </div>
                        <div className="text-xs font-mono text-emerald-400 font-semibold mt-0.5">
                          {gameCfg.formatMoney(b.currentCash)}
                        </div>
                        <div className="text-[10px] text-zinc-400 truncate mt-0.5">
                          {b.isKicked ? (
                            <span className="text-rose-400 font-semibold">{gameCfg.name} • Terputus</span>
                          ) : b.isFarming ? (
                            <span className="text-emerald-400 font-semibold">{gameCfg.name} • {b.job || gameCfg.defaultJob}</span>
                          ) : (
                            <span>{gameCfg.name} • Standby</span>
                          )}
                        </div>
                      </div>
                    </div>

                    <div className="flex items-center gap-2 shrink-0 ml-3" onClick={(e) => e.stopPropagation()}>
                      {b.isKicked ? (
                        <Button
                          variant="destructive"
                          size="sm"
                          className="h-8 text-xs px-2.5"
                          onClick={() => onRejoinBot(id)}
                        >
                          Rejoin
                        </Button>
                      ) : (
                        <Button
                          variant={b.isFarming ? "destructive" : "emerald"}
                          size="sm"
                          className="h-8 text-xs px-3"
                          onClick={() => onSendCommand(id, b.isFarming ? "STOP_FARM" : "START_FARM")}
                        >
                          {b.isFarming ? "Berhenti" : "Mulai"}
                        </Button>
                      )}
                      
                      <Button
                        variant="outline"
                        size="sm"
                        className="h-8 text-xs px-2.5"
                        onClick={() => onSelectBot(id)}
                      >
                        Detail &rarr;
                      </Button>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </CardContent>
      </Card>

    </div>
  );
}
