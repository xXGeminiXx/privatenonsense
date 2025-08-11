-- ▶ Container RNG – Containers Only (dynamic)
-- Scans ReplicatedStorage/Assets/Assets/Containers for options.
-- Defaults to "CamoContainer". Remove everything unrelated to containers.

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage
    :WaitForChild("Modules")
    :WaitForChild("Shared")
    :WaitForChild("Warp")
    :WaitForChild("Index")
    :WaitForChild("Event")
    :WaitForChild("Reliable")

local plr = Players.LocalPlayer

-- Find your plot
local function findPlotForPlayer(playerName)
    local plots = workspace:WaitForChild("Gameplay"):WaitForChild("Plots")
    for _, blot in ipairs(plots:GetChildren()) do
        local label = blot.PlotLogic.PlotNameSign.PlayerInfoSign.PlayerNameSign.MainFrame.NameLabel
        if label.Text:find(playerName .. "'s") then
            return blot
        end
    end
    return nil
end

local plot = findPlotForPlayer(plr.Name)
if not plot then error("No plot found, disabling") return end

local containerHolder = plot:WaitForChild("PlotLogic"):WaitForChild("ContainerHolder")

-- Repo path for available containers
local containerRepo
do
    local assets = ReplicatedStorage:WaitForChild("Assets")
    containerRepo = assets:WaitForChild("Assets"):WaitForChild("Containers")
end

-- Build container list/map from repo
local opcodeByte = 15 -- default prefix used in purchase payload (string.char(opcodeByte))
local containerOptions = {}
local containerMap = {} -- name -> payloadSuffix (char..name)

local function rebuildContainerLists()
    table.clear(containerOptions)
    table.clear(containerMap)

    for _, obj in ipairs(containerRepo:GetChildren()) do
        -- Accept Models/Folders (adjust if your repo uses another class)
        if obj:IsA("Model") or obj:IsA("Folder") then
            table.insert(containerOptions, obj.Name)
            containerMap[obj.Name] = string.char(opcodeByte) .. obj.Name
        end
    end

    table.sort(containerOptions)
end

rebuildContainerLists()

-- UI
local Window = Rayfield:CreateWindow({
    Name = "▶ Container RNG ◀",
    Icon = 0,
    LoadingTitle = "Loading...",
    LoadingSubtitle = "by Agreed 🥵",
    Theme = "DarkBlue",
})

local Container = Window:CreateTab("Container")
Container:CreateSection("Live Containers")

-- Open all placed containers on your plot
Container:CreateToggle({
    Name = "Container Open (All on Plot)",
    CurrentValue = false,
    Callback = function(Value)
        _G._openAll = Value
        while _G._openAll do
            for _, container in ipairs(containerHolder:GetChildren()) do
                -- same open payload you used previously
                remote:FireServer(buffer.fromstring("\28"), buffer.fromstring("\254\1\0\6." .. container.Name))
            end
            task.wait()
        end
    end,
})

-- Selected container (from repo list)
local defaultChoice = "CamoContainer"
if not table.find(containerOptions, defaultChoice) and #containerOptions > 0 then
    defaultChoice = containerOptions[1]
end
local selectedContainer = defaultChoice

Container:CreateDropdown({
    Name = "Buyable Container (from ReplicatedStorage/Assets/Assets/Containers)",
    Options = containerOptions,
    CurrentOption = defaultChoice,
    MultipleOptions = false,
    Callback = function(Option)
        selectedContainer = typeof(Option) == "table" and Option[1] or Option
    end,
})

-- Controls
local buyDelay = 0
local maxContainers = 8
local minMoney = 0

Container:CreateSlider({
    Name = "Max Containers on Plot",
    Range = {1, 8},
    Increment = 1,
    CurrentValue = 8,
    Callback = function(Value)
        maxContainers = Value
    end,
})

Container:CreateInput({
   Name = "Min Money",
   CurrentValue = "0",
   PlaceholderText = "$",
   RemoveTextAfterFocusLost = false,
   Callback = function(Text)
        local v = tonumber(Text)
        if v then minMoney = v else warn("Invalid money input") end
   end,
})

Container:CreateSlider({
    Name = "Buy Delay (seconds)",
    Range = {0, 60},
    Increment = 0.1,
    CurrentValue = 0,
    Callback = function(Value)
        buyDelay = Value
    end,
})

-- Advanced: allow changing the opcodeByte in case game updates it
Container:CreateInput({
   Name = "Opcode Byte (prefix) – default 15",
   CurrentValue = tostring(opcodeByte),
   PlaceholderText = "15",
   RemoveTextAfterFocusLost = false,
   Callback = function(Text)
        local v = tonumber(Text)
        if v and v >= 0 and v <= 255 then
            opcodeByte = v
            -- Rebuild map with new prefix
            for _, name in ipairs(containerOptions) do
                containerMap[name] = string.char(opcodeByte) .. name
            end
        else
            warn("Invalid opcode byte (0-255).")
        end
   end,
})

-- Rescan if devs add/remove containers
Container:CreateButton({
    Name = "Rescan Available Containers",
    Callback = function()
        rebuildContainerLists()
        -- optional: if selected disappears, reset
        if not table.find(containerOptions, selectedContainer) then
            selectedContainer = containerOptions[1]
        end
        Rayfield:Notify({
            Title = "Rescan Complete",
            Content = ("Found %d containers."):format(#containerOptions),
            Duration = 3
        })
    end,
})

-- Buyer
Container:CreateToggle({
    Name = "Auto Buy Selected Container",
    CurrentValue = false,
    Callback = function(Value)
        _G._autoBuy = Value
        while _G._autoBuy do
            local payloadSuffix = containerMap[selectedContainer]
            if not payloadSuffix then
                warn("Invalid container: ", selectedContainer)
                break
            end

            local current = #containerHolder:GetChildren()
            local money = tonumber(plr:FindFirstChild("leaderstats")
                and plr.leaderstats:FindFirstChild("Money")
                and plr.leaderstats.Money.Value) or 0

            if current < maxContainers and money >= minMoney then
                -- purchase
                remote:FireServer(buffer.fromstring("\26"), buffer.fromstring("\254\1\0\6" .. payloadSuffix))
            end

            task.wait(buyDelay)
        end
    end,
})
