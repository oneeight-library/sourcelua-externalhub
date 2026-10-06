import html from "./dashboard.html";

export function getWebDashboardHTML(origin) {
  const wsUrl = origin.replace("https://", "wss://").replace("http://", "ws://") + "/ws";
  return html.replace(/__WS_URL__/g, wsUrl);
}
