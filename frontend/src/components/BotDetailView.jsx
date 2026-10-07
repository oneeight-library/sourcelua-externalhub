import * as React from "react";
import { Card, CardContent } from "@/ui/card.jsx";
import { Button } from "@/ui/button.jsx";
import { Badge } from "@/ui/badge.jsx";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/ui/tabs.jsx";
import { Avatar, AvatarImage, AvatarFallback } from "@/ui/avatar.jsx";
import { ConsoleTab } from "@/components/tabs/ConsoleTab.jsx";
import { SafetyTab } from "@/components/tabs/SafetyTab.jsx";
import { CDIDFarmTab } from "@/components/tabs/CDIDFarmTab.jsx";
import { CDIDMenuTab } from "@/components/tabs/CDIDMenuTab.jsx";
import { PerfTab } from "@/components/tabs/PerfTab.jsx";
import { getGameConfig } from "@/config/games.js";
import { RotateCcw } from "lucide-react";

export function BotDetailView({ bot, activeTab, onTabChange, logs, onClearLogs, onSendCommand, onRejoinBot }) {
  const gameCfg = getGameConfig(bot.gameId);
  const isKicked = bot.isKicked;
  const initial = (bot.name || "B").substring(0, 2).toUpperCase();

  // Pastikan tab aktif selalu valid sesuai game bot
  const currentTab = gameCfg.tabs.some((t) => t.id === activeTab) ? activeTab : gameCfg.tabs[0].id;

  return (
    <div className="space-y-6">
      
      {/* Alert Banner if kicked (Single prominent action, no duplicates!) */}
      {isKicked && (
        <div className="flex items-center justify-between p-4 rounded-xl bg-rose-950/20 border border-rose-900/40 text-rose-300">
          <div className="flex items-center gap-3">
            <span className="text-2xl">🚨</span>
            <div>
              <div className="font-bold text-sm">Koneksi Roblox Terputus (Kick)</div>
              <div className="text-xs text-rose-400/80">Alasan: {bot.kickReason || "Disconnect"}</div>
            </div>
          </div>
          <Button
            variant="destructive"
            size="sm"
            className="gap-1.5 font-semibold text-xs h-8"
            onClick={() => onRejoinBot(bot.botId)}
          >
            <RotateCcw className="h-3 w-3" />
            Rejoin Sekarang
          </Button>
        </div>
      )}

      {/* Hero Card with 3D Avatar */}
      <Card className="border-zinc-800 bg-gradient-to-br from-zinc-900/80 via-zinc-950/60 to-zinc-950/90 shadow-lg">
        <CardContent className="p-5 md:p-6 space-y-5">
          
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            
            {/* Bot Profile */}
            <div className="flex items-center gap-4">
              <Avatar className="h-14 w-14 border-2 border-zinc-700 shadow-xl rounded-2xl">
                {bot.avatarUrl && <AvatarImage src={bot.avatarUrl} alt={bot.name} />}
                <AvatarFallback className="rounded-2xl text-base font-black">
                  {isKicked ? "🚨" : initial}
                </AvatarFallback>
              </Avatar>

              <div>
                <div className="flex items-center gap-2">
                  <h2 className="text-lg md:text-xl font-extrabold tracking-tight text-zinc-100">{bot.name || "Roblox Player"}</h2>
                  <span className="text-sm">{gameCfg.icon}</span>
                </div>
                <div className="flex items-center gap-2 mt-1">
                  <Badge variant={isKicked ? "rose" : (bot.isFarming ? "emerald" : "secondary")} className="text-[11px] font-semibold">
                    {isKicked ? `Terputus (${bot.kickReason || 'Kick'})` : (bot.isFarming ? (bot.status || 'Aktif Bekerja') : 'Standby')}
                  </Badge>
                  <span className="text-xs text-zinc-400 font-medium">{gameCfg.name}</span>
                </div>
              </div>
            </div>

          </div>

          {/* Stats Bar */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 pt-2 border-t border-zinc-800/60">
            <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800/80">
              <span className="text-[10px] font-bold uppercase tracking-wider text-zinc-400">Saldo Akun</span>
              <div className="text-sm md:text-base font-extrabold text-emerald-400 font-mono mt-0.5">
                {gameCfg.formatMoney(bot.currentCash)}
              </div>
            </div>

            <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800/80">
              <span className="text-[10px] font-bold uppercase tracking-wider text-zinc-400">Hasil Sesi Ini</span>
              <div className="text-sm md:text-base font-extrabold text-emerald-400 font-mono mt-0.5">
                +{gameCfg.formatMoney(bot.totalEarnings)}
              </div>
            </div>

            <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800/80">
              <span className="text-[10px] font-bold uppercase tracking-wider text-zinc-400">{gameCfg.metricLabel || 'Selesai'}</span>
              <div className="text-sm md:text-base font-extrabold text-zinc-100 font-mono mt-0.5">
                {bot.tripCount || 0} {gameCfg.metricUnit}
              </div>
            </div>

            <div className="p-3 rounded-xl bg-zinc-900/50 border border-zinc-800/80">
              <span className="text-[10px] font-bold uppercase tracking-wider text-zinc-400">Durasi Sesi</span>
              <div className="text-sm md:text-base font-extrabold text-zinc-100 font-mono mt-0.5">
                {bot.sessionTime || "00:00:00"}
              </div>
            </div>
          </div>

        </CardContent>
      </Card>

      {/* Tabs */}
      <Tabs value={currentTab} onValueChange={onTabChange} className="w-full">
        <TabsList className="mb-4">
          {gameCfg.tabs.map((t) => (
            <TabsTrigger key={t.id} value={t.id}>
              {t.label}
            </TabsTrigger>
          ))}
        </TabsList>

        <TabsContent value="tab_server_gateway">
          <CDIDMenuTab bot={bot} onSendCommand={onSendCommand} />
        </TabsContent>

        <TabsContent value="tab_autofarm">
          <CDIDFarmTab bot={bot} onSendCommand={onSendCommand} />
        </TabsContent>

        <TabsContent value="tab_safety">
          <SafetyTab bot={bot} onSendCommand={onSendCommand} onRejoinBot={onRejoinBot} />
        </TabsContent>

        <TabsContent value="tab_perf">
          <PerfTab bot={bot} onSendCommand={onSendCommand} />
        </TabsContent>

        <TabsContent value="tab_logs">
          <ConsoleTab bot={bot} logs={logs} onClearLogs={onClearLogs} />
        </TabsContent>
      </Tabs>

    </div>
  );
}
