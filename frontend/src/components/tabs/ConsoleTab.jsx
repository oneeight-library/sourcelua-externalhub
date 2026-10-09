import * as React from "react";
import { Card, CardHeader, CardTitle, CardContent } from "@/ui/card.jsx";
import { Button } from "@/ui/button.jsx";
import { Terminal, Trash2, RefreshCw, ArrowDown } from "lucide-react";

export function ConsoleTab({ bot, logs, onClearLogs, onSendCommand }) {
  const scrollRef = React.useRef(null);
  const [autoScroll, setAutoScroll] = React.useState(true);
  const [unreadCount, setUnreadCount] = React.useState(0);

  const filteredLogs = React.useMemo(() => {
    return logs.filter((l) => {
      if (!bot) return true;
      return l.botId === bot.botId || (bot.name && l.source && l.source.toLowerCase() === bot.name.toLowerCase());
    });
  }, [logs, bot]);

  // Handle user scroll detection
  const handleScroll = (e) => {
    const target = e.currentTarget;
    const distanceToBottom = target.scrollHeight - target.scrollTop - target.clientHeight;
    // Toleransi 40px dari dasar
    const isAtBottom = distanceToBottom <= 40;
    if (isAtBottom) {
      if (!autoScroll) {
        setAutoScroll(true);
        setUnreadCount(0);
      }
    } else {
      if (autoScroll) {
        setAutoScroll(false);
      }
    }
  };

  // Auto scroll to bottom only when user is at the bottom
  React.useEffect(() => {
    if (autoScroll && scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    } else if (!autoScroll) {
      setUnreadCount((prev) => prev + 1);
    }
  }, [filteredLogs, autoScroll]);

  const scrollToBottom = () => {
    if (scrollRef.current) {
      scrollRef.current.scrollTo({
        top: scrollRef.current.scrollHeight,
        behavior: "smooth",
      });
      setAutoScroll(true);
      setUnreadCount(0);
    }
  };

  return (
    <Card className="border-zinc-800 bg-zinc-950/60">
      <CardHeader className="p-4 pb-3 border-b border-zinc-800/80 flex flex-row items-center justify-between">
        <CardTitle className="text-xs md:text-sm font-bold flex items-center gap-2 text-zinc-200">
          <Terminal className="h-4 w-4 text-purple-400" />
          Live Konsol: {bot?.name || "Akun"}
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
            className="h-7 text-xs px-2.5 gap-1.5 border-zinc-800 text-zinc-400 hover:text-rose-400 hover:border-rose-900/50"
            onClick={() => {
              onClearLogs?.(bot?.botId, bot?.name);
            }}
          >
            <Trash2 className="h-3 w-3" />
            Bersihkan
          </Button>
        </div>
      </CardHeader>

      <CardContent className="p-3 relative">
        <div 
          ref={scrollRef}
          onScroll={handleScroll}
          className="h-80 overflow-y-auto font-mono text-[11px] leading-relaxed p-2.5 rounded-lg bg-black/40 border border-zinc-900 space-y-1.5"
        >
          {filteredLogs.length === 0 ? (
            <div className="text-zinc-500 italic py-12 text-center">
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

        {/* Floating Scroll to Bottom Indicator if user scrolled up */}
        {!autoScroll && filteredLogs.length > 0 && (
          <div className="absolute bottom-5 right-5 z-10">
            <Button
              size="sm"
              onClick={scrollToBottom}
              className="h-7 px-2.5 text-xs font-semibold gap-1.5 bg-purple-600 hover:bg-purple-500 text-white shadow-lg shadow-purple-900/40 border border-purple-400/30"
            >
              <ArrowDown className="h-3.5 w-3.5" />
              <span>Scroll ke Bawah</span>
              {unreadCount > 0 && (
                <span className="ml-0.5 px-1.5 py-0.2 bg-purple-900 rounded-full text-[10px] font-bold">
                  +{unreadCount}
                </span>
              )}
            </Button>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
