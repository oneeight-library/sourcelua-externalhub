import * as React from "react";
import { Card, CardHeader, CardTitle, CardContent } from "@/ui/card.jsx";
import { Button } from "@/ui/button.jsx";
import { Badge } from "@/ui/badge.jsx";
import {
  Trophy,
  Gift,
  Sparkles,
  CheckCircle2,
  Lock,
  ChevronDown,
  ChevronUp,
  Coins,
  Award,
  Zap,
  Coffee
} from "lucide-react";

export function JobProgressView({ bot, onSendCommand }) {
  const [isExpanded, setIsExpanded] = React.useState(false);
  const [filter, setFilter] = React.useState("all"); // "all", "claimable", "claimed"

  const progress = bot.jobProgress || {
    jobName: "Barista",
    level: 1,
    xp: 0,
    xpInLevel: 0,
    xpNeeded: 150,
    percent: 0,
    claimableCount: 0,
    totalClaimed: 0,
    equippedTitle: "",
    rewards: []
  };

  const handleClaimSingle = (level) => {
    onSendCommand(bot.botId, "CLAIM_JOB_LEVEL", {
      jobName: progress.jobName || "Barista",
      level: level
    });
  };

  const handleClaimAll = () => {
    onSendCommand(bot.botId, "CLAIM_ALL_JOB_LEVELS", {
      jobName: progress.jobName || "Barista"
    });
  };

  const formatRupiah = (val) => {
    const num = Number(val) || 0;
    return "Rp " + num.toLocaleString("id-ID");
  };

  const filteredRewards = (progress.rewards || []).filter((item) => {
    if (filter === "claimable") return item.status === "CAN_CLAIM";
    if (filter === "claimed") return item.status === "CLAIMED";
    return true;
  });

  return (
    <Card className="border-zinc-800 bg-gradient-to-br from-zinc-900/80 via-amber-950/15 to-zinc-950/80 shadow-md">
      <CardHeader className="p-4 pb-3 border-b border-zinc-800/60 flex flex-row items-center justify-between gap-2">
        <div className="flex items-center gap-2.5">
          <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-amber-500/20 text-amber-400">
            <Award className="h-4 w-4" />
          </div>
          <div>
            <CardTitle className="text-xs font-bold uppercase tracking-wider text-amber-300 flex items-center gap-2">
              Klaim Hadiah
            </CardTitle>
          </div>
        </div>

        <div className="flex items-center gap-2">
          {progress.claimableCount > 0 ? (
            <Badge variant="amber" className="bg-amber-500/25 text-amber-300 border-amber-500/40 text-[11px] font-bold animate-pulse flex items-center gap-1">
              <Sparkles className="h-3 w-3" />
              {progress.claimableCount} Siap Klaim
            </Badge>
          ) : (
            <Badge variant="secondary" className="text-[10px] font-semibold">
              Semua Terklaim
            </Badge>
          )}
        </div>
      </CardHeader>

      <CardContent className="p-4 space-y-4">
        {/* Banner Level & XP Progress Bar */}
        <div className="p-4 rounded-xl bg-zinc-900/70 border border-zinc-800/80 space-y-3">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            <div className="flex items-center gap-3">
              <div className="flex flex-col items-center justify-center px-3.5 py-1.5 rounded-lg bg-amber-500/20 border border-amber-500/30 text-amber-300">
                <span className="text-[10px] font-bold uppercase tracking-wider text-amber-400/80">Tingkat</span>
                <span className="text-lg font-black tracking-tight leading-none mt-0.5">Lv {progress.level || 1}</span>
              </div>

              <div>
                <div className="text-sm font-bold text-zinc-100 flex items-center gap-1.5">
                  <span>Level {progress.level || 1}</span>
                  {progress.level >= 50 && (
                    <Badge variant="emerald" className="text-[10px] py-0 px-1.5">MAX</Badge>
                  )}
                  {progress.equippedTitle && (
                    <Badge variant="outline" className="text-[10px] py-0 border-amber-700/60 text-amber-300 bg-amber-950/40">
                      Gelar: {progress.equippedTitle}
                    </Badge>
                  )}
                </div>
                <div className="text-xs text-zinc-400 mt-0.5">
                  Total Akumulasi: <strong className="text-zinc-200">{(progress.xp || 0).toLocaleString()} XP</strong>
                </div>
              </div>
            </div>

            {/* Quick Stats & Claim All Button */}
            <div className="flex items-center gap-2 self-start sm:self-center">
              <Button
                size="sm"
                variant={progress.claimableCount > 0 ? "amber" : "outline"}
                disabled={progress.claimableCount === 0}
                className={`h-9 text-xs font-bold gap-1.5 shadow-md ${
                  progress.claimableCount > 0
                    ? "bg-amber-600 hover:bg-amber-500 text-white animate-pulse"
                    : "border-zinc-800 text-zinc-500"
                }`}
                onClick={handleClaimAll}
              >
                <Gift className="h-3.5 w-3.5" />
                <span>Klaim Semua Hadiah ({progress.claimableCount || 0})</span>
              </Button>
            </div>
          </div>

          {/* Progress Bar Track */}
          <div className="space-y-1.5">
            <div className="flex items-center justify-between text-[11px] font-semibold">
              <span className="text-zinc-400">
                Progres XP: <strong className="text-amber-300">{progress.xpInLevel || 0}</strong> / {progress.xpNeeded || 0} XP
              </span>
              <span className="text-amber-400 font-mono">
                {progress.level >= 50 ? "LEVEL MAKSIMUM (100%)" : `${progress.percent || 0}%`}
              </span>
            </div>

            <div className="h-3 w-full bg-zinc-950 rounded-full border border-zinc-800/90 overflow-hidden p-0.5 shadow-inner">
              <div 
                className="h-full bg-gradient-to-r from-amber-500 via-amber-400 to-yellow-300 rounded-full transition-all duration-500 shadow-sm"
                style={{ width: `${Math.max(progress.percent || 0, progress.level >= 50 ? 100 : 3)}%` }}
              />
            </div>
          </div>
        </div>

        {/* Expandable Level Reward Matrix Tiers */}
        <div className="space-y-3">
          <div className="flex items-center justify-between flex-wrap gap-2">
            <div className="flex items-center gap-2">
              <Button
                variant="ghost"
                size="sm"
                className="text-xs font-bold text-amber-300 hover:text-amber-200 hover:bg-zinc-850 p-1.5 h-7 gap-1"
                onClick={() => setIsExpanded(!isExpanded)}
              >
                {isExpanded ? <ChevronUp className="h-4 w-4" /> : <ChevronDown className="h-4 w-4" />}
                <span>{isExpanded ? "Sembunyikan Daftar Tingkatan Hadiah" : "Lihat Semua Tingkat Hadiah (Lv 2 - 50)"}</span>
              </Button>
            </div>

            {isExpanded && (
              <div className="flex items-center gap-1 p-0.5 rounded-lg bg-zinc-950 border border-zinc-800 text-[11px]">
                <button
                  onClick={() => setFilter("all")}
                  className={`px-2.5 py-1 rounded font-semibold transition-all ${
                    filter === "all" ? "bg-zinc-800 text-zinc-100" : "text-zinc-400 hover:text-zinc-200"
                  }`}
                >
                  Semua ({progress.rewards?.length || 0})
                </button>
                <button
                  onClick={() => setFilter("claimable")}
                  className={`px-2.5 py-1 rounded font-semibold transition-all ${
                    filter === "claimable" ? "bg-amber-600/30 text-amber-300 border border-amber-500/40" : "text-zinc-400 hover:text-zinc-200"
                  }`}
                >
                  Bisa Klaim ({progress.claimableCount || 0})
                </button>
                <button
                  onClick={() => setFilter("claimed")}
                  className={`px-2.5 py-1 rounded font-semibold transition-all ${
                    filter === "claimed" ? "bg-emerald-600/30 text-emerald-300 border border-emerald-500/40" : "text-zinc-400 hover:text-zinc-200"
                  }`}
                >
                  Terklaim ({progress.totalClaimed || 0})
                </button>
              </div>
            )}
          </div>

          {/* List of Tiers */}
          {isExpanded && (
            <div className="max-h-80 overflow-y-auto space-y-2 pr-1 scrollbar-thin scrollbar-thumb-zinc-700">
              {filteredRewards.length === 0 ? (
                <div className="p-6 text-center text-xs text-zinc-500 bg-zinc-900/40 rounded-xl border border-zinc-800">
                  Tidak ada tingkatan reward yang sesuai filter ini.
                </div>
              ) : (
                filteredRewards.map((item) => {
                  const isClaimable = item.status === "CAN_CLAIM";
                  const isClaimed = item.status === "CLAIMED";
                  const isLocked = item.status === "LOCKED";

                  return (
                    <div
                      key={item.level}
                      className={`flex items-center justify-between p-2.5 rounded-xl border text-xs transition-all ${
                        isClaimable
                          ? "bg-amber-950/30 border-amber-600/50 shadow-sm"
                          : item.isMilestone
                          ? "bg-blue-950/20 border-blue-800/40"
                          : "bg-zinc-900/40 border-zinc-800/70"
                      }`}
                    >
                      <div className="flex items-center gap-3">
                        <div
                          className={`flex items-center justify-center h-8 w-11 rounded-lg font-black text-xs shrink-0 ${
                            isClaimable
                              ? "bg-amber-500/20 text-amber-300 border border-amber-500/40"
                              : item.isMilestone
                              ? "bg-blue-500/20 text-blue-300 border border-blue-500/40"
                              : "bg-zinc-800/80 text-zinc-300"
                          }`}
                        >
                          Lv {item.level}
                        </div>

                        <div>
                          <div className="font-bold flex items-center gap-1.5">
                            <span className={item.isMilestone ? "text-blue-300 font-extrabold" : "text-zinc-200"}>
                              {item.rewardText}
                            </span>
                            {item.isMilestone && (
                              <Badge variant="outline" className="text-[9px] py-0 px-1 border-blue-600/50 text-blue-400 bg-blue-950/50">
                                MILESTONE
                              </Badge>
                            )}
                          </div>
                          <span className="text-[10px] text-zinc-500 block">
                            {item.isMilestone ? "Bonus Multiplier Gaji Permanen" : "Hadiah Langsung Tunai"}
                          </span>
                        </div>
                      </div>

                      <div>
                        {isClaimable ? (
                          <Button
                            size="sm"
                            className="h-7 text-xs font-bold bg-amber-600 hover:bg-amber-500 text-white shadow-md gap-1 px-3"
                            onClick={() => handleClaimSingle(item.level)}
                          >
                            <Gift className="h-3 w-3" />
                            <span>Klaim</span>
                          </Button>
                        ) : isClaimed ? (
                          <div className="flex items-center gap-1 text-[11px] font-semibold text-emerald-400 bg-emerald-950/40 px-2 py-1 rounded-md border border-emerald-800/40">
                            <CheckCircle2 className="h-3 w-3" />
                            <span>Sudah Diambil</span>
                          </div>
                        ) : (
                          <div className="flex items-center gap-1 text-[11px] font-medium text-zinc-500 bg-zinc-900/80 px-2 py-1 rounded-md border border-zinc-800">
                            <Lock className="h-3 w-3" />
                            <span>Terkunci</span>
                          </div>
                        )}
                      </div>
                    </div>
                  );
                })
              )}
            </div>
          )}
        </div>
      </CardContent>
    </Card>
  );
}
