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
  const gameCfg = selectedBot ? getGameConfig(selectedBot.gameId) : null;
  const currentLabel = selectedBotId === "ALL" 
    ? `Semua Akun (${bots.size})` 
    : (selectedBot ? selectedBot.name : "Pilih Akun");

  return (
    <header className="h-16 w-full border-b border-zinc-800/80 bg-zinc-950/80 backdrop-blur-md shrink-0 flex flex-col justify-center">
      <div className="flex items-center justify-between px-4 sm:px-6">
        
        {/* Mobile Brand (hidden on desktop because sidebar has brand) */}
        <div className="flex md:hidden items-center gap-2.5">
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-gradient-to-br from-indigo-500 to-violet-700 text-white font-black text-xs shadow-md">
            18
          </div>
          <span className="font-bold text-sm text-zinc-100">OneEight Hub</span>
        </div>

        {/* Desktop Breadcrumb / View Context */}
        <div className="hidden md:flex items-center gap-3">
          <div className="flex items-center gap-2">
            <span className="text-xs font-semibold text-zinc-400">Dashboard /</span>
            <span className="text-sm font-bold text-zinc-100">
              {selectedBotId === "ALL" ? "Ringkasan Seluruh Akun" : (selectedBot ? selectedBot.name : "Akun")}
            </span>
          </div>
          {selectedBot && gameCfg && (
            <Badge variant="outline" className="text-[11px] gap-1 px-2 py-0.5 border-zinc-700">
              <span>{gameCfg.icon}</span>
              <span>{gameCfg.name}</span>
            </Badge>
          )}
        </div>

        {/* Right Actions */}
        <div className="flex items-center gap-3">
          
          {/* Mobile Account Switcher Trigger */}
          <div className="md:hidden">
            <Button
              variant="outline"
              size="sm"
              onClick={() => setIsOpen(true)}
              className="flex items-center gap-2 h-9 px-3 bg-zinc-900/60 border-zinc-800 text-xs font-semibold"
            >
              <span className="truncate max-w-[130px]">{currentLabel}</span>
              <ChevronDown className="h-3.5 w-3.5 text-zinc-400" />
            </Button>

            <Sheet open={isOpen} onOpenChange={setIsOpen}>
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
                    <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-zinc-800 border border-zinc-700 text-zinc-300"><Users className="h-4 w-4" /></div>
                    <div>
                      <div className="font-bold text-xs text-zinc-100">Semua Akun (Global)</div>
                      <div className="text-[11px] text-zinc-400">Kelola Seluruh Armada ({bots.size} Bot)</div>
                    </div>
                  </button>

                  {Array.from(bots.entries()).map(([id, b]) => {
                    const bGameCfg = getGameConfig(b.gameId);
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
                          <AvatarFallback>{initial}</AvatarFallback>
                        </Avatar>

                        <div className="flex-1 min-w-0">
                          <div className="flex items-center justify-between">
                            <span className="font-bold text-xs text-zinc-100 truncate">{b.name || "Bot"}</span>
                            <span className="text-[10px]">{bGameCfg.icon}</span>
                          </div>
                          <div className="text-[11px] font-mono text-emerald-400 font-semibold">
                            {b.currentCash > 0 ? bGameCfg.formatMoney(b.currentCash) : "Memuat..."}
                          </div>
                          <div className="text-[10px] text-zinc-400 truncate">
                            {b.isKicked ? (
                              <span className="text-rose-400 font-semibold">{bGameCfg.name} • Terputus</span>
                            ) : b.isFarming ? (
                              <span className="text-emerald-400 font-semibold">{bGameCfg.name} • {b.job || bGameCfg.defaultJob}</span>
                            ) : (
                              <span>{bGameCfg.name} • Standby</span>
                            )}
                          </div>
                        </div>
                      </button>
                    );
                  })}
                </div>
              </SheetContent>
            </Sheet>
          </div>

          {/* WebSocket Status Indicator */}
          <div className="flex items-center gap-2 px-3 py-1.5 rounded-full border border-zinc-800/80 bg-zinc-900/60">
            <span className={`h-2 w-2 rounded-full ${isWsOnline ? 'bg-emerald-500 shadow-[0_0_8px_rgba(16,185,129,0.7)] animate-pulse' : 'bg-rose-500'}`} />
            <span className="text-xs font-semibold text-zinc-300">{wsStatus}</span>
          </div>

        </div>
      </div>
    </header>
  );
}
