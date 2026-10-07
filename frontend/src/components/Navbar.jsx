import * as React from "react";
import { Badge } from "@/ui/badge.jsx";
import { Button } from "@/ui/button.jsx";
import { Sheet, SheetTrigger, SheetContent, SheetHeader, SheetTitle } from "@/ui/sheet.jsx";
import { Avatar, AvatarImage, AvatarFallback } from "@/ui/avatar.jsx";
import { ChevronDown } from "lucide-react";
import { getGameConfig } from "@/config/games.js";

export function Navbar({ bots, selectedBotId, onSelectBot, isWsOnline, wsStatus }) {
  const [isOpen, setIsOpen] = React.useState(false);

  const selectedBot = bots.get(selectedBotId);
  const currentLabel = selectedBotId === "ALL" 
    ? `🌐 Semua Akun (${bots.size})` 
    : (selectedBot ? selectedBot.name : "Pilih Akun");

  return (
    <header className="sticky top-0 z-40 w-full border-b border-zinc-800/80 bg-zinc-950/80 backdrop-blur-md">
      <div className="flex h-16 items-center justify-between px-4 md:px-6">
        
        {/* Brand */}
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-br from-indigo-500 via-indigo-600 to-violet-700 text-white font-extrabold shadow-lg shadow-indigo-500/20 text-base">
            18
          </div>
          <div>
            <div className="flex items-center gap-2">
              <span className="font-bold tracking-tight text-zinc-100 text-sm md:text-base">OneEight Hub</span>
              <Badge variant="outline" className="hidden sm:inline-flex text-[10px] px-1.5 py-0 border-zinc-700 text-zinc-400">
                PRO
              </Badge>
            </div>
            <p className="text-[11px] text-zinc-400 font-medium">Command Center Fleet</p>
          </div>
        </div>

        {/* Right Actions */}
        <div className="flex items-center gap-2.5">
          
          {/* Mobile Drawer Trigger */}
          <Sheet open={isOpen} onOpenChange={setIsOpen}>
            <SheetTrigger asChild>
              <Button
                variant="outline"
                size="sm"
                className="md:hidden flex items-center gap-2 h-9 px-3 bg-zinc-900/60 border-zinc-800 text-xs font-semibold"
              >
                <span className="truncate max-w-[130px]">{currentLabel}</span>
                <ChevronDown className="h-3.5 w-3.5 text-zinc-400" />
              </Button>
            </SheetTrigger>

            <SheetContent side="bottom" className="p-4 pt-2">
              <SheetHeader className="mb-3">
                <SheetTitle className="text-sm font-bold flex items-center justify-between">
                  <span>Pilih Akun Roblox</span>
                  <Badge variant="secondary" className="text-[10px]">{bots.size} Terhubung</Badge>
                </SheetTitle>
              </SheetHeader>

              <div className="flex flex-col gap-2">
                <button
                  type="button"
                  onClick={() => { onSelectBot("ALL"); setIsOpen(false); }}
                  className={`flex items-center gap-3 p-3 rounded-xl border text-left transition-all ${
                    selectedBotId === "ALL" 
                      ? "bg-zinc-800/90 border-zinc-700 shadow-sm" 
                      : "bg-zinc-900/40 border-zinc-800/80 hover:bg-zinc-900"
                  }`}
                >
                  <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-zinc-800 border border-zinc-700 text-lg">
                    🌐
                  </div>
                  <div>
                    <div className="font-bold text-xs text-zinc-100">Semua Akun (Global)</div>
                    <div className="text-[11px] text-zinc-400">Kelola Seluruh Armada ({bots.size} Bot)</div>
                  </div>
                </button>

                {Array.from(bots.entries()).map(([id, b]) => {
                  const gameCfg = getGameConfig(b.gameId);
                  const isSelected = selectedBotId === id;
                  const initial = (b.name || "B").substring(0, 2).toUpperCase();

                  return (
                    <button
                      key={id}
                      type="button"
                      onClick={() => { onSelectBot(id); setIsOpen(false); }}
                      className={`flex items-center gap-3 p-3 rounded-xl border text-left transition-all ${
                        isSelected 
                          ? "bg-zinc-800/90 border-zinc-700 shadow-sm" 
                          : "bg-zinc-900/40 border-zinc-800/80 hover:bg-zinc-900"
                      }`}
                    >
                      <Avatar className="h-10 w-10 border-zinc-700">
                        {b.avatarUrl && <AvatarImage src={b.avatarUrl} alt={b.name} />}
                        <AvatarFallback>{b.isKicked ? "🚨" : initial}</AvatarFallback>
                      </Avatar>

                      <div className="flex-1 min-w-0">
                        <div className="flex items-center justify-between">
                          <span className="font-bold text-xs text-zinc-100 truncate">{b.name || "Bot"}</span>
                          <span className="text-[10px]">{gameCfg.icon}</span>
                        </div>
                        <div className="text-[11px] font-mono text-emerald-400 font-semibold">
                          {b.currentCash > 0 ? gameCfg.formatMoney(b.currentCash) : "Memuat..."}
                        </div>
                        <div className="text-[10px] text-zinc-400 truncate">
                          {b.isKicked ? (
                            <span className="text-rose-400 font-semibold">{gameCfg.name} • Terputus</span>
                          ) : b.isFarming ? (
                            <span className="text-emerald-400 font-semibold">{gameCfg.name} • {b.job || gameCfg.defaultJob}</span>
                          ) : (
                            <span>{gameCfg.name} • Standby</span>
                          )}
                        </div>
                      </div>
                    </button>
                  );
                })}
              </div>
            </SheetContent>
          </Sheet>

          {/* WebSocket Status Indicator */}
          <div className="flex items-center gap-2 px-3 py-1.5 rounded-full border border-zinc-800/80 bg-zinc-900/50">
            <span className={`h-2 w-2 rounded-full ${isWsOnline ? 'bg-emerald-500 shadow-[0_0_8px_rgba(16,185,129,0.7)] animate-pulse' : 'bg-rose-500'}`} />
            <span className="text-[11px] font-medium text-zinc-300 hidden sm:inline">{wsStatus}</span>
          </div>

        </div>
      </div>

      {/* Mobile Horizontal Reel (Fast swipe between bots on mobile) */}
      <div className="md:hidden flex items-center gap-2 px-4 py-2 border-t border-zinc-800/60 overflow-x-auto no-scrollbar bg-zinc-950/60">
        <button
          type="button"
          onClick={() => onSelectBot("ALL")}
          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold whitespace-nowrap transition-all ${
            selectedBotId === "ALL"
              ? "bg-zinc-800 text-zinc-100 border border-zinc-700 shadow-sm"
              : "bg-zinc-900/60 text-zinc-400 border border-zinc-800/80 hover:text-zinc-200"
          }`}
        >
          <span>🌐</span>
          <span>Semua Akun</span>
        </button>

        {Array.from(bots.entries()).map(([id, b]) => {
          const isSelected = selectedBotId === id;
          const gameCfg = getGameConfig(b.gameId);
          return (
            <button
              key={id}
              type="button"
              onClick={() => onSelectBot(id)}
              className={`flex items-center gap-1.5 px-2.5 py-1.5 rounded-full text-xs font-semibold whitespace-nowrap transition-all ${
                isSelected
                  ? "bg-zinc-800 text-zinc-100 border border-zinc-700 shadow-sm"
                  : "bg-zinc-900/60 text-zinc-400 border border-zinc-800/80 hover:text-zinc-200"
              }`}
            >
              {b.avatarUrl ? (
                <img src={b.avatarUrl} alt={b.name} className="h-4 w-4 rounded-full object-cover" />
              ) : (
                <span>{b.isKicked ? "🚨" : gameCfg.icon}</span>
              )}
              <span className="truncate max-w-[90px]">{b.name || "Bot"}</span>
            </button>
          );
        })}
      </div>
    </header>
  );
}
