--[[
    OneEight External Hub - Streamer Mode (Name Spoofing Engine)
    Fungsi:
    - Menyamarkan username dan DisplayName akun menjadi nama samaran (default: "Warga_Sipil")
    - Meliputi: Overhead Nametag karakter, Minimap radar dot, Menu HP CDID (BCA, E-Toll, KTP, Welcome Screen), CoreGui PlayerList, dan Dialog UI
    - Beroperasi 100% pada layer visual lokal sehingga aman dan tidak merusak koneksi remote server
--]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local StreamerMode = {}
StreamerMode.Enabled = true
StreamerMode.SpoofedName = "Warga_Sipil"
StreamerMode.RealName = LocalPlayer.Name
StreamerMode.RealDisplayName = LocalPlayer.DisplayName

local Context = nil
local isRunning = false
local listenerConns = {}

local function sanitizeText(text)
    if not text or text == "" then return text end
    local real = StreamerMode.RealName
    local disp = StreamerMode.RealDisplayName
    local spoof = StreamerMode.SpoofedName

    local res = text
    if real and real ~= "" then
        res = res:gsub(real, spoof)
        if res:find(real:lower(), 1, true) then
            res = res:gsub(real:lower(), spoof)
        end
    end
    if disp and disp ~= "" and disp ~= real then
        res = res:gsub(disp, spoof)
    end
    return res
end

local function replaceLabel(v)
    if not v or not (v:IsA("TextLabel") or v:IsA("TextButton") or v:IsA("TextBox")) then return end
    pcall(function()
        local current = v.Text
        if not current or current == "" then return end

        local orig = v:GetAttribute("OE_OriginalText") or current

        if StreamerMode.Enabled then
            local real = StreamerMode.RealName
            local disp = StreamerMode.RealDisplayName
            local hasReal = (real and orig:find(real, 1, true)) or (real and orig:lower():find(real:lower(), 1, true))
            local hasDisp = (disp and disp ~= "" and orig:find(disp, 1, true))

            if hasReal or hasDisp then
                if not v:GetAttribute("OE_OriginalText") then
                    v:SetAttribute("OE_OriginalText", orig)
                end
                v.Text = sanitizeText(orig)
            end
        else
            local origText = v:GetAttribute("OE_OriginalText")
            if origText then
                v.Text = origText
                v:SetAttribute("OE_OriginalText", nil)
            end
        end
    end)
end

function StreamerMode.SweepAll()
    pcall(function()
        -- 1. Sweep PlayerGui
        if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
            for _, v in ipairs(LocalPlayer.PlayerGui:GetDescendants()) do
                if v:IsA("TextLabel") or v:IsA("TextButton") or v:IsA("TextBox") then
                    replaceLabel(v)
                end
            end
        end

        -- 2. Sweep Overhead Head Nametag in Workspace.Lives
        local lives = Workspace:FindFirstChild("Lives")
        local charLives = lives and lives:FindFirstChild(StreamerMode.RealName)
        if charLives then
            local head = charLives:FindFirstChild("Head")
            local billboard = head and head:FindFirstChild("PlayerBillboard")
            local frame = billboard and billboard:FindFirstChild("Frame")
            local pName = frame and frame:FindFirstChild("PlayerName")
            if pName and pName:IsA("TextLabel") then
                replaceLabel(pName)
            end
        end

        -- 3. Sweep Character Head if in Workspace direct
        local char = LocalPlayer.Character
        if char and char ~= charLives then
            local head = char:FindFirstChild("Head")
            local billboard = head and head:FindFirstChild("PlayerBillboard")
            local frame = billboard and billboard:FindFirstChild("Frame")
            local pName = frame and frame:FindFirstChild("PlayerName")
            if pName and pName:IsA("TextLabel") then
                replaceLabel(pName)
            end
        end

        -- 4. Sweep CoreGui PlayerList
        local core = (gethui and gethui()) or game:GetService("CoreGui")
        local pList = core:FindFirstChild("PlayerList")
        if pList then
            for _, v in ipairs(pList:GetDescendants()) do
                if v:IsA("TextLabel") then
                    replaceLabel(v)
                end
            end
        end
    end)
end

function StreamerMode.Init(coreContext)
    Context = coreContext

    if _G.OE_PreservedState and _G.OE_PreservedState.streamerMode ~= nil then
        StreamerMode.Enabled = _G.OE_PreservedState.streamerMode
    end
    if _G.OE_PreservedState and _G.OE_PreservedState.spoofedName then
        StreamerMode.SpoofedName = _G.OE_PreservedState.spoofedName
    end

    for _, conn in ipairs(listenerConns) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(listenerConns)

    local function setupGuiListener()
        pcall(function()
            local pg = LocalPlayer:WaitForChild("PlayerGui", 5)
            if pg then
                local conn = pg.DescendantAdded:Connect(function(descendant)
                    if not StreamerMode.Enabled then return end
                    if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
                        task.defer(function()
                            replaceLabel(descendant)
                        end)
                    end
                end)
                table.insert(listenerConns, conn)
            end
        end)
    end

    setupGuiListener()

    local charConn = LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1.0)
        StreamerMode.SweepAll()
    end)
    table.insert(listenerConns, charConn)

    if not isRunning then
        isRunning = true
        task.spawn(function()
            while isRunning do
                if StreamerMode.Enabled then
                    StreamerMode.SweepAll()
                end
                task.wait(1.5)
            end
        end)
    end

    StreamerMode.SweepAll()
end

function StreamerMode.SetEnabled(enabled, newSpoofName, context)
    StreamerMode.Enabled = (enabled == true)
    if newSpoofName and tostring(newSpoofName) ~= "" then
        StreamerMode.SpoofedName = tostring(newSpoofName)
    end

    if _G.OE_PreservedState then
        _G.OE_PreservedState.streamerMode = StreamerMode.Enabled
        _G.OE_PreservedState.spoofedName = StreamerMode.SpoofedName
    end

    StreamerMode.SweepAll()

    if context and context.SendLog then
        context.SendLog(string.format("Streamer Mode (Name Spoof): %s [Nama: %s]",
            StreamerMode.Enabled and "AKTIF" or "NONAKTIF",
            StreamerMode.SpoofedName), "INFO")
    end
end

return StreamerMode
