import * as React from "react";
import { Badge } from "@/ui/badge.jsx";
import { Button } from "@/ui/button.jsx";
import { Sheet, SheetTrigger, SheetContent, SheetHeader, SheetTitle } from "@/ui/sheet.jsx";
import { Avatar, AvatarImage, AvatarFallback } from "@/ui/avatar.jsx";
import { ChevronDown, Users, Code2, Check } from "lucide-react";
import { getGameConfig } from "@/config/games.js";

export function Navbar({ bots, selectedBotId, onSelectBot }) {
  const [isOpen, setIsOpen] = React.useState(false);
  const [copiedLoader, setCopiedLoader] = React.useState(false);

  const handleCopyLoader = () => {
    const origin = typeof window !== "undefined" && window.location.origin 
      ? window.location.origin 
      : "https://externalhub.oneeight-project18.workers.dev";
    const loaderCode = `loadstring(game:HttpGet("${origin}/loader"))()`;

    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(loaderCode).then(() => {
        setCopiedLoader(true);
        setTimeout(() => setCopiedLoader(false), 2000);
      }).catch(() => fallbackCopy(loaderCode));
    } else {
      fallbackCopy(loaderCode);
    }
  };

  const fallbackCopy = (text) => {
    try {
      const ta = document.createElement("textarea");
      ta.value = text;
      ta.style.position = "fixed";
      ta.style.opacity = "0";
      document.body.appendChild(ta);
      ta.select();
      document.execCommand("copy");
      document.body.removeChild(ta);
      setCopiedLoader(true);
      setTimeout(() => setCopiedLoader(false), 2000);
    } catch (e) {
      console.error("Gagal menyalin loader:", e);
    }
  };

  const selectedBot = bots.get(selectedBotId);
  const gameCfg = selectedBot ? getGameConfig(selectedBot.gameId) : null;
  const botKeys = Array.from(bots.keys());
  const currentIndex = selectedBotId === "ALL" ? -1 : botKeys.indexOf(selectedBotId);
  const currentLabel = selectedBotId === "ALL"
    ? `Semua (${bots.size})`
    : (currentIndex !== -1 ? `Akun ${currentIndex + 1}/${bots.size}` : "Pilih Akun");

  return (
    <header className="h-14 sm:h-16 w-full border-b border-zinc-800/80 bg-zinc-950/80 backdrop-blur-md shrink-0 flex flex-col justify-center">
      <div className="flex items-center justify-between px-3 sm:px-6">
        
        {/* Mobile Brand (kompak dan proporsional untuk HP) */}
        <div className="flex md:hidden items-center gap-2 shrink-0">
          <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-gradient-to-br from-indigo-500 to-violet-700 text-white font-black text-xs shadow-md">
            18
          </div>
          <span className="font-extrabold text-xs sm:text-sm text-zinc-100 tracking-tight">OneEight</span>
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
              <span>{selectedBot.placeName || selectedBot.gameName || gameCfg.name}</span>
            </Badge>
          )}
        </div>

        {/* Right Actions (Loader + Switcher Akun, Bersih tanpa Badge Online) */}
        <div className="flex items-center gap-2">
          
          {/* Tombol Loader (Icon Code2 & Teks 'Loader') */}
          <Button
            variant="outline"
            size="sm"
            onClick={handleCopyLoader}
            className={`flex items-center gap-1.5 h-8 sm:h-9 px-2.5 sm:px-3 text-xs font-bold transition-all border-zinc-800 rounded-xl shadow-sm ${
              copiedLoader
                ? "bg-emerald-950/50 border-emerald-500/50 text-emerald-300"
                : "bg-zinc-900/70 hover:bg-zinc-800/90 text-zinc-200 hover:text-white"
            }`}
            title="Klik untuk salin script loader ke executor Roblox"
          >
            {copiedLoader ? (
              <>
                <Check className="h-3.5 w-3.5 text-emerald-400" />
                <span className="text-[11px] sm:text-xs">Tersalin!</span>
              </>
            ) : (
              <>
                <Code2 className="h-3.5 w-3.5 text-indigo-400" />
                <span className="text-[11px] sm:text-xs font-bold">Loader</span>
              </>
            )}
          </Button>
          
          {/* Mobile Account Switcher Trigger */}
          <div className="md:hidden">
            <Button
              variant="outline"
              size="sm"
              onClick={() => setIsOpen(true)}
              className="flex items-center gap-1.5 h-8 px-2.5 bg-zinc-900/70 border-zinc-800 text-xs font-bold rounded-xl"
            >
              <Users className="h-3 w-3 text-zinc-400 shrink-0" />
              <span>{currentLabel}</span>
              <ChevronDown className="h-3 w-3 text-zinc-400 shrink-0" />
            </Button>

            <Sheet open={isOpen} onOpenChange={setIsOpen}>
              <SheetContent side="bottom" className="p-4 pt-2">
                <SheetHeader className="mb-3">
                  <SheetTitle className="text-sm font-bold text-zinc-100">
                    Pilih Akun Roblox
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
                          <div className="text-[11px] text-emerald-400 font-bold tabular-nums">
                            {b.currentCash > 0 ? bGameCfg.formatMoney(b.currentCash) : "Memuat..."}
                          </div>
                          <div className="text-[10px] text-zinc-400 truncate">
                            {b.isKicked ? (
                              <span className="text-rose-400 font-semibold">{b.placeName || b.gameName || bGameCfg.name} • Terputus</span>
                            ) : b.isFarming ? (
                              <span className="text-emerald-400 font-semibold">{b.placeName || b.gameName || bGameCfg.name} • {b.job || bGameCfg.defaultJob}</span>
                            ) : (
                              <span>{b.placeName || b.gameName || bGameCfg.name} • {b.job || "Unemployed"}</span>
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

        </div>
      </div>
    </header>
  );
}
