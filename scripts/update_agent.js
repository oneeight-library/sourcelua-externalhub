import fs from "fs";
import path from "path";

const lighting = fs.readFileSync("client/games/cdid/features/lighting.lua", "utf8");
const safety = fs.readFileSync("client/games/cdid/features/safety.lua", "utf8");
const dealership = fs.readFileSync("client/games/cdid/features/dealership.lua", "utf8");
const teleport = fs.readFileSync("client/games/cdid/features/teleport.lua", "utf8");
const truck = fs.readFileSync("client/games/cdid/jobs/truck.lua", "utf8");
const init = fs.readFileSync("client/games/cdid/init.lua", "utf8");

let agentLua = fs.readFileSync("client/agent.lua", "utf8");

// Remove bottom requireModule if present
const oldBottomReqPattern = /local (LoadedModules = \{\}\s+local )?function requireModule\(name\)[\s\S]*?(?=-- =+\s*\n-- LOAD CORE SAFETY)/;
if (oldBottomReqPattern.test(agentLua)) {
    agentLua = agentLua.replace(oldBottomReqPattern, '');
}

// Put clean requireModule at top
const topVfsPattern = /local Modules = \{\}(\s*local LoadedModules = \{\}[\s\S]*?end\n)?/;
const newTopVfs = `local Modules = {}
local LoadedModules = {}

local function requireModule(name)
    if LoadedModules[name] ~= nil then
        return LoadedModules[name]
    end
    if Modules[name] then
        local res = Modules[name]()
        LoadedModules[name] = res
        return res
    end
    error("[OE-External] Modul tidak ditemukan: " .. tostring(name))
end
`;
agentLua = agentLua.replace(topVfsPattern, newTopVfs);

const modularCdidBlock = `
-- ============================================================================
-- MODULAR CDID SUB-MODULES
-- ============================================================================
Modules["games/cdid/features/lighting"] = function()
${lighting}
end

Modules["games/cdid/features/safety"] = function()
${safety}
end

Modules["games/cdid/features/dealership"] = function()
${dealership}
end

Modules["games/cdid/features/teleport"] = function()
${teleport}
end

Modules["games/cdid/jobs/truck"] = function()
${truck}
end

Modules["games/cdid"] = function()
${init}
end
`;

const cdidStartIdx = agentLua.indexOf('Modules["games/cdid');
const cdidMenuIdx = agentLua.indexOf('Modules["games/cdid_menu"]');

if (cdidStartIdx !== -1 && cdidMenuIdx !== -1) {
    agentLua = agentLua.substring(0, cdidStartIdx) + modularCdidBlock.trim() + '\n\n' + agentLua.substring(cdidMenuIdx);
    fs.writeFileSync("client/agent.lua", agentLua, "utf8");
    console.log("Updated client/agent.lua with modular sub-modules!");
}

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
