import * as React from "react";
import { Card, CardHeader, CardTitle, CardContent } from "@/ui/card.jsx";
import { Switch } from "@/ui/switch.jsx";
import { Zap } from "lucide-react";

export function PerfTab({ bot, onSendCommand }) {
  const [lowRender, setLowRender] = React.useState(!!bot.lowRender);

  const handleToggle = (checked) => {
    setLowRender(checked);
    onSendCommand(bot.botId, "TOGGLE_LOW_RENDER", { enabled: checked });
  };

  return (
    <Card className="border-zinc-800">
      <CardHeader className="p-4 pb-2">
        <CardTitle className="text-sm font-bold flex items-center gap-2">
          <Zap className="h-4 w-4 text-amber-400" />
          Optimasi Performa & Hemat GPU
        </CardTitle>
      </CardHeader>
      <CardContent className="p-4">
        <div className="flex items-center justify-between p-3 rounded-xl bg-zinc-900/40 border border-zinc-800">
          <div>
            <div className="font-semibold text-xs text-zinc-200">Mode Layar Hitam (Black Screen)</div>
            <div className="text-[11px] text-zinc-400">Menonaktifkan 3D rendering untuk menghemat konsumsi GPU hingga 85%</div>
          </div>
          <Switch checked={lowRender} onCheckedChange={handleToggle} />
        </div>
      </CardContent>
    </Card>
  );
}
