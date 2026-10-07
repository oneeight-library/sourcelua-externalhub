import fs from "fs";

let cdid = fs.readFileSync("client/games/cdid/init.lua", "utf8");

// 1. Add destination trigger helper & micro-jitter to force server Touched event
const oldPivotSection = `    State.PreDeliveryCash = State.CurrentCash or 0
    car:PivotTo(targetCF)

    for _, p in ipairs(car:GetDescendants()) do
        if p:IsA("BasePart") then
            p.AssemblyLinearVelocity = Vector3.zero
            p.AssemblyAngularVelocity = Vector3.zero
        end
    end
    task.wait(1.2)
    return true`;

const newPivotSection = `    State.PreDeliveryCash = State.CurrentCash or 0
    car:PivotTo(targetCF)

    -- Cari Destination Trigger Part di workspace.Etc.Job.Truck.Destination
    local destFolder = workspace:FindFirstChild("Etc") and workspace.Etc:FindFirstChild("Job") and workspace.Etc.Job:FindFirstChild("Truck") and workspace.Etc.Job.Truck:FindFirstChild("Destination")
    local foundDestPart = nil
    if destFolder then
        for _, p in ipairs(destFolder:GetChildren()) do
            if p:IsA("BasePart") and (p.Position - targetPos).Magnitude < 300 then
                foundDestPart = p
                break
            end
        end
    end

    -- Pemicu Touched ke server via firetouchinterest & micro-pergerakan fisik
    local primaryPart = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
    if foundDestPart and primaryPart then
        if firetouchinterest then
            pcall(function()
                firetouchinterest(primaryPart, foundDestPart, 0)
                task.wait(0.05)
                firetouchinterest(primaryPart, foundDestPart, 1)
            end)
        end
    end

    -- Micro-jitter fisik: gerakkan sedikit -0.3 dan +0.3 stud agar physics engine Roblox memicu .Touched di server
    for i = 1, 3 do
        if not State.IsFarming then break end
        car:PivotTo(car:GetPivot() * CFrame.new(0, -0.3, 0))
        task.wait(0.15)
        car:PivotTo(car:GetPivot() * CFrame.new(0, 0.3, 0))
        task.wait(0.15)
    end

    for _, p in ipairs(car:GetDescendants()) do
        if p:IsA("BasePart") then
            p.AssemblyLinearVelocity = Vector3.zero
            p.AssemblyAngularVelocity = Vector3.zero
        end
    end
    task.wait(1.0)
    return true`;

cdid = cdid.replace(oldPivotSection, newPivotSection);

// 2. Fix false positive in State 6: ONLY increment TripCount and send SUCCESS if gained > 0
const oldPayoutLogic = `                State.TripCount = State.TripCount + 1
                if gained > 0 then
                    State.LastSalary = gained
                    State.TotalEarnings = (State.TotalEarnings or 0) + gained
                    if State.StartCash and State.StartCash > 0 and (State.CurrentCash - State.StartCash) > State.TotalEarnings then
                        State.TotalEarnings = State.CurrentCash - State.StartCash
                    end
                    if Context and Context.SendLog then
                        Context.SendLog(string.format("Pengiriman #%d Berhasil! Gaji masuk (+%s)", State.TripCount, formatMoney(gained)), "SUCCESS")
                    end
                else
                    if Context and Context.SendLog then
                        Context.SendLog(string.format("Pengiriman #%d Selesai!", State.TripCount), "SUCCESS")
                    end
                end`;

const newPayoutLogic = `                if gained > 0 then
                    State.TripCount = State.TripCount + 1
                    State.LastSalary = gained
                    State.TotalEarnings = (State.TotalEarnings or 0) + gained
                    if State.StartCash and State.StartCash > 0 and (State.CurrentCash - State.StartCash) > State.TotalEarnings then
                        State.TotalEarnings = State.CurrentCash - State.StartCash
                    end
                    if Context and Context.SendLog then
                        Context.SendLog(string.format("Pengiriman #%d Berhasil! Gaji masuk (+%s)", State.TripCount, formatMoney(gained)), "SUCCESS")
                    end
                else
                    if Context and Context.SendLog then
                        Context.SendLog(string.format("Pengiriman belum terhitung server (gaji tidak terdeteksi). Tidak menambah trip.", State.TripCount), "WARN")
                    end
                end`;

cdid = cdid.replace(oldPayoutLogic, newPayoutLogic);

fs.writeFileSync("client/games/cdid/init.lua", cdid, "utf8");

// Update client/agent.lua
let agentLua = fs.readFileSync("client/agent.lua", "utf8");
const cdidModulePattern = /Modules\["games\/cdid"\]\s*=\s*function\(\)[\s\S]*?return CDIDModule\s*\n\s*end/;
if (cdidModulePattern.test(agentLua)) {
    agentLua = agentLua.replace(cdidModulePattern, `Modules["games/cdid"] = function()\n${cdid}\nend`);
    fs.writeFileSync("client/agent.lua", agentLua, "utf8");
    console.log("Updated client/agent.lua");
}

// Generate src/agent_code.js
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
console.log("Updated src/agent_code.js successfully with touch trigger & strict payout validation");
