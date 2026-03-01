--//====================================================--
--// SERVICES
--//====================================================--
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

--//====================================================--
--// LIBRARY
--//====================================================--
local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/tlredz/Library/refs/heads/main/redz-V5-remake/main.luau"
))()

--//====================================================--
--// CONFIG
--//====================================================--
local Config = {
    RaidMap = "Namex Planet",
    RaidDifficulty = "Nightmare",
    HatchMap = "Namex Planet",

    JoinCooldown = 25
}

--//====================================================--
--// STATE
--//====================================================--
local State = {
    AutoRaid = true,
    AutoHatch = false,
    InRaid = false,

    LastJoinTime = 0,
    RaidLoopRunning = false,
    HatchLoopRunning = false
}

--//====================================================--
--// REFERENCES
--//====================================================--
local RaidsVisual = workspace:WaitForChild("Raids_Visual")

--//====================================================--
--// UTILS
--//====================================================--
local function pressE()
    VirtualInputManager:SendKeyEvent(true, "E", false, game)
    task.wait(0.1)
    VirtualInputManager:SendKeyEvent(false, "E", false, game)
end

local function getParty()
    local parties = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Parties")
    repeat task.wait() until parties:FindFirstChild(player.Name)
    return parties[player.Name]
end

--//====================================================--
--// RAID LOGIC
--//====================================================--
local function getServerMob()
    local folder = workspace:FindFirstChild("Worlds")
    if not folder then return nil end

    folder = folder:FindFirstChild("Targets")
    if not folder then return nil end

    folder = folder:FindFirstChild("Server")
    if not folder then return nil end

    for _, mob in pairs(folder:GetChildren()) do
        local session = mob:GetAttribute("SessionId")
        if session and string.find(session, player.Name) then
            return mob
        end
    end

    return nil
end

local function autoStartRaid()
    if tick() - State.LastJoinTime < Config.JoinCooldown then
        return
    end

    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart")

    hrp.CFrame = workspace:WaitForChild("Raids_Entering")
        :WaitForChild("Pod_03"):GetPivot()

    task.wait(1.5)

    local party = getParty()
    if not party then return end

    ReplicatedStorage.Remotes.Gameplays.RaidsLobbies:FireServer(
        party,
        "Worlds_" .. Config.RaidMap
    )

    task.wait(0.5)

    ReplicatedStorage.Remotes.Gameplays.RaidsLobbies:FireServer(
        party,
        "Diffculty_" .. Config.RaidDifficulty
    )

    task.wait(0.5)

    ReplicatedStorage.Remotes.Systems.RaidsEvent:FireServer(
        Config.RaidMap,
        Config.RaidDifficulty
    )

    State.LastJoinTime = tick()
end

local function claimAndExit()
    local raidObj

    for _, child in pairs(RaidsVisual:GetChildren()) do
        if string.find(child.Name, Config.RaidMap .. "_Server_" .. player.Name) then
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
        task.wait(1)
        pressE()
        task.wait(1)
    end

    if rewards:FindFirstChild("Golds") then
        hrp.CFrame = rewards.Golds:GetPivot()
        task.wait(1)
        pressE()
        task.wait(1)
    end

    if portal then
        hrp.CFrame = portal:GetPivot()
        task.wait(0.5)
        pressE()
    end
end

local function clearRaid()
    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart")

    local timeout = 0
    local mob

    repeat
        task.wait(0.5)
        mob = getServerMob()
        timeout += 0.5

        if timeout > 10 then
            State.InRaid = false
            return
        end
    until mob

    State.InRaid = true

    while mob and mob.Parent and State.AutoRaid do
        hrp.CFrame = mob:GetPivot()
        task.wait(0.01)
        mob = getServerMob()
    end

    if State.AutoRaid then
        task.wait(1)
        claimAndExit()
        State.InRaid = false
    end
end

local function autoRaidLoop()
    if State.RaidLoopRunning then return end
    State.RaidLoopRunning = true

    while State.AutoRaid do
        if State.InRaid then
            clearRaid()
        else
            autoStartRaid()
        end
        task.wait(1)
    end

    State.RaidLoopRunning = false
end

--//====================================================--
--// HATCH LOGIC
--//====================================================--
local function autoHatch()
    if State.HatchLoopRunning then return end
    State.HatchLoopRunning = true

    while State.AutoHatch do
        ReplicatedStorage.Remotes.Summoners.RemoteEvent:FireServer(
            workspace:WaitForChild("Summoners"):WaitForChild(Config.HatchMap),
            "Multi"
        )
        task.wait(0.1)
    end

    State.HatchLoopRunning = false
end

--//====================================================--
--// UI
--//====================================================--
local Window = Library:MakeWindow({
    Title = "Aqua Hub: Anime Card Realm",
    SubTitle = "by aquane1075",
    ScriptFolder = "AquaHubConfigs",
})

local Challenge = Window:MakeTab({ "Challenge", "sword" })
Challenge:AddSection("Raid")

Challenge:AddDropdown({
    Name = "Select Raid Map",
    Options = {"Namex Planet","Colosseum Kingdom","Demon Forest","Dungeons Town"},
    Default = Config.RaidMap,
    Flag = "Raid_Map",
    Callback = function(v)
        Config.RaidMap = v
    end,
})

Challenge:AddDropdown({
    Name = "Select Raid Difficulty",
    Options = {"Easy","Medium","Hard","Nightmare"},
    Default = Config.RaidDifficulty,
    Flag = "Raid_Difficulty",
    Callback = function(v)
        Config.RaidDifficulty = v
    end,
})

Challenge:AddToggle({
    Name = "Auto Raid",
    Default = false,
    Flag = "Auto_Raid",
    Callback = function(v)
        State.AutoRaid = v
        if v then autoRaidLoop() end
    end,
})

local Hatch = Window:MakeTab({ "Hatch", "egg" })

Hatch:AddDropdown({
    Name = "Select Hatch Map",
    Options = {"Namex Planet","Colosseum Kingdom","Demon Forest","Dungeons Town"},
    Default = Config.HatchMap,
    Flag = "Hatch_Map",
    Callback = function(v)
        Config.HatchMap = v
    end,
})

Hatch:AddToggle({
    Name = "Auto Hatch",
    Default = false,
    Flag = "Auto_Hatch",
    Callback = function(v)
        State.AutoHatch = v
        if v then autoHatch() end
    end,
})

local UI = Window:MakeTab({ "Ui", "sword" })

local function toggleGui(name, value)
    local gui = player.PlayerGui:FindFirstChild(name)
    if gui then
        gui.Enabled = value
    end
end

UI:AddToggle({
    Name = "Open Trait Ui",
    Callback = function(v)
        toggleGui("Traits", v)
    end,
})

UI:AddToggle({
    Name = "Open Vending Machine Ui",
    Callback = function(v)
        toggleGui("SpinWheels", v)
    end,
})

UI:AddToggle({
    Name = "Open Talent Ui",
    Callback = function(v)
        toggleGui("Talents", v)
    end,
})
