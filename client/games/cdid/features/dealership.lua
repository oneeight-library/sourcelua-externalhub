--[[
    CDID Feature: Dealership Controller, Catalog Extractor & Remote Buy
    100% Berbasis Nilai car.Dealership.Value dari ReplicatedStorage.CarData
--]]
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DealershipFeature = {}

-- Urutan resmi nama dealer CDID langsung dari nilai Dealership di CarData
local DEFAULT_DEALER_LIST = {
    "77", "Bandung", "Otnas", "Premium", "Toyota", "Honda",
    "Hyundai", "Mitsubishi", "MercedesBenz", "Suzuki", "Daihatsu",
    "KIA", "Nissan", "Mazda", "Lexus", "Wuling", "Audi", "VW",
    "DIR", "Chery", "Jaecoo", "Geely", "Shehua", "SLM", "Komersial"
}

function DealershipFeature.GetRealDealerList()
    local list = {}
    local seen = {}

    -- Baca langsung semua nilai unik dari car.Dealership.Value di ReplicatedStorage.CarData
    pcall(function()
        local carData = ReplicatedStorage:FindFirstChild("CarData")
        if carData then
            for _, car in ipairs(carData:GetChildren()) do
                local unobtainable = car:FindFirstChild("Unobtainable")
                local d = car:FindFirstChild("Dealership") and car.Dealership.Value
                if d and d ~= "" and not unobtainable then
                    if d == "Komersil" then d = "Komersial" end
                    if not seen[d] then
                        seen[d] = true
                        table.insert(list, d)
                    end
                end
            end
        end
    end)

    if #list == 0 then
        return DEFAULT_DEALER_LIST
    end

    -- Urutkan sesuai urutan populer CDID
    local orderMap = {}
    for idx, name in ipairs(DEFAULT_DEALER_LIST) do
        orderMap[name:lower()] = idx
    end
    table.sort(list, function(a, b)
        local oa = orderMap[a:lower()] or 999
        local ob = orderMap[b:lower()] or 999
        if oa ~= ob then return oa < ob end
        return a:lower() < b:lower()
    end)

    return list
end

local GamepassMaps = nil
local function getGamepassMaps()
    if GamepassMaps then return GamepassMaps end
    GamepassMaps = {
        Luxury = {},
        Rare = {},
        Retro = {},
        Emergency = {},
        Limited = {},
        New = {}
    }
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    if shared then
        local function fill(name, target)
            local m = shared:FindFirstChild(name)
            if m and m:IsA("ModuleScript") then
                local ok, data = pcall(require, m)
                if ok and type(data) == "table" then
                    for _, id in ipairs(data) do
                        target[tostring(id):lower()] = true
                    end
                end
            end
        end
        fill("LuxuryCar", GamepassMaps.Luxury)
        fill("RareImportCar", GamepassMaps.Rare)
        fill("RetroCar", GamepassMaps.Retro)
        fill("EmergencyCar", GamepassMaps.Emergency)
        fill("LimitedCar", GamepassMaps.Limited)
        fill("NewCar", GamepassMaps.New)

        -- Load from Shared.Data.LimitedList
        local dataFolder = shared:FindFirstChild("Data")
        local limListMod = dataFolder and dataFolder:FindFirstChild("LimitedList")
        if limListMod and limListMod:IsA("ModuleScript") then
            local ok, data = pcall(require, limListMod)
            if ok and type(data) == "table" then
                for _, id in ipairs(data) do
                    GamepassMaps.Limited[tostring(id):lower()] = true
                end
            end
        end
    end
    return GamepassMaps
end

