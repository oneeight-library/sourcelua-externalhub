import * as React from "react";
import { Card, CardHeader, CardTitle, CardContent } from "@/ui/card.jsx";
import { Button } from "@/ui/button.jsx";
import { ArrowRight, Key, MapPin, RefreshCw } from "lucide-react";

export function CDIDMenuTab({ bot, onSendCommand }) {
  const [manualCode, setManualCode] = React.useState("");
  const activeCode = bot.serverCode || "";
  const hasCode = activeCode.length > 0;

  const handleJoinMap = (mapKey) => {
    onSendCommand(bot.botId, "JOIN_MAP", { mapKey, code: activeCode });
  };

  const handleSetCode = (e) => {
    e.preventDefault();
    if (!manualCode.trim()) return;
    onSendCommand(bot.botId, "SET_SERVER_CODE", { code: manualCode.trim() });
    setManualCode("");
  };

  const handleGenerateCode = () => {
    onSendCommand(bot.botId, "GENERATE_SERVER_CODE");
  };

  const allMaps = [
    { key: "JawaTimur", name: "Jawa Timur" },
    { key: "Jakarta", name: "Jakarta" },
    { key: "JawaBarat", name: "Jawa Barat" },
    { key: "Bandung", name: "Bandung" },
    { key: "JawaTengah", name: "Jawa Tengah" },
    { key: "Bali", name: "Bali" },
    { key: "Seasonal", name: "Seasonal" },
  ];

  return (
    <div className="space-y-4">
      
      {/* 1. Pengaturan Kode Private Server */}
      <Card className="border-zinc-800">
        <CardHeader className="p-4 pb-2 border-b border-zinc-800/60">
          <CardTitle className="text-xs font-semibold uppercase tracking-wider text-zinc-400 flex items-center gap-2">
            <Key className="h-4 w-4 text-zinc-400" />
            Kode Private Server
          </CardTitle>
        </CardHeader>
        <CardContent className="p-4 space-y-3">
          
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 p-3.5 rounded-xl bg-zinc-900/40 border border-zinc-800">
            <div>
              <span className="text-[10px] uppercase font-bold text-zinc-500 block tracking-wider">Kode Aktif</span>
              <div className="mt-1 flex items-center gap-2">
                {hasCode ? (
                  <span className="font-mono text-sm font-semibold text-emerald-400 bg-emerald-950/30 border border-emerald-800/40 px-2.5 py-1 rounded-md">
                    {activeCode}
                  </span>
                ) : (
                  <span className="text-xs text-zinc-400 bg-zinc-900 border border-zinc-800 px-2.5 py-1 rounded-md">
                    Tidak ada kode aktif
                  </span>
                )}
              </div>
            </div>

            <Button
              variant="outline"
              size="sm"
              className="gap-1.5 h-9 text-xs font-medium border-zinc-700 hover:bg-zinc-800"
              onClick={handleGenerateCode}
            >
              <RefreshCw className="h-3.5 w-3.5 text-zinc-400" />
              Buat Kode Baru
            </Button>
          </div>

          {/* Form Input Kode Manual */}
          <form onSubmit={handleSetCode} className="flex gap-2">
            <input
              type="text"
              value={manualCode}
              onChange={(e) => setManualCode(e.target.value)}
              placeholder="Masukkan kode server manual..."
              className="flex-1 h-9 px-3 rounded-lg bg-zinc-900 border border-zinc-800 text-xs text-zinc-100 placeholder:text-zinc-500 focus:outline-none focus:border-zinc-700"
            />
            <Button type="submit" size="sm" variant="secondary" className="font-medium text-xs h-9 px-4">
              Simpan
            </Button>
          </form>

        </CardContent>
      </Card>

      {/* 2. Pilihan Map CDID (Netral, Tanpa Emoji & Tanpa Deskripsi Lebay) */}
      <Card className="border-zinc-800">
        <CardHeader className="p-4 pb-2 border-b border-zinc-800/60">
          <CardTitle className="text-xs font-semibold uppercase tracking-wider text-zinc-400 flex items-center gap-2">
            <MapPin className="h-4 w-4 text-zinc-400" />
            Pilih Map Tujuan
          </CardTitle>
        </CardHeader>
        <CardContent className="p-4">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
            {allMaps.map((m) => (
              <div
                key={m.key}
                className="flex items-center justify-between p-3 px-4 rounded-xl bg-zinc-900/40 border border-zinc-800/80 hover:border-zinc-700 hover:bg-zinc-850/50 transition-colors"
              >
                <div className="flex items-center gap-2.5 min-w-0">
                  <MapPin className="h-4 w-4 text-zinc-400 shrink-0" />
                  <span className="font-semibold text-xs sm:text-sm text-zinc-200 truncate">{m.name}</span>
                </div>

                <Button
                  variant="outline"
                  size="sm"
                  className="h-8 text-xs font-medium px-3 shrink-0 ml-2 gap-1.5 border-zinc-700/80 hover:bg-zinc-800 text-zinc-200"
                  onClick={() => handleJoinMap(m.key)}
                >
                  <span>Masuk</span>
                  <ArrowRight className="h-3 w-3 text-zinc-400" />
                </Button>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>

    </div>
  );
}
