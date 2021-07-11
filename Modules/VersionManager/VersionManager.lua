local _, CLM = ...

local LOG = CLM.LOG
local MODULES = CLM.MODULES
local CONSTANTS = CLM.CONSTANTS
local MODELS = CLM.MODELS
local UTILS = CLM.UTILS

local Comms = MODULES.Comms
local LedgerManager = MODULES.LedgerManager
local ProfileManager = MODULES.ProfileManager
local EventManager = MODULES.EventManager

local ColorCodeText = UTILS.ColorCodeText

local VersionCommStructure = MODELS.VersionCommStructure
local VersionCommAnnounceVersion = MODELS.VersionCommAnnounceVersion

local VERSION_COMM_PREFIX = "Version001"

local function stringifyVersion(version)
    return string.format("v%s.%s.%s", version.major or 0, version.minor or 0, version.patch or 0)
end

local VersionManager = {}

local function AnnounceVersion()
    LOG:Trace("VersionManager:AnnounceVersion()")
    local version = CLM.CORE:GetVersion()
    local message = VersionCommStructure:New(
        CONSTANTS.VERSIONNING_COMM.TYPE.ANNOUNCE_VERSION,
        VersionCommAnnounceVersion:New(version.major, version.minor, version.patch, version.changeset))
    Comms:Send(VERSION_COMM_PREFIX, message, CONSTANTS.COMMS.DISTRIBUTION.GUILD)
end

-- local function RequestVersion()
--     LOG:Trace("VersionManager:RequestVersion()")
--     local message = VersionCommStructure:New(CONSTANTS.VERSIONNING_COMM.TYPE.REQUEST_VERSION, {})
--     Comms:Send(VERSION_COMM_PREFIX, message, CONSTANTS.COMMS.DISTRIBUTION.GUILD)
-- end

local function OutOfDate(self, version, disable)
    LOG:Trace("VersionManager:OutOfDate()")
    local currentTime = GetServerTime()
    if disable then
        if currentTime - self._lastDisplayedMessageD > 300 then
            LOG:Message("|cffcc0000Your Classic Loot Manager is significantly out of date.|r AddOn communication has been disabled. Version %s is available. Please update as soon as possible.", ColorCodeText(stringifyVersion(version), "00cc00"))
            self._lastDisplayedMessageD = currentTime
        end
        LedgerManager:Cutoff()
        Comms:Disable()
    else
        if currentTime - self._lastDisplayedMessage > 300 then
            LOG:Message("New version %s of Classic Loot Manager is available. For best experience please update the AddOn.", ColorCodeText(stringifyVersion(version), "00cc00"))
            self._lastDisplayedMessage = currentTime
        end
    end
end

local function SetProfileVersion(name, version)
    local profile = ProfileManager:GetProfileByName(name)
    if profile then
        profile:SetVersion(version.major, version.minor, version.patch, version.changeset)
    end
end

local function StoreProfileVersion(self, name, version)
    self.db[name] = version
end

local function HandleIncomingMessage(self, message, distribution, sender)
    LOG:Trace("VersionManager:HandleIncomingMessage()")
    local mtype = message:Type() or 0
    if self.handlers[mtype] then
        self.handlers[mtype](self, message:Data(), sender)
    end
end

local function HandleAnnounceVersion(self, data, sender)
    LOG:Trace("VersionManager:HandleAnnounceVersion()")
    local currentVersion = CLM.CORE:GetVersion()
    local receivedVersion = data:Version()

    -- Check if we have older version
    if currentVersion.major < receivedVersion.major then
        OutOfDate(self, receivedVersion, true)
    else -- equal majors
        if currentVersion.minor < receivedVersion.minor then
            -- older minor
            OutOfDate(self, receivedVersion, false)
        elseif currentVersion.patch < receivedVersion.patch then
            if receivedVersion.changeset == "" then -- changeset = unofficial or beta. We don't care about that
                OutOfDate(self, receivedVersion, false)
            else
                LOG:Debug("Received version %s-%s", stringifyVersion(receivedVersion), receivedVersion.changeset)
            end
        end
    end

    SetProfileVersion(sender, receivedVersion)
    StoreProfileVersion(self, sender, receivedVersion)
end

-- local function HandleRequestVersion(self, data, sender)
--     LOG:Trace("VersionManager:HandleRequestVersion()")
--     local currentTime = GetServerTime()
--     if (currentTime - self._lastRequestResponse) > 30  then
--         AnnounceVersion(self)
--         self._lastRequestResponse = currentTime
--     end
-- end

local function RestoreVersions(self)
    for name, version in pairs(self.db) do
        SetProfileVersion(name, version)
    end
end

function VersionManager:Initialize()
    LOG:Trace("VersionManager:Initialize()")
    self._initialized = false

    self._lastRequestResponse = 0
    self._lastDisplayedMessage = 0
    self._lastDisplayedMessageD = 0

    local db = MODULES.Database:Personal()
    if not db.version then
        db.version = {}
    end
    self.db = db.version

    self.handlers = {
        [CONSTANTS.VERSIONNING_COMM.TYPE.ANNOUNCE_VERSION]  = HandleAnnounceVersion,
        -- [CONSTANTS.VERSIONNING_COMM.TYPE.REQUEST_VERSION]   = HandleRequestVersion,
    }

    Comms:Register(VERSION_COMM_PREFIX, (function(rawMessage, distribution, sender)
        local message = VersionCommStructure:New(rawMessage)
        if CONSTANTS.VERSIONNING_COMM.TYPES[message:Type()] == nil then return end
        HandleIncomingMessage(self, message, distribution, sender)
    end), CONSTANTS.ACL.LEVEL.PLEBS, true)

    LedgerManager:RegisterOnUpdate(function(lag, uncommitted)
        if lag ~= 0 or uncommitted ~= 0 then return end
        if not self._initialized then
            RestoreVersions(self)
            LOG:Message("Classic Loot Manager %s initialization complete.", ColorCodeText(CLM.CORE:GetVersionString(), "00cc00"))
            C_Timer.After(math.random(1, 5), function()
                AnnounceVersion(self)
            end)
            self._initialized = true
        end
    end)

    EventManager:RegisterEvent("READY_CHECK", (function(...) AnnounceVersion(self) end))

    MODULES.ConfigManager:RegisterUniversalExecutor("ver", "Version", self)
end

CONSTANTS.VERSIONNING_COMM = {
    TYPE = {
        ANNOUNCE_VERSION    = 1,
        REQUEST_VERSION     = 2
    },
    TYPES = UTILS.Set({ 1, 2 })
}

MODULES.VersionManager = VersionManager