function DealershipFeature.GetCars(dealerTarget)
    local list = {}
    local carData = ReplicatedStorage:FindFirstChild("CarData")
    if not carData then return list end

    local cleanTarget = tostring(dealerTarget or ""):lower():gsub("%s+", "")
    if cleanTarget == "komersil" then cleanTarget = "komersial" end

    -- 1. Ambil Server Time resmi dari Backend Remote CDID (Network.GetServerTime)
    local serverTime = os.time()
    pcall(function()
        local mod = ReplicatedStorage:FindFirstChild("Modules")
        if mod and mod:FindFirstChild("Network") then
            local Network = require(mod.Network)
            local st = Network:InvokeServer("GetServerTime")
            if type(st) == "number" and st > 0 then
                serverTime = st
            end
        end
    end)

    -- 2. Ambil jadwal limited langsung dari Backend Memory Game (end_ts)
    local timeMap = {}
    pcall(function()
        if getgc then
            for _, t in ipairs(getgc(true)) do
                if type(t) == "table" then
                    local firstVal = nil
                    for _, v in pairs(t) do
                        firstVal = v
                        break
                    end
                    if type(firstVal) == "table" and rawget(firstVal, "end_ts") and rawget(firstVal, "start_ts") then
                        for carId, entry in pairs(t) do
                        if type(entry) == "table" and entry.end_ts and type(entry.end_ts) == "table" then
                            local expTs = os.time(entry.end_ts)
                            local startTs = entry.start_ts and os.time(entry.start_ts) or 0
                            if startTs > serverTime then
                                -- Mobil terjadwal rilis di masa depan (Upcoming Bocoran)
                                local diffStart = startTs - serverTime
                                local h = math.floor(diffStart / 3600)
                                local m = math.floor((diffStart % 3600) / 60)
                                local s = diffStart % 60
                                timeMap[tostring(carId):lower()] = {
                                    timeLeft = string.format("%02i:%02i:%02i", h, m, s),
                                    expiresAt = expTs,
                                    startAt = startTs,
                                    isUpcoming = true,
                                    serverTime = serverTime
                                }
                            else
                                local diffSec = expTs - serverTime
                                if diffSec > 0 then
                                    local h = math.floor(diffSec / 3600)
                                    local m = math.floor((diffSec % 3600) / 60)
                                    local s = diffSec % 60
                                    timeMap[tostring(carId):lower()] = {
                                        timeLeft = string.format("%02i:%02i:%02i", h, m, s),
                                        expiresAt = expTs,
                                        isUpcoming = false,
                                        serverTime = serverTime
                                    }
                                end
                            end
                        end
                    end
                        break
                    end
                end
            end
        end
    end)

    -- 3. Fallback: Ambil dari TextLabel UI jika memory schedule tidak terjangkau
    pcall(function()
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        local dGui = pGui and pGui:FindFirstChild("Dealership")
        local dList = dGui and dGui:FindFirstChild("Container") and dGui.Container:FindFirstChild("Dealership") and dGui.Container.Dealership:FindFirstChild("Dealerlist")
        if dList then
            for _, dFolder in ipairs(dList:GetChildren()) do
                for _, cFrame in ipairs(dFolder:GetChildren()) do
                    local lowerName = cFrame.Name:lower()
                    if not timeMap[lowerName] then
                        local tLbl = cFrame:FindFirstChild("Frame") and cFrame.Frame:FindFirstChild("Time")
                        if tLbl and tLbl:IsA("TextLabel") and tLbl.Text ~= "" and tLbl.Text ~= "00:00:00" then
                            local h, m, s = tLbl.Text:match("(%d+):(%d+):(%d+)")
                            local sec = 0
                            if h and m and s then
                                sec = tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s)
                            end
                            timeMap[lowerName] = {
                                timeLeft = tLbl.Text,
                                expiresAt = (sec > 0) and (serverTime + sec) or nil,
                                serverTime = serverTime
                            }
                        end
                    end
                end
            end
        end
    end)

    local maps = getGamepassMaps()

    for _, car in ipairs(carData:GetChildren()) do
        local dealerVal = car:FindFirstChild("Dealership")
        local unobtainable = car:FindFirstChild("Unobtainable")
        local lowerId = car.Name:lower()
        local timeInfo = timeMap[lowerId]

        -- Kategori "Upcoming" HANYA diberikan jika ada entri start_ts di memori server yang menunjukkan waktu rilis di masa depan (start_ts > now)
        local isUpcoming = false
        if timeInfo and timeInfo.isUpcoming == true then
            isUpcoming = true
        end

        if dealerVal and (not unobtainable or isUpcoming) then
            local rawDealer = tostring(dealerVal.Value)
            local cleanDealer = rawDealer:lower():gsub("%s+", "")
            if cleanDealer == "komersil" then cleanDealer = "komersial" end

            local isMatch = false
            if cleanTarget == "" or cleanTarget == "all" or cleanTarget == "semuadealer" then
                isMatch = true
            elseif cleanDealer == cleanTarget then
                -- PURE EXACT MATCH terhadap nilai car.Dealership.Value
                isMatch = true
            end

            if isMatch then
                local maps = getGamepassMaps()
                local lowerId = car.Name:lower()
                local gamepassLabel = ""
                local isGamepass = false

                if maps.Luxury[lowerId] then
                    gamepassLabel = "Luxury"
                    isGamepass = true
                elseif maps.Rare[lowerId] then
                    gamepassLabel = "Rare Import"
                    isGamepass = true
                elseif maps.Retro[lowerId] then
                    gamepassLabel = "Retro"
                    isGamepass = true
                elseif maps.Emergency[lowerId] then
                    gamepassLabel = "Emergency"
                    isGamepass = true
                end

                local timeInfo = timeMap[lowerId]
                local timeLeft = timeInfo and timeInfo.timeLeft or ""
                local expiresAt = timeInfo and timeInfo.expiresAt or nil
                local isLimited = false
                if maps.Limited[lowerId] or car:FindFirstChild("Limited") or timeLeft ~= "" then
                    isLimited = true
                end

                local isNew = maps.New[lowerId] == true

                local stockVal = nil
                local stockFolder = ReplicatedStorage:FindFirstChild("LimitedStock")
                if stockFolder then
                    local sItem = stockFolder:FindFirstChild(car.Name)
                    if sItem and (sItem:IsA("IntValue") or sItem:IsA("NumberValue")) then
                        stockVal = sItem.Value
                    end
                end

                local img = car:FindFirstChild("CarImage") and car.CarImage.Value or ""
                local assetId = img:match("id=(%d+)") or img:match("(%d+)$") or ""
                local engineVal = car:FindFirstChild("Engine") and tostring(car.Engine.Value) or ""
                local seaterVal = car:FindFirstChild("Seater") and tostring(car.Seater.Value) or ""
                table.insert(list, {
                    id = car.Name,
                    name = car:FindFirstChild("CarName") and car.CarName.Value or car.Name,
                    cost = car:FindFirstChild("Cost") and car.Cost.Value or 0,
                    dealer = rawDealer, -- Nilai tepat dari car.Dealership.Value
                    assetId = assetId,
                    topSpeed = car:FindFirstChild("TopSpeed") and car.TopSpeed.Value or 0,
                    hp = car:FindFirstChild("Horsepower") and car.Horsepower.Value or 0,
                    year = car:FindFirstChild("CarYear") and car.CarYear.Value or "",
                    engine = engineVal,
                    seater = seaterVal,
                    gamepass = gamepassLabel,
                    isGamepass = isGamepass,
                    isLimited = isLimited,
                    isNew = isNew,
                    isUpcoming = isUpcoming,
                    stock = stockVal,
                    timeLeft = timeLeft,
                    expiresAt = expiresAt,
                    serverTime = serverTime
                })
            end
        end
    end

    table.sort(list, function(a, b) return a.cost < b.cost end)
    return list
