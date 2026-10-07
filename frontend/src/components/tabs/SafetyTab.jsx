import * as React from "react";
import { Card, CardHeader, CardTitle, CardContent } from "@/ui/card.jsx";
import { Button } from "@/ui/button.jsx";
import { Switch } from "@/ui/switch.jsx";
import { ShieldCheck, RotateCcw } from "lucide-react";

export function SafetyTab({ bot, onSendCommand, onRejoinBot }) {
  const [autoRejoin, setAutoRejoin] = React.useState(bot.autoRejoin !== false);

  const handleToggleAutoRejoin = (checked) => {
    setAutoRejoin(checked);
    onSendCommand(bot.botId, "TOGGLE_AUTO_REJOIN", { enabled: checked });
  };

  return (
    <div className="space-y-4">
      <Card className="border-zinc-800">
        <CardHeader className="p-4 pb-2">
          <CardTitle className="text-sm font-bold flex items-center gap-2">
            <ShieldCheck className="h-4 w-4 text-emerald-400" />
            Proteksi Koneksi & Anti-AFK
          </CardTitle>
        </CardHeader>
        <CardContent className="p-4 space-y-4">
          <div className="flex items-center justify-between p-3 rounded-xl bg-zinc-900/40 border border-zinc-800">
            <div>
              <div className="font-semibold text-xs text-zinc-200">Auto Rejoin Saat Kick</div>
              <div className="text-[11px] text-zinc-400">Otomatis menghubungkan kembali karakter jika terkena disconnect</div>
            </div>
            <Switch checked={autoRejoin} onCheckedChange={handleToggleAutoRejoin} />
          </div>

          <div className="flex items-center justify-between p-3 rounded-xl bg-zinc-900/40 border border-zinc-800">
            <div>
              <div className="font-semibold text-xs text-zinc-200">Paksa Rejoin Server Sekarang</div>
              <div className="text-[11px] text-zinc-400">Pindahkan karakter ke server baru secara manual</div>
            </div>
            <Button
              variant="destructive"
              size="sm"
              className="gap-1.5 h-8 text-xs font-semibold"
              onClick={() => onRejoinBot(bot.botId)}
            >
              <RotateCcw className="h-3.5 w-3.5" />
              Rejoin
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
