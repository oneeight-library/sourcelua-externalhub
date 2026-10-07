import * as React from "react";
import { Navbar } from "@/components/Navbar.jsx";
import { Sidebar } from "@/components/Sidebar.jsx";
import { FleetOverview } from "@/components/FleetOverview.jsx";
import { BotDetailView } from "@/components/BotDetailView.jsx";
import { DealershipPage } from "@/components/DealershipPage.jsx";
import { Button } from "@/ui/button.jsx";
import { useWebSocketHub } from "@/hooks/useWebSocketHub.js";

export default function App() {
  const {
    bots,
    selectedBotId,
    selectedBot,
    selectedAccountName,
    setSelectedBotId,
    activeTab,
    setActiveTab,
    wsStatus,
    isWsOnline,
    logsHistory,
    clearLogs,
    sendBotCommand,
    rejoinBot,
    dealerCatalog,
    fetchDealerCars,
    buyCar
  } = useWebSocketHub();

  const [currentPath, setCurrentPath] = React.useState(() => typeof window !== "undefined" ? window.location.pathname : "/");

  React.useEffect(() => {
    const handleLocationChange = () => setCurrentPath(window.location.pathname);
    window.addEventListener("popstate", handleLocationChange);
    return () => window.removeEventListener("popstate", handleLocationChange);
  }, []);

  const isDealerRoute = currentPath.startsWith("/cdid_");
  const urlDealerRaw = isDealerRoute ? currentPath.replace(/^\/cdid_/, "").replace(/\//g, "") : null;
  const initialDealerName = urlDealerRaw && urlDealerRaw !== "dealer"
    ? urlDealerRaw.charAt(0).toUpperCase() + urlDealerRaw.slice(1)
    : "Semua Dealer";

  if (isDealerRoute) {
    return (
      <DealershipPage
        initialDealer={initialDealerName}
        bots={bots}
        activeBot={selectedBot || Array.from(bots.values())[0]}
        onSelectBot={setSelectedBotId}
        dealerCatalog={dealerCatalog}
        onFetchCars={fetchDealerCars}
        onBuyCar={buyCar}
        isWsOnline={isWsOnline}
        wsStatus={wsStatus}
        onBackToDashboard={() => {
          window.history.pushState(null, "", "/");
          setCurrentPath("/");
        }}
      />
    );
  }

  return (
    <div className="flex h-screen h-[100dvh] w-screen overflow-hidden bg-zinc-950 text-zinc-100">
      
      {/* 1. Desktop Full-Height Sidebar on the Left Edge */}
      <Sidebar
        bots={bots}
        selectedBotId={selectedBotId}
        onSelectBot={setSelectedBotId}
      />

      {/* 2. Main Workspace */}
      <div className="flex-1 flex flex-col min-w-0 h-full overflow-hidden">
        
        {/* Top Navbar */}
        <Navbar
          bots={bots}
          selectedBotId={selectedBotId}
          onSelectBot={setSelectedBotId}
          isWsOnline={isWsOnline}
          wsStatus={wsStatus}
        />

        {/* Scrollable Viewport */}
        <main className="flex-1 overflow-y-auto p-4 pb-32 sm:p-6 sm:pb-12 lg:p-8 lg:pb-16 bg-zinc-950/60 overscroll-contain">
          <div className="w-full max-w-6xl mx-auto space-y-6 pb-6">
            {selectedAccountName === "ALL" ? (
              <FleetOverview
                bots={bots}
                onSelectBot={setSelectedBotId}
                onSendCommand={sendBotCommand}
                onRejoinBot={rejoinBot}
              />
            ) : selectedBot ? (
              <BotDetailView
                bot={selectedBot}
                activeTab={activeTab}
                onTabChange={setActiveTab}
                logs={logsHistory}
                onClearLogs={clearLogs}
                onSendCommand={sendBotCommand}
                onRejoinBot={rejoinBot}
              />
            ) : (
              /* State Teleportasi / Menghubungkan Ulang: Jangan melempar user ke home */
              <div className="flex flex-col items-center justify-center py-16 px-6 text-center rounded-2xl border border-zinc-800 bg-zinc-900/40">
                <div className="h-8 w-8 rounded-full border-2 border-indigo-500 border-t-transparent animate-spin mb-4" />
                <h3 className="font-bold text-base text-zinc-100">Menghubungkan ke Akun ({selectedAccountName})...</h3>
                <p className="text-xs text-zinc-400 mt-1 max-w-sm leading-relaxed">
                  Akun sedang proses teleportasi server Roblox atau reconnecting. Halaman akan tersinkron otomatis begitu Roblox siap.
                </p>
                <Button
                  variant="outline"
                  size="sm"
                  className="mt-5 text-xs font-semibold border-zinc-700 hover:bg-zinc-800"
                  onClick={() => setSelectedBotId("ALL")}
                >
                  Kembali ke Semua Akun
                </Button>
              </div>
            )}
          </div>
        </main>
      </div>

    </div>
  );
}