end

function DealershipFeature.Buy(carId, dealer, color, Context)
    local colorName = "White"
    if type(color) == "string" and color ~= "" then
        colorName = color
    elseif type(color) == "table" and color.name then
        colorName = color.name
    end

    local cMap = {
        ["Putih"] = "White",
        ["Hitam"] = "Black",
        ["Silver"] = "White",
        ["Abu-abu"] = "Black",
        ["Merah"] = "Red",
        ["Biru"] = "Blue",
        ["Kuning"] = "Yellow",
        ["Oranye"] = "Orange",
        ["Hijau"] = "Green",
        ["Pink"] = "Pink"
    }
    colorName = cMap[colorName] or colorName or "White"

    local result = "Failed"
    pcall(function()
        local Network = require(ReplicatedStorage.Modules.Network)
        result = Network:InvokeServer("Dealership", "Buy", carId, colorName, dealer or "")
    end)
    local isSuccess = (result == "Success")
    if Context and Context.SendLog then
        Context.SendLog(string.format("Hasil beli mobil '%s' (%s, Warna %s): %s", carId, tostring(dealer), colorName, tostring(result)), isSuccess and "SUCCESS" or "WARN")
    end
    if Context and Context.SendPacket then
        pcall(function()
            Context.SendPacket("BUY_CAR_RESULT", {
                carId = carId,
                dealer = dealer or "",
                color = colorName,
                success = isSuccess,
                message = tostring(result)
            })
        end)
    end
    return result
end

function DealershipFeature.Open(dealerName, Context)
    dealerName = dealerName or "77"
    pcall(function()
        local etc = Workspace:FindFirstChild("Etc") or Instance.new("Folder", Workspace)
        etc.Name = "Etc"
        local dealershipFolder = etc:FindFirstChild("Dealership") or Instance.new("Folder", etc)
        dealershipFolder.Name = "Dealership"

        local oldFake = dealershipFolder:FindFirstChild("Fake_" .. dealerName)
        if oldFake then oldFake:Destroy() end

        local fakeModel = Instance.new("Model")
        fakeModel.Name = dealerName
        fakeModel.Parent = dealershipFolder

        local fakePrompt = Instance.new("ProximityPrompt")
        fakePrompt.Parent = fakeModel

        if typeof(firesignal) == "function" then
            firesignal(game:GetService("ProximityPromptService").PromptTriggered, fakePrompt)
            if Context and Context.SendLog then
                Context.SendLog(string.format("UI Dealership '%s' berhasil dibuka.", dealerName), "SUCCESS")
            end
        elseif Context and Context.SendLog then
            Context.SendLog("Executor tidak mendukung firesignal.", "WARN")
        end

        task.delay(1.5, function()
            if fakeModel then fakeModel:Destroy() end
        end)
    end)
end

function DealershipFeature.Teleport(dealerName, Context)
    pcall(function()
        local dealershipFolder = Workspace:FindFirstChild("Etc") and Workspace.Etc:FindFirstChild("Dealership")
        local targetModel = dealershipFolder and dealershipFolder:FindFirstChild(dealerName)
        local char = LocalPlayer.Character
        local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart)
        if hrp and targetModel then
            hrp.CFrame = targetModel:GetPivot() * CFrame.new(0, 0, 3.5)
            if Context and Context.SendLog then
                Context.SendLog(string.format("Teleport ke showroom '%s' berhasil.", dealerName), "SUCCESS")
            end
        elseif hrp then
            hrp.CFrame = CFrame.new(Vector3.new(34800, 140, -54200))
        end
    end)
end

return DealershipFeature
