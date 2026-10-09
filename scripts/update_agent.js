import fs from "fs";
import path from "path";

const projectRoot = ".";

const HEADER = `--[[
    OneEight External Hub - Master Modular Client Agent
    Version: 3.2.0 (CDID Minigames Sumo & Modular VFS)
--]]

local HttpService = game:GetService("HttpService")
local MY_INSTANCE_ID = HttpService:GenerateGUID(false)

-- Tutup socket lama secara bersih jika ada instance sebelumnya
if _G.OE_ExternalSocket then
    pcall(function() _G.OE_ExternalSocket:Close() end)
end

-- Klaim ID instance aktif saat ini secara atomik
_G.OE_ExternalCurrentInstance = MY_INSTANCE_ID
_G.OE_ExternalRunning = true

local function isInstanceAlive()
    return (_G.OE_ExternalCurrentInstance == MY_INSTANCE_ID)
end

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

-- ============================================================================
-- MODULAR INTERNAL VFS
-- ============================================================================
local Modules = {}
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
    error("[OE-External VFS] Modul tidak ditemukan: " .. tostring(name))
end
`;

const MODULES_CONFIG = [
  { name: "core/safety", file: path.join(process.cwd(), "client/core/safety.lua") },
  { name: "games/base_game", file: path.join(process.cwd(), "client/games/base_game.lua") },
  { name: "games/cdid/features/lighting", file: path.join(process.cwd(), "client/games/cdid/features/lighting.lua") },
  { name: "games/cdid/features/safety", file: path.join(process.cwd(), "client/games/cdid/features/safety.lua") },
  { name: "games/cdid/features/dealership", file: path.join(process.cwd(), "client/games/cdid/features/dealership.lua") },
  { name: "games/cdid/features/teleport", file: path.join(projectRoot, "client/games/cdid/features/teleport.lua") },
  { name: "games/cdid/jobs/truck", file: path.join(projectRoot, "client/games/cdid/jobs/truck.lua") },
  { name: "games/cdid/jobs/minigames", file: path.join(projectRoot, "client/games/cdid/jobs/minigames.lua") },
  { name: "games/cdid", file: path.join(projectRoot, "client/games/cdid/init.lua") },
  { name: "games/cdid_menu", file: path.join(projectRoot, "client/games/cdid/menu.lua") },
  { name: "games/dds", file: path.join(projectRoot, "client/games/dds/init.lua") },
];

let modulesCode = "";
for (const m of MODULES_CONFIG) {
  if (fs.existsSync(m.file)) {
    const content = fs.readFileSync(m.file, "utf8").trim();
    modulesCode += `Modules["${m.name}"] = function()\n${content}\nend\n\n`;
  } else {
    console.error(`ERROR: Module file not found: ${m.file}`);
    process.exit(1);
  }
}

// Extract runner section from agent.lua (from '-- LOAD CORE SAFETY' to end)
const currentAgentLua = fs.readFileSync(path.join(projectRoot, "client/agent.lua"), "utf8");
const runnerMarker = "-- LOAD CORE SAFETY & KICK DETECTOR";
const runnerIdx = currentAgentLua.indexOf(runnerMarker);
if (runnerIdx === -1) {
  throw new Error("Runner section marker not found in agent.lua!");
}

const sepMarker = "-- ============================================================================";
const sepIdx = currentAgentLua.lastIndexOf(sepMarker, runnerIdx);
const runnerCode = (sepIdx !== -1 ? currentAgentLua.substring(sepIdx) : currentAgentLua.substring(runnerIdx)).trim();

const agentLua = `${HEADER.trim()}\n\n${modulesCode}${runnerCode}\n`;

fs.writeFileSync(path.join(projectRoot, "client/agent.lua"), agentLua, "utf8");
console.log("Successfully rebuilt client/agent.lua with all 11 modules and VFS requireModule intact!");

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

fs.writeFileSync(path.join(projectRoot, "src/agent_code.js"), jsCode, "utf8");
console.log("Successfully updated src/agent_code.js!");
