local isVerbose = false -- non-verbose  by default
local userNotifiedOfNewVersion = false

ProfessionProfessor = LibStub("AceAddon-3.0"):NewAddon("ProfessionProfessor", "AceEvent-3.0", "AceComm-3.0", "AceConsole-3.0", "AceSerializer-3.0")

-- Create shorthand reference for less typing
prof = ProfessionProfessor

local aceGUI = LibStub("AceGUI-3.0")

local allowedTradeskills = {
    "Alchemy",
    "Blacksmithing",
    "Enchanting",
    "Engineering",
    "Leatherworking",
    "Tailoring",
    "Jewelcrafting",
    "Cooking",
    "Inscription"
}

-- AceAddon :OnInitialize()
function prof:OnInitialize()
    self.version = GetAddOnMetadata("ProfessionProfessor", "Version")

    self.db = LibStub("AceDB-3.0"):New("ProfessionProfessorDB")

    -- Set up default options

    if not self.db.char.options then
        self.db.char.options = {}
        self.db.char.options['verbose'] = isVerbose
    else
        isVerbose = self.db.char.options['verbose']
    end

    -- Console commands
    prof:RegisterChatCommand("pro", "consoleCommands")
    -- Event registration
    -- as or 3.0.3 Enchanting counts as a normal tradeskill
    prof:RegisterEvent("TRADE_SKILL_UPDATE", "tradeSkillUpdate")
    
    -- Version checking
    prof:RegisterComm("PROFPRO_VERSION", "onCommReceived")
    prof:SendCommMessage("PROFPRO_VERSION", prof.version, "GUILD")
end

local function verbosePrint(message)
    if isVerbose then
        prof:Print(message)
    end
end

local function isTradeskillSupported(value)
    for i,v in ipairs(allowedTradeskills) do
        if v == value then
            return true
        end
    end
    return false
end

local function splitString(s, delimiter)
    result = {};
    for match in (s..delimiter):gmatch("(.-)%"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

function prof:toggleVerbose()
    if self.db.char.options and self.db.char.options['verbose'] ~= nil then
        isVerbose = not self.db.char.options['verbose']
        self.db.char.options['verbose'] = isVerbose
        prof:Print("Turned verbose mode " .. (isVerbose and 'On' or 'Off'))
    end
end

function prof:tradeSkillUpdate()
    -- Add in a check if the tradeskill has been linked (we don't want to index someone elses recipes!)
    local isLink, linkedPlayer = IsTradeSkillLinked()
    if isLink then
        verbosePrint("Recipe is a linked skill from player " .. linkedPlayer)
        -- break out early
        return
    end

    updateProfessionDB()
end

function prof:onCommReceived(prefix, payload, distribution, sender)    
	if prefix == "PROFPRO_VERSION" then
		-- Only notify the user once of a newer version
		if userNotifiedOfNewVersion then
			return
		end
	
		receivedVersion = splitString(payload, ".")
		currentVersion = splitString(prof.version, ".")
		
		for i=1, #receivedVersion do
			if tonumber(currentVersion[i]) < tonumber(receivedVersion[i]) then
				prof:Print("A newer version (".. payload ..") is available, please update!")
				userNotifiedOfNewVersion = true
				return
			end
			
			-- Check if our version is newer and early out, if we don't do this there might be issues
			-- with checking versions 2.1.1 vs 2.0.9
			if tonumber(currentVersion[i]) > tonumber(receivedVersion[i]) then
				return
			end
		end
	end
end

function updateProfessionDB()
    local localisedName = GetTradeSkillLine()
    local numSkills = GetNumTradeSkills()
    
    if not isTradeskillSupported(localisedName) then 
        return 
    end

    if type(prof.db.char.professions) == "table" then
        if prof.db.char.professions[localisedName] and prof.db.char.professions[localisedName]["numSkills"] >= numSkills then
            verbosePrint("No new recipes found for " .. localisedName)
            return
        end
    else
        prof.db.char.professions = {}
    end

    verbosePrint("Updating database for " .. localisedName)

    local learnedIds = {}
    local amount = 0

    for i=1,numSkills do
        local _,skillType = GetTradeSkillInfo(i)
        -- Skip the headers, only check real skills
        if skillType ~= "header" then
            local itemLink, id = getTradeSkillItemId(i)

            verbosePrint("Adding "  .. itemLink .. ' [' .. id .. ']')
            table.insert(learnedIds, id)
            amount = amount + 1
        end
    end
    
    if amount > 0 then
        previousAmount = prof.db.char.professions[localisedName] and prof.db.char.professions[localisedName]["realNumSkills"] or 0
        prof.db.char.professions[localisedName] = {
            ["numSkills"] =  numSkills,
            ["realNumSkills"] = amount,
            ["learnedIds"] = learnedIds
        }
        
        newlyLearnedAmount = amount - previousAmount        
        prof:Print(newlyLearnedAmount .. " new " .. (newlyLearnedAmount > 1 and "recipes" or "recipe") .. " found for " .. localisedName)
    end
end

function getTradeSkillItemId(i)
    local itemLink
    local returnid

    itemLink = GetTradeSkillRecipeLink(i)

    returnid = itemLink:match("enchant:(%d+)")
    if returnid == nil then
        returnid = itemLink:match("item:(%d+)")
    end

    return itemLink, returnid
end

function prof:consoleCommands(input)
    if not input or input:trim() == "" then
        if self.db.char.professions and next(self.db.char.professions) ~= nil then
            showJson()
        else
            self:Print("Please open your professions windows to update the database, so there is something to export")
        end
    elseif input == "reset" then
        self.db.char.professions = {}
        self:Print("Data has been reset")
    elseif input == "print" then
        if self.db.char.professions then
            local output = "You have " .. countTable(self.db.char.professions) .. " saved"
            for k,v in pairs(self.db.char.professions) do
                output = output .. ", " .. k .. "(" .. self.db.char.professions[k]['realNumSkills'] .. ") "
            end
            self:Print(output)
        end
    elseif input == "verbose" then
        self:toggleVerbose()
    end
end

function showJson()
    -- Create a container frame
    local f = aceGUI:Create("Frame")
    f:SetCallback("OnClose",function(widget) aceGUI:Release(widget) end)
    f:SetTitle("Profession Professor Skill Checker - Export -- " .. prof.version)
    f:SetLayout("Flow")

    local editBox = aceGUI:Create("MultiLineEditBox")
    editBox:SetWidth(800)
    editBox:SetHeight(500)
    editBox:SetText(convertTableToString())
    editBox:SetLabel("Copy text and paste into your discord channel with the Profession Professor bot and using the /upload slash command")
    editBox:SetNumLines(20)
    editBox:DisableButton(true)

    f:AddChild(editBox)
end

function countTable(tableName)
    local count = 0
    for _ in pairs(tableName) do
        count = count + 1
    end
    return count
end

function convertTableToString()
    local name,_ = UnitName("player")
    local faction,_ = UnitFactionGroup("player")

    local text = name .. ";" .. faction .. ";" .. GetRealmName() .. ";"

    for k,v in pairs(prof.db.char.professions) do
        text = text .. k .. ";"
        text = text .. getSkillString(k)
    end
    return text
end

function getSkillString(key)
    local profession = prof.db.char.professions[key]
    local realNumSkills = profession['realNumSkills']
    local list = profession['learnedIds']

    local text = ""

    for i = 1,realNumSkills do
        if list[i] ~= nil then
            text = text .. list[i] .. ";"
        end
    end

    return text
end
