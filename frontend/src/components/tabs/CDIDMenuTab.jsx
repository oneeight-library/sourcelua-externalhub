import * as React from "react";
import { Card, CardHeader, CardTitle, CardContent } from "@/ui/card.jsx";
import { Button } from "@/ui/button.jsx";
import { Badge } from "@/ui/badge.jsx";
import { MapPin, Key, RefreshCw, ArrowRight } from "lucide-react";

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

  // Semua map CDID disajikan sejajar dan setara (netral tanpa memaksa Jatim)
  const allMaps = [
    { key: "JawaTimur", name: "Jawa Timur", desc: "Pusat Truk Kargo & Depot", icon: "🚚", color: "text-emerald-400", border: "hover:border-emerald-500/50" },
    { key: "Jakarta", name: "Jakarta", desc: "Pusat Kota & Kurir BCA", icon: "🏙️", color: "text-purple-400", border: "hover:border-purple-500/50" },
    { key: "JawaBarat", name: "Jawa Barat", desc: "Tol Cipularang & Bukit", icon: "⛰️", color: "text-blue-400", border: "hover:border-blue-500/50" },
    { key: "Bandung", name: "Bandung", desc: "Kota Kembang & Wisata", icon: "🌸", color: "text-indigo-400", border: "hover:border-indigo-500/50" },
    { key: "JawaTengah", name: "Jawa Tengah", desc: "Semarang & Tol Solo", icon: "🌾", color: "text-amber-400", border: "hover:border-amber-500/50" },
    { key: "Bali", name: "Bali", desc: "Pulau Dewata & Pantai", icon: "🌴", color: "text-teal-400", border: "hover:border-teal-500/50" },
    { key: "Seasonal", name: "Seasonal", desc: "Event Khusus & Spesial", icon: "✨", color: "text-rose-400", border: "hover:border-rose-500/50" },
  ];

  return (
    <div className="space-y-4">
      
      {/* 1. Pengaturan Kode Private Server (Berlaku untuk Map Mana Pun yang Dipilih) */}
      <Card className="border-zinc-800">
        <CardHeader className="p-4 pb-2 border-b border-zinc-800/60">
          <CardTitle className="text-xs font-bold uppercase tracking-wider text-zinc-400 flex items-center gap-2">
            <Key className="h-4 w-4 text-amber-400" />
            Kode Private Server CDID
          </CardTitle>
        </CardHeader>
        <CardContent className="p-4 space-y-3">
          
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 p-3.5 rounded-xl bg-zinc-900/40 border border-zinc-800">
            <div>
              <span className="text-[10px] uppercase font-bold text-zinc-400 block tracking-wider">Kode Aktif Saat Ini</span>
              <div className="mt-1 flex items-center gap-2">
                {hasCode ? (
                  <span className="font-mono text-base font-extrabold text-emerald-400 tracking-wider bg-emerald-950/30 border border-emerald-800/40 px-3 py-1 rounded-md">
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
              Buat Kode Baru (Free)
            </Button>
          </div>

          {/* Form Input Kode Manual */}
          <form onSubmit={handleSetCode} className="flex gap-2">
            <input
              type="text"
              value={manualCode}
              onChange={(e) => setManualCode(e.target.value)}
              placeholder="Atur atau masukkan kode server manual..."
              className="flex-1 h-9 px-3 rounded-lg bg-zinc-900 border border-zinc-800 text-xs text-zinc-100 placeholder:text-zinc-500 focus:outline-none focus:border-zinc-600"
            />
            <Button type="submit" size="sm" variant="secondary" className="font-semibold text-xs h-9 px-4">
              Simpan Kode
            </Button>
          </form>

        </CardContent>
      </Card>

      {/* 2. Pilihan Seluruh Map CDID (Setara, Bersih, Netral) */}
      <Card className="border-zinc-800">
        <CardHeader className="p-4 pb-2 border-b border-zinc-800/60">
          <CardTitle className="text-xs font-bold uppercase tracking-wider text-zinc-400 flex items-center gap-2">
            <MapPin className="h-4 w-4 text-blue-400" />
            Pilih Map Tujuan
          </CardTitle>
        </CardHeader>
        <CardContent className="p-4">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
            {allMaps.map((m) => (
              <div
                key={m.key}
                className={`flex items-center justify-between p-3.5 rounded-xl bg-zinc-900/40 border border-zinc-800 transition-all ${m.border} hover:bg-zinc-900/70`}
              >
                <div className="flex items-center gap-3 min-w-0">
                  <span className="text-2xl shrink-0">{m.icon}</span>
                  <div className="min-w-0">
                    <div className={`font-bold text-xs ${m.color} truncate`}>{m.name}</div>
                    <div className="text-[10px] text-zinc-400 truncate mt-0.5">{m.desc}</div>
                  </div>
                </div>

                <Button
                  variant="outline"
                  size="sm"
                  className="h-8 text-xs font-semibold px-3 shrink-0 ml-2 gap-1.5 hover:bg-zinc-800"
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
