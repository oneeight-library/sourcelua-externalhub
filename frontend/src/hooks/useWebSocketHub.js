import { useState, useEffect, useRef, useCallback } from "react";

export function useWebSocketHub() {
  const [bots, setBots] = useState(new Map());
  
  // 1. Persist Selected Account Name (Berdasarkan Username Akun Roblox)
  const [selectedAccountName, setSelectedAccountName] = useState(() => {
    try {
      return localStorage.getItem("oe_selected_account") || "ALL";
    } catch (e) {
      return "ALL";
    }
  });

  const [activeTab, setActiveTab] = useState("tab_autofarm");
  const [dealerCatalog, setDealerCatalog] = useState({});
  const [wsStatus, setWsStatus] = useState("Menghubungkan");
  const [isWsOnline, setIsWsOnline] = useState(false);
  const [buyCarResult, setBuyCarResult] = useState(null);

  // 2. Persist Logs History di SessionStorage (agar saat F5 / Refresh riwayat log tidak hilang)
  const [logsHistory, setLogsHistory] = useState(() => {
    try {
      const saved = sessionStorage.getItem("oe_logs_history");
      return saved ? JSON.parse(saved) : [];
    } catch (e) {
      return [];
    }
  });
  
  const socketRef = useRef(null);

  const addLog = useCallback((source, msg, level = "INFO", botId = null) => {
    const timeStr = new Date().toTimeString().split(" ")[0];
    setLogsHistory((prev) => {
      const next = [...prev, { id: Math.random().toString(36), time: timeStr, source, msg, level, botId }];
      const trimmed = next.length > 150 ? next.slice(-150) : next;
      try {
        sessionStorage.setItem("oe_logs_history", JSON.stringify(trimmed));
      } catch (e) {}
      return trimmed;
    });
  }, []);

  const clearLogs = useCallback((targetBotId) => {
    if (!targetBotId || targetBotId === "ALL") {
      setLogsHistory([]);
      try { sessionStorage.removeItem("oe_logs_history"); } catch (e) {}
    } else {
      setLogsHistory((prev) => {
        const filtered = prev.filter((l) => l.botId !== targetBotId);
        try { sessionStorage.setItem("oe_logs_history", JSON.stringify(filtered)); } catch (e) {}
        return filtered;
      });
    }
  }, []);

  const sendBotCommand = useCallback((targetBotId, action, payload = {}) => {
    if (!socketRef.current || socketRef.current.readyState !== WebSocket.OPEN) return;
    socketRef.current.send(JSON.stringify({
      type: "COMMAND",
      targetBotId,
      action,
      payload
    }));
  }, []);

  const rejoinBot = useCallback((botId) => {
    sendBotCommand(botId, "REJOIN_SERVER");
    addLog("Controller", "Mengirim perintah Rejoin Server...", "WARN", botId);
  }, [sendBotCommand, addLog]);

  const fetchDealerCars = useCallback((botId, dealer = "all") => {
    sendBotCommand(botId, "FETCH_DEALER_CARS", { dealer });
  }, [sendBotCommand]);

  const buyCar = useCallback((botId, carId, dealer, color) => {
    sendBotCommand(botId, "BUY_CAR", { carId, dealer, color });
    addLog("Controller", `Mengirim perintah beli mobil: ${carId} (${dealer})`, "INFO", botId);
  }, [sendBotCommand, addLog]);

  // Resolusi bot terpilih secara tangguh (mencocokkan botId ATAU account username)
  let resolvedBot = null;
  if (selectedAccountName !== "ALL") {
    for (const [id, b] of bots.entries()) {
      if (id === selectedAccountName || (b.name && b.name.toLowerCase() === selectedAccountName.toLowerCase())) {
        resolvedBot = b;
        break;
      }
    }
  }

  const selectedBotId = resolvedBot ? resolvedBot.botId : selectedAccountName;

  const setSelectedBotId = useCallback((id) => {
    if (id === "ALL") {
      setSelectedAccountName("ALL");
      try { localStorage.setItem("oe_selected_account", "ALL"); } catch (e) {}
    } else {
      const b = bots.get(id);
      const accName = b && b.name ? b.name : id;
      setSelectedAccountName(accName);
      try { localStorage.setItem("oe_selected_account", accName); } catch (e) {}
    }
  }, [bots]);

  useEffect(() => {
    let wsUrl = window.__HUB_WS_ENDPOINT__;
    if (!wsUrl || typeof wsUrl !== "string" || wsUrl.includes("__")) {
      const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
      wsUrl = `${protocol}//${window.location.host}/ws`;
    }

    let socket;
    let reconnectTimer;

    function connect() {
      socket = new WebSocket(wsUrl);
      socketRef.current = socket;

      socket.onopen = () => {
        setIsWsOnline(true);
        setWsStatus("Online");
      };

      socket.onclose = () => {
        setIsWsOnline(false);
        setWsStatus("Offline");
        reconnectTimer = setTimeout(connect, 3000);
      };

      socket.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          
          if (data.type === "SYNC_BOTS") {
            const map = new Map();
            (data.bots || []).forEach((b) => {
              for (const [id, existing] of map.entries()) {
                if (existing.name && b.name && existing.name.toLowerCase() === b.name.toLowerCase()) {
                  map.delete(id);
                }
              }
              map.set(b.botId || b.id, b);
            });
            setBots(map);

          } else if (data.type === "LOG_HISTORY") {
            setLogsHistory((prev) => {
              const existingIds = new Set(prev.map(l => l.id));
              const incoming = (data.logs || []).map(l => ({
                id: l.id || Math.random().toString(36),
                time: new Date(l.timestamp || Date.now()).toTimeString().split(" ")[0],
                source: l.botName || "Bot",
                msg: l.log,
                level: l.level || "INFO",
                botId: l.botId
              })).filter(l => !existingIds.has(l.id));
              const combined = [...prev, ...incoming];
              const trimmed = combined.length > 150 ? combined.slice(-150) : combined;
              try { sessionStorage.setItem("oe_logs_history", JSON.stringify(trimmed)); } catch (e) {}
              return trimmed;
            });

          } else if (data.type === "BOT_JOINED") {
            setBots((prev) => {
              const next = new Map(prev);
              for (const [id, existing] of next.entries()) {
                if (existing.name && data.bot.name && existing.name.toLowerCase() === data.bot.name.toLowerCase()) {
                  next.delete(id);
                }
              }
              next.set(data.bot.botId, data.bot);
              return next;
            });
            addLog(data.bot.name, `Akun terhubung (${data.bot.gameName || 'Roblox'})`, "SUCCESS", data.bot.botId);

          } else if (data.type === "BOT_LEFT") {
            setBots((prev) => {
              const next = new Map(prev);
              next.delete(data.botId);
              return next;
            });
            // CATATAN PENTING: JANGAN melempar user ke 'ALL' saat BOT_LEFT!
            // Karena jika akun sedang teleportasi / reconnecting, akun akan segera kembali dengan nama yang sama.
            addLog(data.name || "Bot", "Koneksi terputus (reconnect/teleport)...", "WARN", data.botId);

          } else if (data.type === "BOT_TELEMETRY") {
            setBots((prev) => {
              const next = new Map(prev);
              const target = next.get(data.botId);
              if (target) {
                next.set(data.botId, { ...target, ...(data.payload || {}) });
              }
              return next;
            });

          } else if (data.type === "CLIENT_KICKED" || data.type === "BOT_KICKED") {
            setBots((prev) => {
              const next = new Map(prev);
              const target = next.get(data.botId);
              if (target) {
                next.set(data.botId, {
                  ...target,
                  isKicked: true,
                  kickReason: data.reason || data.payload?.reason,
                  status: `KICKED (${data.reason || data.payload?.reason || 'Disconnect'})`
                });
              }
              return next;
            });
            addLog(data.botName || "Bot", `ROBLOX KICK: ${data.reason || data.payload?.reason || 'Disconnect'}`, "ERROR", data.botId);

          } else if (data.type === "BUY_CAR_RESULT") {
            setBuyCarResult({
              ...data.payload,
              botId: data.botId,
              botName: data.botName,
              timestamp: Date.now()
            });
            addLog(data.botName || "Bot", `Respon beli mobil: ${data.payload?.success ? 'BERHASIL' : 'GAGAL'} (${data.payload?.message || ''})`, data.payload?.success ? "SUCCESS" : "WARN", data.botId);
          } else if (data.type === "DEALER_CARS_DATA") {
            const dealerKey = (data.dealer || "all").toLowerCase().replace(/\s+/g, "");
            setDealerCatalog((prev) => ({
              ...prev,
              [dealerKey]: data.cars || [],
              lastUpdated: Date.now()
            }));
          } else if (data.type === "BOT_LOG") {
            addLog(data.botName || "Bot", data.log, data.level, data.botId);
          }
        } catch (e) {
          console.error("Socket parse error:", e);
        }
      };
    }

    connect();

    return () => {
      clearTimeout(reconnectTimer);
      if (socket) socket.close();
    };
  }, [addLog]);

  return {
    bots,
    selectedBotId,
    selectedBot: resolvedBot,
    selectedAccountName,
    setSelectedBotId,
    activeTab,
    setActiveTab,
    wsStatus,
    isWsOnline,
    logsHistory,
    addLog,
    clearLogs,
    sendBotCommand,
    rejoinBot,
    dealerCatalog,
    fetchDealerCars,
    buyCar,
    buyCarResult
  };
}
