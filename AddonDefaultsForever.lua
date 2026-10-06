local addonName, ns = ...

-- Toggle debug chat messages.
local DEBUG = true

local function DebugPrint(fmt, ...)
    if not DEBUG then return end
    print(string.format("|cff00ff00%s|r: %s", addonName, string.format(fmt, ...)))
end

-- Per-addon config:
--  addon    : exact addon folder name (case-insensitive)
--  db       : global saved variable name
--  path     : optional sub-path inside the DB
--             - omit or ""       : apply to the root table
--             - "profiles"       : apply to every profile in an AceDB saved variable
--             - "profile" etc.   : apply to a direct sub-key
--  defaults : key/value pairs to apply
--  mode     : "default" = only if key is nil
--             "force"   = overwrite existing value
--  poll     : if true, re-apply every 5 seconds while addon is loaded
ns.config = {
    {
        addon = "Buffet",
        db = "BuffetDB",
        defaults = {
            hearthstone = false,
        },
        mode = "force",
        poll = false,
    },
    {
        addon = "RXPGuides",
        db = "RXPSettings",
        path = "profiles",
        defaults = {
            enableLevelUpAnnounceSolo = false,
            enableLevelUpAnnounceGroup = false,
            enableLevelUpAnnounceGuild = false,
            enableCompleteStepAnnouncements = false,
            enableCollectStepAnnouncements = false,
            enableFlyStepAnnouncements = false,
            alwaysSendBranded = false,
            checkVersions = false,
            shareQuests = false,
            shareActiveSteps = false,
        },
        mode = "force",
        poll = true,
    },
}

local pending = {}
local polling = {}

local function IsAddOnLoadedCompat(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(name)
    end
    return IsAddOnLoaded(name)
end

local function ResolvePath(root, path)
    if not path or path == "" then
        return root
    end

    local current = root
    for segment in path:gmatch("[^%.]+") do
        if type(current) ~= "table" then
            return nil
        end
        current = current[segment]
    end
    return current
end

local function GatherTargets(db, path)
    local targets = {}

    if path == "profiles" then
        if type(db.profiles) == "table" then
            for name, profile in pairs(db.profiles) do
                if type(profile) == "table" then
                    table.insert(targets, profile)
                end
            end
        end
    else
        local target = ResolvePath(db, path)
        if type(target) == "table" then
            table.insert(targets, target)
        end
    end

    return targets
end

local function ApplySavedVariables(config)
    local db = _G[config.db]
    if type(db) ~= "table" then
        DebugPrint("DB not ready: %s", config.db)
        return false
    end

    local targets = GatherTargets(db, config.path)
    if #targets == 0 then
        DebugPrint("No targets found: %s%s", config.db,
            config.path and ("." .. config.path) or "")
        return false
    end

    local force = config.mode == "force"
    local pathLabel = config.path or "<root>"

    for _, target in ipairs(targets) do
        for key, value in pairs(config.defaults) do
            local shouldSet = force or target[key] == nil
            if shouldSet then
                target[key] = value
                DebugPrint("Set %s.%s.%s = %s (mode: %s)",
                    config.db,
                    pathLabel,
                    key,
                    tostring(value),
                    config.mode)
            end
        end
    end

    return true
end

local function Apply(config)
    if config.apply then
        return config.apply(config)
    elseif config.db and config.defaults then
        return ApplySavedVariables(config)
    end
    return false
end

local function QueueForAddon(addonName, config, targetTable)
    local key = addonName:lower()
    targetTable[key] = targetTable[key] or {}
    table.insert(targetTable[key], config)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(self, event, loadedAddon)
    if event == "ADDON_LOADED" then
        local configs = pending[loadedAddon:lower()]
        if not configs then return end

        DebugPrint("ADDON_LOADED: %s", loadedAddon)

        for _, config in ipairs(configs) do
            Apply(config)
            if config.poll then
                QueueForAddon(config.addon, config, polling)
            end
        end

        pending[loadedAddon:lower()] = nil
    elseif event == "PLAYER_LOGIN" then
        DebugPrint("PLAYER_LOGIN")

        for addon, configs in pairs(pending) do
            if IsAddOnLoadedCompat(addon) then
                for _, config in ipairs(configs) do
                    Apply(config)
                    if config.poll then
                        QueueForAddon(config.addon, config, polling)
                    end
                end
                pending[addon] = nil
            end
        end
    end
end)

for _, config in ipairs(ns.config) do
    QueueForAddon(config.addon, config, pending)

    if IsAddOnLoadedCompat(config.addon) then
        DebugPrint("Already loaded at startup: %s", config.addon)
        Apply(config)
        if config.poll then
            QueueForAddon(config.addon, config, polling)
        end
    end
end

pending[addonName:lower()] = nil

C_Timer.NewTicker(5, function()
    for addon, configs in pairs(polling) do
        if IsAddOnLoadedCompat(addon) then
            for _, config in ipairs(configs) do
                Apply(config)
            end
        end
    end
end)
