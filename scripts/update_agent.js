import fs from "fs";

const lighting = fs.readFileSync("client/games/cdid/features/lighting.lua", "utf8");
const safety = fs.readFileSync("client/games/cdid/features/safety.lua", "utf8");
const dealership = fs.readFileSync("client/games/cdid/features/dealership.lua", "utf8");
const teleport = fs.readFileSync("client/games/cdid/features/teleport.lua", "utf8");
const truck = fs.readFileSync("client/games/cdid/jobs/truck.lua", "utf8");
const init = fs.readFileSync("client/games/cdid/init.lua", "utf8");

let agentLua = fs.readFileSync("client/agent.lua", "utf8");

function replaceModule(source, moduleName, moduleContent) {
  const prefix = `Modules["${moduleName}"] = function()`;
  const startIdx = source.indexOf(prefix);
  if (startIdx === -1) {
    console.warn(`Module prefix not found: ${prefix}`);
    return source;
  }
  
  const nextModuleIdx = source.indexOf('\nModules["', startIdx + prefix.length);
  const endIdx = nextModuleIdx !== -1 
    ? source.lastIndexOf('\nend\n', nextModuleIdx) 
    : source.indexOf('\nend\n', startIdx);
  
  if (endIdx === -1) {
    console.warn(`Module end not found for ${moduleName}`);
    return source;
  }

  const before = source.substring(0, startIdx + prefix.length);
  const after = source.substring(endIdx);
  console.log(`Replaced ${moduleName} (start: ${startIdx}, end: ${endIdx})`);
  return before + "\n" + moduleContent.trim() + after;
}

agentLua = replaceModule(agentLua, "games/cdid/features/lighting", lighting);
agentLua = replaceModule(agentLua, "games/cdid/features/safety", safety);
agentLua = replaceModule(agentLua, "games/cdid/features/dealership", dealership);
agentLua = replaceModule(agentLua, "games/cdid/features/teleport", teleport);
agentLua = replaceModule(agentLua, "games/cdid/jobs/truck", truck);
agentLua = replaceModule(agentLua, "games/cdid", init);

fs.writeFileSync("client/agent.lua", agentLua, "utf8");
console.log("Updated client/agent.lua with all sub-modules!");

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
console.log("Updated src/agent_code.js successfully with modular architecture!");
