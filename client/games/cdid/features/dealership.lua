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

function DealershipFeature.GetCars(dealerTarget)
    local list = {}
    local carData = ReplicatedStorage:FindFirstChild("CarData")
    if not carData then return list end

    local cleanTarget = tostring(dealerTarget or ""):lower():gsub("%s+", "")
    if cleanTarget == "komersil" then cleanTarget = "komersial" end

    for _, car in ipairs(carData:GetChildren()) do
        local dealerVal = car:FindFirstChild("Dealership")
        local unobtainable = car:FindFirstChild("Unobtainable")
        if dealerVal and not unobtainable then
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
                local img = car:FindFirstChild("CarImage") and car.CarImage.Value or ""
                local assetId = img:match("id=(%d+)") or img:match("(%d+)$") or ""
                table.insert(list, {
                    id = car.Name,
                    name = car:FindFirstChild("CarName") and car.CarName.Value or car.Name,
                    cost = car:FindFirstChild("Cost") and car.Cost.Value or 0,
                    dealer = rawDealer, -- Nilai tepat dari car.Dealership.Value
                    assetId = assetId,
                    topSpeed = car:FindFirstChild("TopSpeed") and car.TopSpeed.Value or 0,
                    hp = car:FindFirstChild("Horsepower") and car.Horsepower.Value or 0,
                    year = car:FindFirstChild("CarYear") and car.CarYear.Value or ""
                })
            end
        end
    end

    table.sort(list, function(a, b) return a.cost < b.cost end)
    return list
end

function DealershipFeature.Buy(carId, dealer, color, Context)
    local color3 = (color and Color3.fromRGB(color.r or 255, color.g or 255, color.b or 255)) or Color3.fromRGB(255, 255, 255)
    local result = "Failed"
    pcall(function()
        local net = require(ReplicatedStorage.Shared.Network)
        result = net:InvokeServer("Dealership", "Buy", carId, color3, dealer or "")
    end)
    if Context and Context.SendLog then
        Context.SendLog(string.format("Hasil beli mobil '%s' (%s): %s", carId, dealer, tostring(result)), result == "Success" and "SUCCESS" or "WARN")
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
