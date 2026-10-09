--[[
    OneEight External Hub - Streamer Mode (Name Spoofing Engine v2.0)
    Fungsi:
    - Menyamarkan username dan DisplayName akun menjadi nama samaran (default: "Warga_Sipil" atau custom)
    - Meliputi: Overhead Nametag karakter, Minimap radar dot, Menu HP CDID (BCA, E-Toll, KTP, Welcome Screen), CoreGui PlayerList, dan Dialog UI
    - Beroperasi 100% pada layer visual lokal sehingga aman dan tidak merusak koneksi remote server
    - Pemulihan total (Restore) kembali ke nama asli akun saat dimatikan tanpa tertinggal "Warga_Sipil"
--]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local StreamerMode = {}
StreamerMode.Enabled = true
StreamerMode.SpoofedName = "Warga_Sipil"
StreamerMode.PreviousSpoofName = nil
StreamerMode.RealName = (LocalPlayer and LocalPlayer.Name) or ""
StreamerMode.RealDisplayName = (LocalPlayer and LocalPlayer.DisplayName) or StreamerMode.RealName

local Context = nil
local isRunning = false
local listenerConns = {}
local hookedLabels = {}

local function sanitizeText(text)
    if not text or text == "" then return text end
    local real = StreamerMode.RealName
    local disp = StreamerMode.RealDisplayName
    local spoof = StreamerMode.SpoofedName

    local res = text
    -- 1. Ganti nama asli
    if real and real ~= "" then
        res = res:gsub(real, spoof)
        if res:find(real:lower(), 1, true) then
            res = res:gsub(real:lower(), spoof)
        end
    end
    -- 2. Ganti display name asli jika berbeda
    if disp and disp ~= "" and disp ~= real then
        res = res:gsub(disp, spoof)
    end
    -- 3. Ganti "Warga_Sipil" jika nama samaran saat ini berbeda dengan "Warga_Sipil"
    if spoof ~= "Warga_Sipil" then
        res = res:gsub("Warga_Sipil", spoof)
    end
    -- 4. Ganti nama spoof sebelumnya jika ada
    if StreamerMode.PreviousSpoofName and StreamerMode.PreviousSpoofName ~= "" and StreamerMode.PreviousSpoofName ~= spoof then
        res = res:gsub(StreamerMode.PreviousSpoofName, spoof)
    end

    return res
end

local function restoreLabel(v)
    if not v or not (v:IsA("TextLabel") or v:IsA("TextButton") or v:IsA("TextBox")) then return end
    pcall(function()
        local realName = StreamerMode.RealDisplayName or StreamerMode.RealName
        local origText = v:GetAttribute("OE_OriginalText")
        
        if origText and origText ~= "" and origText ~= "Warga_Sipil" and origText ~= StreamerMode.SpoofedName and origText ~= StreamerMode.PreviousSpoofName then
            v.Text = origText
            v:SetAttribute("OE_OriginalText", nil)
        else
            -- Jika origText tidak ada atau sudah pernah tercemar "Warga_Sipil":
            local current = v.Text
            if current and current ~= "" then
                local restored = current
                local hasSpoof = false
                if StreamerMode.SpoofedName and StreamerMode.SpoofedName ~= "" and restored:find(StreamerMode.SpoofedName, 1, true) then
                    restored = restored:gsub(StreamerMode.SpoofedName, realName)
                    hasSpoof = true
                end
                if StreamerMode.PreviousSpoofName and StreamerMode.PreviousSpoofName ~= "" and restored:find(StreamerMode.PreviousSpoofName, 1, true) then
                    restored = restored:gsub(StreamerMode.PreviousSpoofName, realName)
                    hasSpoof = true
                end
                if restored:find("Warga_Sipil", 1, true) then
                    restored = restored:gsub("Warga_Sipil", realName)
                    hasSpoof = true
                end
                if hasSpoof then
                    v.Text = restored
                end
                v:SetAttribute("OE_OriginalText", nil)
            end
        end
    end)
end

local function replaceLabel(v)
    if not v or not (v:IsA("TextLabel") or v:IsA("TextButton") or v:IsA("TextBox")) then return end
    pcall(function()
        local current = v.Text
        if not current or current == "" then return end

        if StreamerMode.Enabled then
            local real = StreamerMode.RealName
            local disp = StreamerMode.RealDisplayName
            local spoof = StreamerMode.SpoofedName
            local prevSpoof = StreamerMode.PreviousSpoofName

            local hasReal = (real and real ~= "" and (current:find(real, 1, true) or current:lower():find(real:lower(), 1, true)))
            local hasDisp = (disp and disp ~= "" and current:find(disp, 1, true))
            local hasOldSpoof = (spoof ~= "Warga_Sipil" and current:find("Warga_Sipil", 1, true)) or 
                                (prevSpoof and prevSpoof ~= "" and prevSpoof ~= spoof and current:find(prevSpoof, 1, true))

            if hasReal or hasDisp or hasOldSpoof then
                -- Simpan teks asli hanya jika belum ter-spoof
                local orig = v:GetAttribute("OE_OriginalText")
                if not orig then
                    if not hasOldSpoof then
                        v:SetAttribute("OE_OriginalText", current)
                    else
                        v:SetAttribute("OE_OriginalText", disp or real)
                    end
                end
                v.Text = sanitizeText(current)
            end
        else
            restoreLabel(v)
        end
    end)
end

local function attachLabelWatcher(v)
    if not v or not (v:IsA("TextLabel") or v:IsA("TextButton") or v:IsA("TextBox")) then return end
    if hookedLabels[v] then return end
    hookedLabels[v] = true

    local conn = v:GetPropertyChangedSignal("Text"):Connect(function()
        if StreamerMode.Enabled then
            task.defer(function()
                replaceLabel(v)
            end)
        end
    end)
    table.insert(listenerConns, conn)
end

function StreamerMode.SweepAll()
    pcall(function()
        if not StreamerMode.Enabled then
            -- RESTORE SEMUA ELEMEN KE NAMA ASLI
            if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
                for _, v in ipairs(LocalPlayer.PlayerGui:GetDescendants()) do
                    if v:IsA("TextLabel") or v:IsA("TextButton") or v:IsA("TextBox") then
                        restoreLabel(v)
                    end
                end
            end

            -- Restore overhead
            local lives = Workspace:FindFirstChild("Lives")
            local charLives = lives and (lives:FindFirstChild(StreamerMode.RealName) or lives:FindFirstChild(StreamerMode.SpoofedName))
            if charLives then
                local head = charLives:FindFirstChild("Head")
                local billboard = head and head:FindFirstChild("PlayerBillboard")
                local frame = billboard and billboard:FindFirstChild("Frame")
                local pName = frame and frame:FindFirstChild("PlayerName")
                if pName and pName:IsA("TextLabel") then
                    restoreLabel(pName)
                end
            end

            local char = LocalPlayer.Character
            if char then
                local head = char:FindFirstChild("Head")
                local billboard = head and head:FindFirstChild("PlayerBillboard")
                local frame = billboard and billboard:FindFirstChild("Frame")
                local pName = frame and frame:FindFirstChild("PlayerName")
                if pName and pName:IsA("TextLabel") then
                    restoreLabel(pName)
                end
            end
            return
        end

        -- KETIKA AKTIF: GANTI KE SPOOFED NAME
        -- 1. Sweep PlayerGui
        if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
            for _, v in ipairs(LocalPlayer.PlayerGui:GetDescendants()) do
                if v:IsA("TextLabel") or v:IsA("TextButton") or v:IsA("TextBox") then
                    replaceLabel(v)
                    attachLabelWatcher(v)
                end
            end
        end

        -- 2. Sweep Overhead Head Nametag in Workspace.Lives
        local lives = Workspace:FindFirstChild("Lives")
        local charLives = lives and (lives:FindFirstChild(StreamerMode.RealName) or lives:FindFirstChild(StreamerMode.SpoofedName))
        if charLives then
            local head = charLives:FindFirstChild("Head")
            local billboard = head and head:FindFirstChild("PlayerBillboard")
            local frame = billboard and billboard:FindFirstChild("Frame")
            local pName = frame and frame:FindFirstChild("PlayerName")
            if pName and pName:IsA("TextLabel") then
                replaceLabel(pName)
                attachLabelWatcher(pName)
            end
        end

        -- 3. Sweep Character Head if in Workspace direct
        local char = LocalPlayer.Character
        if char then
            local head = char:FindFirstChild("Head")
            local billboard = head and head:FindFirstChild("PlayerBillboard")
            local frame = billboard and billboard:FindFirstChild("Frame")
            local pName = frame and frame:FindFirstChild("PlayerName")
            if pName and pName:IsA("TextLabel") then
                replaceLabel(pName)
                attachLabelWatcher(pName)
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
        StreamerMode.Enabled = (_G.OE_PreservedState.streamerMode == true)
    end
    if _G.OE_PreservedState and _G.OE_PreservedState.spoofedName then
        StreamerMode.SpoofedName = tostring(_G.OE_PreservedState.spoofedName)
    end

    for _, conn in ipairs(listenerConns) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(listenerConns)
    table.clear(hookedLabels)

    local function setupGuiListener()
        pcall(function()
            local pg = LocalPlayer:WaitForChild("PlayerGui", 5)
            if pg then
                local conn = pg.DescendantAdded:Connect(function(descendant)
                    if not StreamerMode.Enabled then return end
                    if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
                        task.defer(function()
                            replaceLabel(descendant)
                            attachLabelWatcher(descendant)
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
    local wasEnabled = StreamerMode.Enabled
    StreamerMode.Enabled = (enabled == true)

    if newSpoofName and tostring(newSpoofName) ~= "" and tostring(newSpoofName) ~= StreamerMode.SpoofedName then
        StreamerMode.PreviousSpoofName = StreamerMode.SpoofedName
        StreamerMode.SpoofedName = tostring(newSpoofName)
    end

    if _G.OE_PreservedState then
        _G.OE_PreservedState.streamerMode = StreamerMode.Enabled
        _G.OE_PreservedState.spoofedName = StreamerMode.SpoofedName
    end

    StreamerMode.SweepAll()

    if context and context.SendLog then
        context.SendLog(string.format("Streamer Mode (Name Spoof): %s [Nama: %s]",
            StreamerMode.Enabled and "AKTIF" or "NONAKTIF (Kembali ke Nama Asli)",
            StreamerMode.Enabled and StreamerMode.SpoofedName or (StreamerMode.RealDisplayName or StreamerMode.RealName)), "INFO")
    end
end

return StreamerMode
