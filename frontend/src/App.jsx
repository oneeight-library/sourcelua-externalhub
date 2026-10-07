import * as React from "react";
import { Navbar } from "@/components/Navbar.jsx";
import { Sidebar } from "@/components/Sidebar.jsx";
import { FleetOverview } from "@/components/FleetOverview.jsx";
import { BotDetailView } from "@/components/BotDetailView.jsx";
import { useWebSocketHub } from "@/hooks/useWebSocketHub.js";

export default function App() {
  const {
    bots,
    selectedBotId,
    setSelectedBotId,
    activeTab,
    setActiveTab,
    wsStatus,
    isWsOnline,
    logsHistory,
    clearLogs,
    sendBotCommand,
    rejoinBot
  } = useWebSocketHub();

  const selectedBot = bots.get(selectedBotId);

  return (
    <div className="flex h-screen w-screen overflow-hidden bg-zinc-950 text-zinc-100">
      
      {/* 1. Desktop Full-Height Sidebar on the Left Edge */}
      <Sidebar
        bots={bots}
        selectedBotId={selectedBotId}
        onSelectBot={setSelectedBotId}
      />

      {/* 2. Main Workspace (Fills all remaining screen width) */}
      <div className="flex-1 flex flex-col min-w-0 h-full overflow-hidden">
        
        {/* Top Navbar */}
        <Navbar
          bots={bots}
          selectedBotId={selectedBotId}
          onSelectBot={setSelectedBotId}
          isWsOnline={isWsOnline}
          wsStatus={wsStatus}
        />

        {/* Scrollable Viewport (No more weird centered container!) */}
        <main className="flex-1 overflow-y-auto p-4 sm:p-6 lg:p-8 bg-zinc-950/60">
          <div className="w-full max-w-6xl mx-auto space-y-6">
            {selectedBotId === "ALL" || !selectedBot ? (
              <FleetOverview
                bots={bots}
                onSelectBot={setSelectedBotId}
                onSendCommand={sendBotCommand}
                onRejoinBot={rejoinBot}
              />
            ) : (
              <BotDetailView
                bot={selectedBot}
                activeTab={activeTab}
                onTabChange={setActiveTab}
                logs={logsHistory}
                onClearLogs={clearLogs}
                onSendCommand={sendBotCommand}
                onRejoinBot={rejoinBot}
              />
            )}
          </div>
        </main>
      </div>

    </div>
  );
}
