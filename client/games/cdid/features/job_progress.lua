--[[
    OneEight External Hub - Job Progress & Level Claim Feature
    100% Pure Backend DataReplication Engine
    - Direct read from replica.Data.Jobs (Zero UI scraping)
    - Full mathematical level curve calculation (Levels 1 - 50)
    - Reward Matrix ($24M base + $9.6M/level, +10% income on milestones)
    - Single and Multi-Claim (Claim All) automated execution via Network Remote
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local JobProgressFeature = {}
local Context = nil
local cachedReplica = nil

local function GetReplica()
    if cachedReplica and cachedReplica.Data then
        return cachedReplica
    end
    pcall(function()
        local dataRep = require(ReplicatedStorage.Services.DataReplication)
        local ups = debug.getupvalues(dataRep.GetCash)
        if ups and ups[1] then
            cachedReplica = ups[1]
        end
    end)
    return cachedReplica
end

local function formatRupiah(amount)
    amount = tonumber(amount) or 0
    local formatted = tostring(math.floor(math.abs(amount))):reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")
    return (amount < 0 and "-Rp " or "Rp ") .. formatted
end

local function calculateLevel(rawXp)
    local xp = math.max(math.floor(rawXp or 0), 0)
    local lvl = 1
    while lvl < 50 do
        local nextLvl = lvl + 1
        local n = nextLvl - 1
        local threshold = n * 150 + n * 35 * (n - 1) / 2
        if threshold <= xp then
            lvl = nextLvl
        else
            break
        end
    end
    local n = lvl - 1
    local currentLevelBaseXp = n * 150 + n * 35 * (n - 1) / 2
    local xpInLevel = xp - currentLevelBaseXp
    local xpNeeded = (lvl >= 50) and 0 or ((lvl - 1) * 35 + 150)
    return lvl, xpInLevel, xpNeeded, xp
end

local function getRemote()
    local netContainer = ReplicatedStorage:FindFirstChild("NetworkContainer")
    local remotes = netContainer and netContainer:FindFirstChild("RemoteEvents")
    return remotes and remotes:FindFirstChild("JobProgress")
end

local function fireClaim(jobName, level)
    local Net = nil
    pcall(function()
        local modules = ReplicatedStorage:FindFirstChild("Modules")
        if modules and modules:FindFirstChild("Network") then
            Net = require(modules.Network)
        end
    end)
    if Net and typeof(Net.FireServer) == "function" then
        Net:FireServer("JobProgress", "Claim", jobName, tonumber(level))
    else
        local remote = getRemote()
        if remote then
            remote:FireServer("Claim", jobName, tonumber(level))
        end
    end
end

function JobProgressFeature.Init(coreContext)
    Context = coreContext
    GetReplica()
    print("[OE-External CDID] Modul Job Progress (Level & Claim) Berhasil Diinisialisasi!")
end

function JobProgressFeature.GetRawJobData(jobName)
    local replica = GetReplica()
    if replica and replica.Data and replica.Data.Jobs then
        local jobObj = replica.Data.Jobs[jobName]
        if typeof(jobObj) == "table" then
            return {
                xp = tonumber(jobObj.xp) or 0,
                claimed = (typeof(jobObj.claimed) == "table" and jobObj.claimed) or {},
                titles = (typeof(jobObj.titles) == "table" and jobObj.titles) or {},
                tutorialDone = jobObj.tutorialDone == true
            }
        elseif typeof(jobObj) == "number" then
            return {
                xp = jobObj,
                claimed = {},
                titles = {},
                tutorialDone = true
            }
        end
    end
    return {
        xp = 0,
        claimed = {},
        titles = {},
        tutorialDone = false
    }
end

function JobProgressFeature.GetProgressData(jobName)
    jobName = jobName or "Barista"
    local raw = JobProgressFeature.GetRawJobData(jobName)
    local currentLvl, xpInLevel, xpNeeded, totalXp = calculateLevel(raw.xp)

    local rewards = {}
    local claimableCount = 0
    local totalClaimed = 0

    for lvl = 2, 50 do
        local isMilestone = (lvl % 10 == 0)
        local rewardText = ""
        local cash = 0
        if isMilestone then
            rewardText = "+10% Income Permanen & Gelar Title"
        else
            cash = 24000000 + (lvl - 2) * 9600000
            rewardText = formatRupiah(cash)
        end

        local status = "LOCKED"
        if raw.claimed[tostring(lvl)] == true then
            status = "CLAIMED"
            totalClaimed = totalClaimed + 1
        elseif lvl <= currentLvl then
            status = "CAN_CLAIM"
            claimableCount = claimableCount + 1
        end

        table.insert(rewards, {
            level = lvl,
            isMilestone = isMilestone,
            rewardText = rewardText,
            cash = cash,
            status = status
        })
    end

    local percent = (xpNeeded > 0) and math.clamp(math.floor((xpInLevel / xpNeeded) * 100), 0, 100) or 100
    local replica = GetReplica()
    local equippedTitle = (replica and replica.Data and replica.Data.EquippedTitle) or ""

    return {
        jobName = jobName,
        level = currentLvl,
        xp = totalXp,
        xpInLevel = xpInLevel,
        xpNeeded = xpNeeded,
        percent = percent,
        claimableCount = claimableCount,
        totalClaimed = totalClaimed,
        equippedTitle = equippedTitle,
        rewards = rewards
    }
end

function JobProgressFeature.ClaimLevel(jobName, level)
    jobName = jobName or "Barista"
    level = tonumber(level)
    if not level or level < 2 or level > 50 then return false end

    local raw = JobProgressFeature.GetRawJobData(jobName)
    local currentLvl = calculateLevel(raw.xp)

    if level > currentLvl then
        if Context and Context.SendLog then
            Context.SendLog(string.format("Level %d belum terbuka (Level saat ini: %d)", level, currentLvl), "WARN")
        end
        return false
    end

    if raw.claimed[tostring(level)] == true then
        if Context and Context.SendLog then
            Context.SendLog(string.format("Hadiah Level %d sudah pernah diklaim sebelumnya.", level), "WARN")
        end
        return false
    end

    fireClaim(jobName, level)

    if Context and Context.SendLog then
        Context.SendLog(string.format("Mengklaim hadiah Level %d untuk pekerjaan %s...", level, jobName), "SUCCESS")
    end

    return true
end

function JobProgressFeature.ClaimAll(jobName)
    jobName = jobName or "Barista"
    local raw = JobProgressFeature.GetRawJobData(jobName)
    local currentLvl = calculateLevel(raw.xp)

    local toClaim = {}
    for lvl = 2, math.min(currentLvl, 50) do
        if raw.claimed[tostring(lvl)] ~= true then
            table.insert(toClaim, lvl)
        end
    end

    if #toClaim == 0 then
        if Context and Context.SendLog then
            Context.SendLog("Tidak ada hadiah level baru yang bisa diklaim saat ini.", "INFO")
        end
        return 0
    end

    if Context and Context.SendLog then
        Context.SendLog(string.format("Memulai klaim otomatis untuk %d hadiah level (%s)...", #toClaim, jobName), "INFO")
    end

    task.spawn(function()
        local successCount = 0
        for _, lvl in ipairs(toClaim) do
            fireClaim(jobName, lvl)
            successCount = successCount + 1
            task.wait(0.35)
        end
        if Context and Context.SendLog then
            Context.SendLog(string.format("Selesai mengklaim %d hadiah level %s!", successCount, jobName), "SUCCESS")
        end
    end)

    return #toClaim
end

return JobProgressFeature
