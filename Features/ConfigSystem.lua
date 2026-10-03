-- ==================================================
-- YOKUDO HUB | FEATURE | Config System (v2 FULL)
-- ✅ Registry (push model): tabs/features Register{Get,Set}
-- ✅ Real Save/Load via YOKUDO-SAE/yokudo.json
-- ✅ Deep-merge defaults (forward compatible)
-- ✅ Deferred apply for character-moving features
-- ✅ Reset + UI refresh hooks
-- ==================================================

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local CONFIG_FOLDER = "YOKUDO-SAE"
local CONFIG_FILE = CONFIG_FOLDER .. "/yokudo.json"
local CONFIG_VERSION = 1

-- ==================================================
-- DEFAULT CONFIG
-- ==================================================
local DefaultConfig = {
    Version = CONFIG_VERSION,
    Farming = { Enabled = false, Rarities = { "Divine", "Eternal", "Secret", "Mythic", "Legendary" } },
    AutoFarming = { CheckEgg = false, GetEgg = false },
    Event = { Enabled = false },
    Combat = { AutoEquip = false, AutoHit = false },
    Setting = { AntiTrap = false, ManualFastClick = false, AntiAFK = false },
    CollectEggNew = { DropEgg = false, AntiGuard = false },
    ESP = { Name = false, Distance = false, Box = false },
    MapSettings = { Waits = {} },
    AutoTreadmill = { Enabled = true, Priority = { "egg", "boss" } },
}

-- ==================================================
-- REGISTRY
-- ==================================================
local Registry = {}

-- ==================================================
-- HELPERS
-- ==================================================
local function DeepCopy(Value)
    if type(Value) ~= "table" then return Value end
    local Out = {}
    for K, V in pairs(Value) do
        Out[K] = DeepCopy(V)
    end
    return Out
end

local function DeepMerge(Base, Override)
    if type(Override) ~= "table" then return Base end
    for K, V in pairs(Override) do
        if type(V) == "table" and type(Base[K]) == "table" then
            DeepMerge(Base[K], V)
        else
            Base[K] = V
        end
    end
    return Base
end

local function EnsureFolder()
    pcall(function()
        if not isfolder(CONFIG_FOLDER) then
            makefolder(CONFIG_FOLDER)
        end
    end)
end

local function FileExists(Path)
    local Exists = false
    pcall(function()
        Exists = isfile(Path)
    end)
    return Exists
end

-- ==================================================
-- REFRESH HOOKS
-- ==================================================
local RefreshHooks = {
    "YOKUDO_RefreshFarmingUI",
    "YOKUDO_RefreshAutoFarmingUI",
    "YOKUDO_RefreshEventUI",
    "YOKUDO_RefreshCombatUI",
    "YOKUDO_RefreshSettingUI",
    "YOKUDO_RefreshCollectEggNewUI",
    "YOKUDO_RefreshMapSettingsUI",
    "YOKUDO_RefreshESPUI",
    "YOKUDO_RefreshAutoTreadmillUI",
}

local function RefreshAll()
    for _, Key in ipairs(RefreshHooks) do
        local Fn = _G[Key]
        if type(Fn) == "function" then
            pcall(Fn)
        end
    end
end

-- ==================================================
-- BUILD CONFIG FROM REGISTRY
-- ==================================================
local function BuildConfig()
    local Config = DeepCopy(DefaultConfig)
    Config.Version = CONFIG_VERSION

    for Key, Entry in pairs(Registry) do
        if type(Entry.Get) == "function" then
            local OK, Value = pcall(Entry.Get)
            if OK and Value ~= nil then
                Config[Key] = Value
            end
        end
    end

    return Config
end

-- ==================================================
-- APPLY CONFIG
-- ==================================================
local function ApplyConfig(Config, DeferredOnly)
    for Key, Entry in pairs(Registry) do
        if type(Entry.Set) == "function" then
            local IsDeferred = Entry.Deferred == true
            if DeferredOnly == nil or DeferredOnly == IsDeferred then
                if Config[Key] ~= nil then
                    pcall(Entry.Set, Config[Key])
                end
            end
        end
    end
end

-- ==================================================
-- LOAD / SAVE
-- ==================================================
local function LoadConfig()
    EnsureFolder()

    local Config = DeepCopy(DefaultConfig)

    if FileExists(CONFIG_FILE) then
        local ReadOK, Raw = pcall(function()
            return readfile(CONFIG_FILE)
        end)

        if ReadOK and Raw and Raw ~= "" then
            local DecodeOK, Decoded = pcall(function()
                return HttpService:JSONDecode(Raw)
            end)

            if DecodeOK and type(Decoded) == "table" then
                DeepMerge(Config, Decoded)
            else
                warn("[YOKUDO] Config decode failed — using defaults")
            end
        end
    end

    Config.Version = CONFIG_VERSION
    return Config
end

local function SaveConfig(Config)
    EnsureFolder()

    local EncodeOK, Encoded = pcall(function()
        return HttpService:JSONEncode(Config or BuildConfig())
    end)

    if not EncodeOK or not Encoded then
        warn("[YOKUDO] Failed to encode config")
        return false
    end

    local WriteOK = pcall(function()
        writefile(CONFIG_FILE, Encoded)
    end)

    if WriteOK then
        print("[YOKUDO] Config Saved →", CONFIG_FILE)
        return true
    end

    warn("[YOKUDO] Failed to write config")
    return false
end

local SaveQueued = false
local function ScheduleSave()
    if SaveQueued then return end
    SaveQueued = true
    task.delay(0.5, function()
        SaveQueued = false
        SaveConfig(BuildConfig())
    end)
end

-- ==================================================
-- DEFERRED APPLY (after character ready)
-- ==================================================
local function ApplyDeferredWhenReady(Config)
    task.spawn(function()
        local Player = Players.LocalPlayer
        if Player then
            if not Player.Character then
                pcall(function() Player.CharacterAdded:Wait() end)
            end
            task.wait(2.5)
        end
        ApplyConfig(Config, true)
        RefreshAll()
        print("[YOKUDO] Deferred config applied")
    end)
end

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_ConfigSystem = {
    Folder = CONFIG_FOLDER,
    File = CONFIG_FILE,
    Default = DefaultConfig,

    Register = function(Key, Entry)
        if type(Key) ~= "string" or type(Entry) ~= "table" then return end
        Registry[Key] = {
            Get = Entry.Get,
            Set = Entry.Set,
            Deferred = Entry.Deferred == true,
        }
    end,

    Get = function()
        return BuildConfig()
    end,

    Save = function()
        ScheduleSave()
        return true
    end,

    SaveNow = function()
        return SaveConfig(BuildConfig())
    end,

    Load = function()
        local Config = LoadConfig()
        ApplyConfig(Config, false)
        RefreshAll()
        ApplyDeferredWhenReady(Config)
        return Config
    end,

    Reset = function()
        local Config = DeepCopy(DefaultConfig)
        ApplyConfig(Config, false)
        ApplyConfig(Config, true)
        SaveConfig(Config)
        RefreshAll()
        print("[YOKUDO] Config Reset to Default")
        return Config
    end,
}

print("✅ ConfigSystem Loaded (v2 FULL — Registry + Save/Load)")
