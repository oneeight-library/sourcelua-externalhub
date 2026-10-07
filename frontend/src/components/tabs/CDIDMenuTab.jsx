import * as React from "react";
import { Card, CardHeader, CardTitle, CardContent } from "@/ui/card.jsx";
import { Button } from "@/ui/button.jsx";
import { Badge } from "@/ui/badge.jsx";
import { Globe, ArrowRight, Key, Sparkles, RefreshCw } from "lucide-react";

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

  const mapsList = [
    { key: "JawaBarat", name: "Jawa Barat", desc: "Tol & Pegunungan", color: "text-blue-400" },
    { key: "Bandung", name: "Bandung", desc: "Kota Kembang", color: "text-indigo-400" },
    { key: "Jakarta", name: "Jakarta", desc: "Pusat Kota & Kurir BCA", color: "text-purple-400" },
    { key: "JawaTengah", name: "Jawa Tengah", desc: "Semarang & Solo", color: "text-amber-400" },
    { key: "Bali", name: "Bali", desc: "Pulau Dewata", color: "text-emerald-400" },
    { key: "Seasonal", name: "Seasonal", desc: "Map Event Khusus", color: "text-rose-400" },
  ];

  return (
    <div className="space-y-4">
      
      {/* Featured Primary Action: Masuk Jawa Timur */}
      <div className="p-4 md:p-5 rounded-xl border border-emerald-500/30 bg-gradient-to-br from-emerald-950/20 via-zinc-900/60 to-zinc-950/80 flex flex-col sm:flex-row sm:items-center justify-between gap-4 shadow-lg">
        <div className="flex items-center gap-3.5">
          <div className="text-3xl">🚚</div>
          <div>
            <h4 className="font-extrabold text-sm md:text-base text-emerald-400">Jawa Timur (Pusat Truk Kargo)</h4>
            <p className="text-xs text-emerald-300/80 mt-0.5">Map utama tempat pekerjaan Supir Truk Kargo berada.</p>
          </div>
        </div>

        <Button
          variant="emerald"
          className="font-bold text-xs h-10 px-5 gap-2 shadow-md shadow-emerald-950/50"
          onClick={() => handleJoinMap("JawaTimur")}
        >
          <Sparkles className="h-4 w-4" />
          Masuk Jawa Timur
        </Button>
      </div>

      {/* Private Server Code Management Card */}
      <Card className="border-zinc-800">
        <CardHeader className="p-4 pb-3">
          <CardTitle className="text-sm font-bold flex items-center gap-2">
            <Key className="h-4 w-4 text-amber-400" />
            Kode Private Server CDID
          </CardTitle>
        </CardHeader>
        <CardContent className="p-4 pt-1 space-y-4">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 p-3.5 rounded-xl bg-zinc-900/40 border border-zinc-800">
            <div>
              <span className="text-[10px] uppercase font-bold text-zinc-400 block tracking-wider">Status Kode Server</span>
              <div className="mt-1 flex items-center gap-2">
                {hasCode ? (
                  <span className="font-mono text-base font-extrabold text-emerald-400 tracking-wider bg-emerald-950/30 border border-emerald-800/40 px-2.5 py-1 rounded-md">
                    🔑 {activeCode}
                  </span>
                ) : (
                  <span className="text-xs font-semibold text-amber-400 bg-amber-950/20 border border-amber-900/30 px-2.5 py-1 rounded-md">
                    ⚠️ Belum Ada Kode Terdeteksi
                  </span>
                )}
              </div>
            </div>

            <Button
              variant="outline"
              size="sm"
              className="gap-1.5 h-9 text-xs font-semibold border-zinc-700 hover:bg-zinc-800"
              onClick={handleGenerateCode}
            >
              <RefreshCw className="h-3.5 w-3.5 text-zinc-400" />
              Buat Kode Server Baru
            </Button>
          </div>

          {/* Form Manual Code */}
          <form onSubmit={handleSetCode} className="flex gap-2">
            <input
              type="text"
              value={manualCode}
              onChange={(e) => setManualCode(e.target.value)}
              placeholder="Atur atau masukkan kode server manual..."
              className="flex-1 h-9 px-3 rounded-lg bg-zinc-900 border border-zinc-800 text-xs text-zinc-100 placeholder:text-zinc-500 focus:outline-none focus:border-emerald-500"
            />
            <Button type="submit" size="sm" variant="secondary" className="font-semibold text-xs h-9 px-4">
              Simpan Kode
            </Button>
          </form>
        </CardContent>
      </Card>

      {/* Other CDID Maps */}
      <Card className="border-zinc-800">
        <CardHeader className="p-4 pb-2">
          <CardTitle className="text-sm font-bold flex items-center gap-2">
            <Globe className="h-4 w-4 text-blue-400" />
            Pilihan Map Lainnya
          </CardTitle>
        </CardHeader>
        <CardContent className="p-4 grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-2.5">
          {mapsList.map((m) => (
            <Button
              key={m.key}
              variant="outline"
              className="justify-between h-14 p-3 bg-zinc-900/30 border-zinc-800/80 hover:bg-zinc-800/60 hover:border-zinc-700 text-left"
              onClick={() => handleJoinMap(m.key)}
            >
              <div>
                <div className={`font-bold text-xs ${m.color}`}>{m.name}</div>
                <div className="text-[10px] text-zinc-400 mt-0.5">{m.desc}</div>
              </div>
              <ArrowRight className="h-3.5 w-3.5 text-zinc-500" />
            </Button>
          ))}
        </CardContent>
      </Card>

    </div>
  );
}
