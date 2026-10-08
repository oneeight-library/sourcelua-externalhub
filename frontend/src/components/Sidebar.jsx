import { Users } from "lucide-react";
import * as React from "react";
import { Badge } from "@/ui/badge.jsx";
import { Avatar, AvatarImage, AvatarFallback } from "@/ui/avatar.jsx";
import { getGameConfig } from "@/config/games.js";

export function Sidebar({ bots, selectedBotId, onSelectBot }) {
  return (
    <aside className="hidden md:flex flex-col w-72 shrink-0 border-r border-zinc-800/80 bg-zinc-950 h-full select-none">
      
      {/* Brand Header */}
      <div className="flex items-center gap-3 h-16 px-5 border-b border-zinc-800/80 shrink-0">
        <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-br from-indigo-500 via-indigo-600 to-violet-700 text-white font-black shadow-lg shadow-indigo-500/20 text-base">
          18
        </div>
        <div>
          <div className="flex items-center gap-2">
            <span className="font-extrabold tracking-tight text-zinc-100 text-sm">OneEight Hub</span>
            <Badge variant="outline" className="text-[10px] px-1.5 py-0 border-zinc-700 text-zinc-400 font-semibold">
              PRO
            </Badge>
          </div>
          <p className="text-[11px] text-zinc-400 font-medium">Command Center Fleet</p>
        </div>
      </div>

      {/* Account Section Head */}
      <div className="flex items-center justify-between px-5 pt-4 pb-2 shrink-0">
        <span className="text-[11px] font-bold uppercase tracking-wider text-zinc-400">Daftar Akun Roblox</span>
        <Badge variant="secondary" className="text-[10px] bg-zinc-900 border border-zinc-800 text-zinc-300 font-bold px-2 py-0.5">
          {bots.size} Bot
        </Badge>
      </div>

      {/* Account List Scroll Area */}
      <div className="flex-1 overflow-y-auto px-3 py-2 space-y-1.5">
        
                {/* Global Item */}
        <button
          type="button"
          onClick={() => onSelectBot("ALL")}
          className={`w-full flex items-center gap-3 p-3 rounded-xl border text-left transition-all ${
            selectedBotId === "ALL" 
              ? "bg-zinc-900 border-zinc-700 shadow-sm" 
              : "bg-zinc-950 border-transparent hover:bg-zinc-900/60 hover:border-zinc-800/60"
          }`}
        >
          <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-zinc-900 border border-zinc-800 text-zinc-400"><Users className="h-4 w-4" /></div>
          <div className="min-w-0 flex-1">
            <div className="font-bold text-xs text-zinc-100">Semua Akun (Global)</div>
            <div className="text-[11px] text-zinc-400 truncate">Kelola Seluruh Armada ({bots.size} Bot)</div>
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
              className={`w-full flex items-center gap-3 p-3 rounded-xl border text-left transition-all ${
                isSelected 
                  ? "bg-zinc-900 border-zinc-700 shadow-sm" 
                  : "bg-zinc-950 border-transparent hover:bg-zinc-900/60 hover:border-zinc-800/60"
              }`}
            >
              <div className="relative shrink-0">
                <Avatar className="h-10 w-10 border-zinc-800">
                  {b.avatarUrl && <AvatarImage src={b.avatarUrl} alt={b.name} />}
                  <AvatarFallback>{initial}</AvatarFallback>
                </Avatar>
                <span className={`absolute -bottom-0.5 -right-0.5 h-2.5 w-2.5 rounded-full border-2 border-zinc-950 ${
                  b.isKicked ? "bg-rose-500" : (b.isFarming ? "bg-emerald-500" : "bg-amber-500")
                }`} />
              </div>

              <div className="min-w-0 flex-1">
                <div className="flex items-center justify-between">
                  <span className="font-bold text-xs text-zinc-100 truncate">{b.name || "Bot"}</span>
                  <span className="text-[10px] ml-1">{gameCfg.icon}</span>
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

      {/* Sidebar Footer */}
      <div className="p-4 border-t border-zinc-800/80 shrink-0 bg-zinc-950/80">
        <div className="flex items-center justify-between text-[11px] text-zinc-500">
          <span>OneEight External v2.0</span>
          <span>Cloudflare Edge</span>
        </div>
      </div>
    </aside>
  );
}
