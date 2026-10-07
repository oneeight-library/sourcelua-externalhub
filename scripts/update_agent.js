import fs from "fs";

let cdid = fs.readFileSync("client/games/cdid/init.lua", "utf8");

// Update client/agent.lua
let agentLua = fs.readFileSync("client/agent.lua", "utf8");
const cdidModulePattern = /Modules\["games\/cdid"\]\s*=\s*function\(\)[\s\S]*?return CDIDModule\s*\n\s*end/;
if (cdidModulePattern.test(agentLua)) {
    agentLua = agentLua.replace(cdidModulePattern, `Modules["games/cdid"] = function()\n${cdid}\nend`);
    fs.writeFileSync("client/agent.lua", agentLua, "utf8");
    console.log("Updated client/agent.lua");
}

// Generate src/agent_code.js with AGENT_LUA and getAgentLuaCode
const jsCode = `// Auto-generated from client/agent.lua (UTF-8 without BOM)
export const AGENT_LUA = ${JSON.stringify(agentLua)};

export function getAgentLuaCode(origin) {
  let code = AGENT_LUA;
  if (origin) {
    const wsUrl = origin.replace(/^http/, "ws") + "/ws?role=bot";
    code = code.replace(/wss:\\/\\/[^\\/]+\\/ws\\?role=bot/g, wsUrl);
    code = code.replace(/https:\\/\\/[^\\/]+\\/loader/g, origin + "/loader");
  }
  return code;
}
`;
fs.writeFileSync("src/agent_code.js", jsCode, "utf8");
console.log("Updated src/agent_code.js successfully with getAgentLuaCode");
