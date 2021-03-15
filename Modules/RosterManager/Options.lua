local _, CLM = ...
-- local LOG = CLM.LOG
local CONSTANTS = CLM.CONSTANTS
local OPTIONS = CLM.OPTIONS
local MODULE = CLM.MODULE
local RosterManager = MODULE.RosterManager

local CBTYPE = {
    GETTER   = "get",
    SETTER   = "set",
    EXECUTOR = "execute"
}

local RosterManagerOptions = { externalOptions = {} }

function RosterManagerOptions:Initialize()
    self.handlers = {
        name_get = (function(name) 
            return name
        end),
        -- TODO: set to the newly renamed (for dropdown) instead of first one. No issue seen for tree
        name_set = (function(old, new) 
            print(old .. " -> " .. new)
            RosterManager:RenameRoster(old, new)
            self:UpdateOptions()
        end),
        remove_execute = (function(name)
            RosterManager:DeleteRosterByName(name)
            self:UpdateOptions()
        end),
        -- copy
        -- copy_source
        point_type_get = (function(name) return 0 end),
        -- point_type_set
        auction_type_get = (function(name) return 0 end),
        -- auction_type
        item_value_mode_get = (function(name) return 0 end),
        -- item_value_mode
        zero_sum_bank_get = (function(name) return false end),
        -- zero_sum_bank
        allow_negative_standings_get = (function(name) return true end),
        -- allow_negative_standings
        allow_negative_bidders_get = (function(name) return true end),
        -- allow_negative_bidders
        simultaneous_auctions_get = (function(name) return false end),
        -- simultaneous_auctions
    }

    self:UpdateOptions()
end

function RosterManagerOptions:_Handle(cbtype, info, ...)
    -- for k,v in pairs(info) do
    --     print("[" .. tostring(k) .."]: " .. tostring(v) )
    -- end
    -- Assumes This is the handler of each of the subgroups but not the main group
    local roster_name = info[1]
    node_name = ""
    if #info >= 2 then
        node_name = info[2]
        for i=3,#info do
            node_name = node_name .. "_" .. info[i]
        end
    else
        node_name = info[#info]
    end
    node_name = node_name .. "_".. cbtype
    print(node_name)
    -- Execute handler
    if type(self.handlers[node_name]) == "function" then
        return self.handlers[node_name](roster_name, ...)
    end
    return nil
end

function RosterManagerOptions:Getter(info, ...)
   return self:_Handle(CBTYPE.GETTER, info, ...)
end

function RosterManagerOptions:Setter(info, ...)
    self:_Handle(CBTYPE.SETTER, info, ...)
end

function RosterManagerOptions:Handler(info, ...)
    self:_Handle(CBTYPE.EXECUTOR, info, ...)
end
    -- -- Point type: DKP / EPGP
    -- self.pointType = CONSTANTS.POINT_TYPES.DKP
    -- -- Auction type: Open / Sealed / Vickrey
    -- self.auctionType = CONSTANTS.AUCTION_TYPES.SEALED
    -- -- Item Value mode: Single-Priced / Ascending
    -- self.itemValueMode = CONSTANTS.ITEM_VALUE_MODES.SINGLE_PRICED
    -- -- Allow negative standings
    -- self.allowNegativeStandings = false
    -- -- Allow negative bidders
    -- self.allowNegativeBidders = false 
    -- -- Zero-Sum Bank
    -- self.zeroSum = false
    -- -- Simultaneous Auctions
    -- self.simultaneousAuctions = false
function RosterManagerOptions:GenerateRosterOptions(name)
    local options = {
        type = "group",
        name = name,
        handler = self,
        set = "Setter",
        get = "Getter",
        func = "Handler",
        args = {
            name = {
                name = "Name",
                desc = "Change roster name.",
                type = "input",
                width = "full",
                order = 1
            },
            description = {
                name = "Description",
                desc = "Roster description.",
                type = "input",
                width = "full",
                multiline = 4,
                order = 2
            },
            copy = {
                name = "Copy settings",
                desc = "Copy settings from selected roster.",
                type = "execute",
                confirm = true,
                order = 98
            },
            copy_source = {
                name = "Copy source",
                --desc = "Copy settings from selected roster.",
                type = "select",
                values = (function() 
                    local r = RosterManager:GetRosters()
                    local v = {}
                    for name, _ in pairs(r) do
                        v[name] = name
                    end
                    return v
                end),
                order = 99
            },
            remove = {
                name = "Remove",
                desc = "Removes current roster.",
                type = "execute",
                confirm = true,
                order = 100
            },
            point_type = {
                name = "Point type",
                desc = "DKP or EPGP (currently not supported).",
                type = "select",
                style = "radio",
                order = 3,
                width = "half",
                disabled = true,
                values = {
                    [0] = "DKP", 
                    [1] = "EPGP"
                }
            },
            auction_type = {
                name = "Auction type",
                desc = "Type of auction used: Open, Sealed, Vickrey (Sealed with second-highest pay price).",
                type = "select",
                style = "radio",
                order = 4,
                values = { 
                    [0] = "Open",
                    [1] = "Sealed",
                    [2] = "Vickrey"
                }
            },
            item_value_mode = {
                name = "Item value mode",
                desc = "Single-Priced (static) or Ascending (in range of min-max) item value.",
                type = "select",
                style = "radio",
                order = 5,
                values = { 
                    [0] = "Single-Priced",
                    [1] = "Ascending"
                }
            },
            zero_sum_bank = {
                name = "Zero-Sum Bank",
                desc = "Enable paid value splitting amongst raiders.",
                type = "toggle",
                width = "full",
                order = 6
            },
            allow_negative_standings = {
                name = "Allow Negative Standings",
                desc = "Allow biding more than current standings and end up with negative values.",
                type = "toggle",
                width = "full",
                order = 7
            },
            allow_negative_bidders = {
                name = "Allow Negative Bidders",
                desc = "Allow biding when current standings are negative values.",
                type = "toggle",
                width = "full",
                order = 8
            },
            simultaneous_auctions = {
                name = "Simultaneous auctions",
                desc = "Allow multiple simultaneous auction happening at the same time.",
                type = "toggle",
                width = "full",
                order = 9
            }
        }
    }
    return options
end


function RosterManagerOptions:UpdateOptions()
    local options = {
        new = { -- Global options -> Create New Roster
            name = "Create",
            desc = "Creates new roster with default configuration",
            type = "execute",
            func = function() RosterManager:NewRoster(); self:UpdateOptions() end,
            order = 1
        },
        sync = { -- Global options -> Send New Rosters
            name = "Synchronise",
            desc = "Sends and overwrites roster configuration",
            type = "execute",
            func = function() end,
            confirm = true,
            order = 2
        }
    }
    local rosters = MODULE.RosterManager:GetRosters()
    for name, _ in pairs(rosters) do
        options[name] = self:GenerateRosterOptions(name)
    end
    MODULE.ConfigManager:Register(CONSTANTS.CONFIGS.GROUP.ROSTER, options, true)
end

-- Accepts array of ACE options and array of callbacks
function RosterManagerOptions:RegisterOptions(options, callbacks)

end

OPTIONS.RosterManager = RosterManagerOptions