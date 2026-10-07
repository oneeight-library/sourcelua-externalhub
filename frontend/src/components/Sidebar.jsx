import * as React from "react";
import { Badge } from "@/ui/badge.jsx";
import { Avatar, AvatarImage, AvatarFallback } from "@/ui/avatar.jsx";
import { getGameConfig } from "@/config/games.js";

export function Sidebar({ bots, selectedBotId, onSelectBot }) {
  return (
    <aside className="hidden md:flex flex-col w-72 shrink-0 border-r border-zinc-800/80 bg-zinc-950/40 p-4 min-h-[calc(100vh-4rem)]">
      
      {/* Head */}
      <div className="flex items-center justify-between pb-3 mb-2 border-b border-zinc-800/60">
        <span className="text-xs font-bold uppercase tracking-wider text-zinc-400">Daftar Akun Roblox</span>
        <Badge variant="secondary" className="text-[10px] bg-zinc-800 text-zinc-300 font-semibold">
          {bots.size} Bot
        </Badge>
      </div>

      <div className="flex flex-col gap-2 overflow-y-auto pr-1">
        
        {/* Global Item */}
        <button
          type="button"
          onClick={() => onSelectBot("ALL")}
          className={`flex items-center gap-3 p-3 rounded-xl border text-left transition-all select-none ${
            selectedBotId === "ALL" 
              ? "bg-zinc-800/90 border-zinc-700 shadow-sm" 
              : "bg-zinc-900/30 border-zinc-800/60 hover:bg-zinc-900/60"
          }`}
        >
          <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-zinc-800/80 border border-zinc-700/80 text-lg">
            🌐
          </div>
          <div>
            <div className="font-bold text-xs text-zinc-100">Semua Akun (Global)</div>
            <div className="text-[11px] text-zinc-400">Kelola {bots.size} Akun Terhubung</div>
          </div>
        </button>

        {/* Bot Items */}
        {Array.from(bots.entries()).map(([id, b]) => {
          const gameCfg = getGameConfig(b.gameId);
          const isSelected = selectedBotId === id;
          const initial = (b.name || "B").substring(0, 2).toUpperCase();

          return (
            <button
              key={id}
              type="button"
              onClick={() => onSelectBot(id)}
              className={`flex items-center gap-3 p-3 rounded-xl border text-left transition-all select-none ${
                isSelected 
                  ? "bg-zinc-800/90 border-zinc-700 shadow-sm" 
                  : "bg-zinc-900/30 border-zinc-800/60 hover:bg-zinc-900/60"
              }`}
            >
              <div className="relative">
                <Avatar className="h-10 w-10 border-zinc-700">
                  {b.avatarUrl && <AvatarImage src={b.avatarUrl} alt={b.name} />}
                  <AvatarFallback>{b.isKicked ? "🚨" : initial}</AvatarFallback>
                </Avatar>
                <span className={`absolute -bottom-0.5 -right-0.5 h-2.5 w-2.5 rounded-full border-2 border-zinc-950 ${
                  b.isKicked ? "bg-rose-500" : (b.isFarming ? "bg-emerald-500" : "bg-amber-500")
                }`} />
              </div>

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
    </aside>
  );
}
