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
    <div className="min-h-screen bg-zinc-950 text-zinc-100 flex flex-col">
      <Navbar
        bots={bots}
        selectedBotId={selectedBotId}
        onSelectBot={setSelectedBotId}
        isWsOnline={isWsOnline}
        wsStatus={wsStatus}
      />

      <div className="flex-1 flex max-w-7xl w-full mx-auto">
        <Sidebar
          bots={bots}
          selectedBotId={selectedBotId}
          onSelectBot={setSelectedBotId}
        />

        <main className="flex-1 p-4 md:p-6 overflow-y-auto">
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
        </main>
      </div>
    </div>
  );
}
