import * as React from "react";
import { Card, CardHeader, CardTitle, CardContent } from "@/ui/card.jsx";
import { Button } from "@/ui/button.jsx";
import { Badge } from "@/ui/badge.jsx";
import { Globe, ArrowRight } from "lucide-react";

export function CDIDMenuTab({ bot, onSendCommand }) {
  const [fastJoinCode, setFastJoinCode] = React.useState("");

  const handleJoinMap = (mapName) => {
    onSendCommand(bot.botId, "SELECT_MAP", { map: mapName });
  };

  const handleFastJoin = (e) => {
    e.preventDefault();
    if (!fastJoinCode) return;
    onSendCommand(bot.botId, "FAST_JOIN", { code: fastJoinCode });
  };

  return (
    <div className="space-y-4">
      <Card className="border-zinc-800">
        <CardHeader className="p-4 pb-2">
          <CardTitle className="text-sm font-bold flex items-center gap-2">
            <Globe className="h-4 w-4 text-blue-400" />
            Portal Gerbang Server CDID
          </CardTitle>
        </CardHeader>
        <CardContent className="p-4 space-y-4">
          
          {/* Fast Join Form */}
          <form onSubmit={handleFastJoin} className="flex gap-2">
            <input
              type="text"
              value={fastJoinCode}
              onChange={(e) => setFastJoinCode(e.target.value)}
              placeholder="Masukkan Kode Server / JobId..."
              className="flex-1 h-9 px-3 rounded-lg bg-zinc-900 border border-zinc-800 text-xs text-zinc-100 focus:outline-none focus:border-blue-500"
            />
            <Button type="submit" size="sm" className="bg-blue-600 hover:bg-blue-500 font-semibold text-xs">
              Masuk Server
            </Button>
          </form>

          {/* Quick Map Pickers */}
          <div className="space-y-2 pt-2">
            <span className="text-[11px] font-semibold text-zinc-400 uppercase tracking-wider block">Pilih Map Tujuan</span>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
              <Button
                variant="outline"
                className="justify-between h-12 bg-zinc-900/40 border-zinc-800 hover:bg-zinc-800"
                onClick={() => handleJoinMap("Jawa Timur")}
              >
                <div className="text-left">
                  <div className="font-bold text-xs text-emerald-400">Map Jawa Timur (Jatim)</div>
                  <div className="text-[10px] text-zinc-400">Lokasi Job Truk Kargo</div>
                </div>
                <ArrowRight className="h-4 w-4 text-zinc-400" />
              </Button>

              <Button
                variant="outline"
                className="justify-between h-12 bg-zinc-900/40 border-zinc-800 hover:bg-zinc-800"
                onClick={() => handleJoinMap("Jawa Barat")}
              >
                <div className="text-left">
                  <div className="font-bold text-xs text-blue-400">Map Jawa Barat (Jabar)</div>
                  <div className="text-[10px] text-zinc-400">Pedesaan & Kota</div>
                </div>
                <ArrowRight className="h-4 w-4 text-zinc-400" />
              </Button>
            </div>
          </div>

        </CardContent>
      </Card>
    </div>
  );
}
