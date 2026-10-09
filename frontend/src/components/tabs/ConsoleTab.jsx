import * as React from "react";
import { Card, CardHeader, CardTitle, CardContent } from "@/ui/card.jsx";
import { Button } from "@/ui/button.jsx";
import { ScrollArea } from "@/ui/scroll-area.jsx";
import { Terminal, Trash2, RefreshCw } from "lucide-react";

export function ConsoleTab({ bot, logs, onClearLogs, onSendCommand }) {
  const scrollRef = React.useRef(null);

  const filteredLogs = React.useMemo(() => {
    return logs.filter((l) => {
      if (!bot) return true;
      return l.botId === bot.botId || (bot.name && l.source && l.source.toLowerCase() === bot.name.toLowerCase());
    });
  }, [logs, bot]);

  // Auto scroll to bottom
  React.useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [filteredLogs]);

  return (
    <Card className="border-zinc-800 bg-zinc-950/60">
      <CardHeader className="p-4 pb-3 border-b border-zinc-800/80 flex flex-row items-center justify-between">
        <CardTitle className="text-xs md:text-sm font-bold flex items-center gap-2 text-zinc-200">
          <Terminal className="h-4 w-4 text-zinc-400" />
          Konsol Live: {bot?.name || "Akun"}
        </CardTitle>
        <div className="flex items-center gap-2">
          <Button
            variant="outline"
            size="sm"
            className="h-7 text-xs px-2.5 gap-1.5 border-amber-800/60 bg-amber-950/20 text-amber-300 hover:bg-amber-900/40 hover:text-amber-200"
            onClick={() => {
              if (window.confirm(`Lakukan Hot Reload live script untuk akun ${bot?.name || "ini"}?\nClient akan memperbarui script tanpa rejoin server.`)) {
                onSendCommand?.(bot?.botId, "HOT_RELOAD");
              }
            }}
          >
            <RefreshCw className="h-3 w-3" />
            Hot Reload OTA
          </Button>
          <Button
            variant="outline"
            size="sm"
            className="h-7 text-xs px-2.5 gap-1.5 border-zinc-800 text-zinc-400 hover:text-zinc-200"
            onClick={() => onClearLogs(bot?.botId)}
          >
            <Trash2 className="h-3 w-3" />
            Bersihkan
          </Button>
        </div>
      </CardHeader>

      <CardContent className="p-3">
        <div 
          ref={scrollRef}
          className="h-72 overflow-y-auto font-mono text-[11px] leading-relaxed p-2 rounded-lg bg-black/40 border border-zinc-900 space-y-1.5"
        >
          {filteredLogs.length === 0 ? (
            <div className="text-zinc-500 italic py-8 text-center">
              Belum ada log aktivitas untuk akun {bot?.name || "ini"}...
            </div>
          ) : (
            filteredLogs.map((l) => {
              let colorClass = "text-zinc-300";
              if (l.level === "SUCCESS") colorClass = "text-emerald-400 font-medium";
              else if (l.level === "WARN") colorClass = "text-amber-400 font-medium";
              else if (l.level === "ERROR") colorClass = "text-rose-400 font-bold";

              return (
                <div key={l.id} className="flex items-start gap-2 break-all">
                  <span className="text-zinc-500 shrink-0 font-normal">[{l.time}]</span>
                  <span className={colorClass}>
                    <span className="text-zinc-400 font-normal">[{l.source}]</span> {l.msg}
                  </span>
                </div>
              );
            })
          )}
        </div>
      </CardContent>
    </Card>
  );
}
