-- ==============================
-- SERVICES
-- ==============================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/tlredz/Library/refs/heads/main/redz-V5-remake/main.luau"
))()

-- ==============================
-- SETTINGS
-- ==============================
local select_map = "Namex Planet"
local select_difficulty = "Nightmare"

local autoraid = true
local JOIN_COOLDOWN = 25
local lastJoinTime = 0

local RaidsVisual = workspace:WaitForChild("Raids_Visual")

local inRaid = false
local CHECK_DELAY = 2

-- ==============================
-- RAID STATE CHECK
-- ==============================
local function is_my_raid_object(obj)
    if not obj then return false end
    return string.find(obj.Name, player.Name) ~= nil
end

local function updateRaidState()
    for _, child in pairs(RaidsVisual:GetChildren()) do
        if is_my_raid_object(child) then
            inRaid = true
            return
        end
    end

    task.wait(CHECK_DELAY)

    for _, child in pairs(RaidsVisual:GetChildren()) do
        if is_my_raid_object(child) then
            inRaid = true
            return
        end
    end

    inRaid = false
end

-- ==============================
-- GET PARTY
-- ==============================
local function get_party()
    local parties = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Parties")
    repeat task.wait() until parties:FindFirstChild(player.Name)
    return parties[player.Name]
end

-- ==============================
-- START RAID
-- ==============================
local function auto_start_raid()
    if tick() - lastJoinTime < JOIN_COOLDOWN then
        return
    end

    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart")

    local pod = workspace:WaitForChild("Raids_Entering"):WaitForChild("Pod_03")
    hrp.CFrame = pod:GetPivot()

    task.wait(1.5)

    local partyFolder = get_party()
    if not partyFolder then return end

    ReplicatedStorage.Remotes.Gameplays.RaidsLobbies:FireServer(
        partyFolder,
        "Worlds_" .. select_map
    )

    task.wait(0.5)

    ReplicatedStorage.Remotes.Gameplays.RaidsLobbies:FireServer(
        partyFolder,
        "Diffculty_" .. select_difficulty
    )

    task.wait(0.5)

    ReplicatedStorage.Remotes.Systems.RaidsEvent:FireServer(
        select_map,
        select_difficulty
    )

    lastJoinTime = tick()
end

-- ==============================
-- GET SERVER MOB
-- ==============================
local function get_server_mob()
    local serverFolder = workspace:FindFirstChild("Worlds")
    if not serverFolder then return nil end

    serverFolder = serverFolder:FindFirstChild("Targets")
    if not serverFolder then return nil end

    serverFolder = serverFolder:FindFirstChild("Server")
    if not serverFolder then return nil end

    for _, mob in pairs(serverFolder:GetChildren()) do
        local session = mob:GetAttribute("SessionId")
        if session and string.find(session, player.Name) then
            return mob
        end
    end

    return nil
end

-- ==============================
-- INPUT
-- ==============================
local function press_E()
    VirtualInputManager:SendKeyEvent(true, "E", false, game)
    task.wait(0.1)
    VirtualInputManager:SendKeyEvent(false, "E", false, game)
end

-- ==============================
-- CLAIM + EXIT
-- ==============================
local function claim_and_exit()
    local raidObj = nil

    for _, child in pairs(RaidsVisual:GetChildren()) do
        if string.find(child.Name, select_map .. "_Server_" .. player.Name) then
            raidObj = child
            break
        end
    end

    if not raidObj then return end

    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart")

    local rewards = raidObj.Configs.Others.Rewards
    local portal = raidObj.Configs.Others.Portal.Travel

    if rewards:FindFirstChild("Special") then
        hrp.CFrame = rewards.Special:GetPivot()
        task.wait(0.5)
        press_E()
        task.wait(0.5)
    end

    if rewards:FindFirstChild("Golds") then
        hrp.CFrame = rewards.Golds:GetPivot()
        task.wait(0.5)
        press_E()
        task.wait(0.5)
    end

    if portal then
        hrp.CFrame = portal:GetPivot()
        task.wait(0.5)
        press_E()
    end
end

