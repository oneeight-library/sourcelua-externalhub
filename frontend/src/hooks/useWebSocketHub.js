import { useState, useEffect, useRef, useCallback } from "react";

export function useWebSocketHub() {
  const [bots, setBots] = useState(new Map());
  const [selectedBotId, setSelectedBotId] = useState("ALL");
  const [activeTab, setActiveTab] = useState("tab_autofarm");
  const [wsStatus, setWsStatus] = useState("Menghubungkan");
  const [isWsOnline, setIsWsOnline] = useState(false);
  const [logsHistory, setLogsHistory] = useState([]);
  
  const socketRef = useRef(null);

  const addLog = useCallback((source, msg, level = "INFO", botId = null) => {
    const timeStr = new Date().toTimeString().split(" ")[0];
    setLogsHistory((prev) => {
      const next = [...prev, { id: Math.random().toString(36), time: timeStr, source, msg, level, botId }];
      return next.length > 150 ? next.slice(-150) : next;
    });
  }, []);

  const clearLogs = useCallback((targetBotId) => {
    if (!targetBotId || targetBotId === "ALL") {
      setLogsHistory([]);
    } else {
      setLogsHistory((prev) => prev.filter((l) => l.botId !== targetBotId));
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

  useEffect(() => {
    let wsUrl = window.__WS_URL__;
    if (!wsUrl || wsUrl === "__WS_URL__") {
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
              map.set(b.id || b.botId, b);
            });
            setBots(map);

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
            setSelectedBotId((cur) => (cur === data.botId ? "ALL" : cur));
            addLog(data.name || "Bot", "Akun offline", "WARN", data.botId);

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
    setSelectedBotId,
    activeTab,
    setActiveTab,
    wsStatus,
    isWsOnline,
    logsHistory,
    addLog,
    clearLogs,
    sendBotCommand,
    rejoinBot
  };
}