-- ==============================
-- CLEAR RAID
-- ==============================
local function clear_raid()
    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart")

    local timeout = 0
    local mob

    repeat
        task.wait(0.5)
        mob = get_server_mob()
        timeout += 0.5

        if timeout > 10 then
            inRaid = false
            return
        end
    until mob

    inRaid = true

    while mob and mob.Parent and autoraid do
        hrp.CFrame = mob:GetPivot()
        task.wait(0.01)
        mob = get_server_mob()
    end

    if autoraid then
        task.wait(1)
        claim_and_exit()
        inRaid = false
    end
end

-- ==============================
-- AUTO RAID LOOP
-- ==============================
local loop_running = false

function auto_raid_loop()
    if loop_running then return end
    loop_running = true

    while autoraid do
        if inRaid then
            clear_raid()
        else
            auto_start_raid()
        end

        task.wait(1)
    end

    loop_running = false
end

-- ==============================
-- HATCH
-- ==============================
local select_hatch_map = "Namex Planet"
local autohatch = false
local hatch_loop_running = false

function auto_hatch()
    if hatch_loop_running then return end
    hatch_loop_running = true

    while autohatch do
        local args = {
            workspace:WaitForChild("Summoners"):WaitForChild(select_hatch_map),
            "Multi"
        }

        ReplicatedStorage.Remotes.Summoners.RemoteEvent:FireServer(unpack(args))
        task.wait(0.1)
    end

    hatch_loop_running = false
end

-- ==============================
-- UI
-- ==============================
local Window = Library:MakeWindow({
    Title = "Aqua Hub: Anime Card Realm",
    SubTitle = "by aquane1075",
    ScriptFolder = "AquaHubConfigs",
})

local Minimizer = Window:NewMinimizer({
    KeyCode = Enum.KeyCode.LeftControl,
})

Minimizer:CreateMobileMinimizer({
    Image = "rbxassetid://114289527320220",
    BackgroundColor3 = Color3.fromRGB(32, 96, 169),
})

-- ==============================
-- RAID TAB
-- ==============================
local Challenge = Window:MakeTab({ "Challenge", "sword" })

Challenge:AddSection("Raid")

Challenge:AddDropdown({
    Name = "Select Raid Map",
    Options = {"Namex Planet","Colosseum Kingdom","Demon Forest","Dungeons Town"},
    Default = select_map,
    Flag = "Raid_Map",
    Callback = function(value)
        select_map = value
    end,
})

Challenge:AddDropdown({
    Name = "Select Raid Difficulty",
    Options = {"Easy","Medium","Hard","Nightmare"},
    Default = select_difficulty,
    Flag = "Raid_Difficulty",
    Callback = function(value)
        select_difficulty = value
    end,
})

Challenge:AddToggle({
    Name = "Auto Raid",
    Default = false,
    Flag = "Auto_Raid",
    Callback = function(value)
        autoraid = value
        if autoraid then
            auto_raid_loop()
        end
    end,
})

-- ==============================
-- HATCH TAB
-- ==============================
local Hatch = Window:MakeTab({ "Hatch", "egg" })

Hatch:AddDropdown({
    Name = "Select Hatch Map",
    Options = {"Namex Planet","Colosseum Kingdom","Demon Forest","Dungeons Town"},
    Default = select_hatch_map,
    Flag = "Hatch_Map",
    Callback = function(value)
        select_hatch_map = value
    end,
})

Hatch:AddToggle({
    Name = "Auto Hatch",
    Default = false,
    Flag = "Auto_Hatch",
    Callback = function(value)
        autohatch = value
        if autohatch then
            auto_hatch()
        end
    end,
})

-- ==============================
-- UI TAB
-- ==============================
local UI = Window:MakeTab({ "Ui", "sword" })

UI:AddToggle({
    Name = "Open Trait Ui",
    Default = false,
    Callback = function(value)
        local traitsGui = player.PlayerGui:FindFirstChild("Traits")
        if traitsGui then
            traitsGui.Enabled = value
        end
    end,
})

UI:AddToggle({
    Name = "Open Vending Machine Ui",
    Default = false,
    Callback = function(value)
        local vendingGui = player.PlayerGui:FindFirstChild("SpinWheels")
        if vendingGui then
            vendingGui.Enabled = value
        end
    end,
})

UI:AddToggle({
    Name = "Open Talent Ui",
    Default = false,
    Callback = function(value)
        local talentGui = player.PlayerGui:FindFirstChild("Talents")
        if talentGui then
            talentGui.Enabled = value
        end
    end,
})
