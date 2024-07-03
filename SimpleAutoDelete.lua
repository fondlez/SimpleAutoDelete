--[[

	SimpleAutoDelete
		Automatically delete items specified in the list.
		Will only trigger outside of combat

		Original addon by null
		https://github.com/nullfoxh/SimpleAutoDelete-TBC
    
    Modified for vanilla (1.12.1) by fondlez
    https://github.com/fondlez/SimpleAutoDelete

]]--

---------------------------------------------------------------------------------------------


local GetContainerNumSlots, GetContainerNumFreeSlots, UnitAffectingCombat, GetItemInfo
	= GetContainerNumSlots, GetContainerNumFreeSlots, UnitAffectingCombat, GetItemInfo

local print = function(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffa0f6aaSimpleAutoDelete|r: "..msg)
end

local printv = function(msg)
	if SimpleAutoDelete.verbose then print(msg) end
end

SimpleAutoDelete = {
	list = {},
	verbose = true,
	delay = 0.4
}

---------------------------------------------------------------------------------------------

local function getTableSize(t)
	local count = 0
	for _ in pairs(t) do
		count = count + 1
	end
	return count
end

-- Utility function to lowercase compare strings for equality
local function leq(a, b)
  return strlower(a) == strlower(b)
end

-- Utility function to parse components of an item string
local function parseItemString(target)
  local found, _, item_id, enchant_id, suffix_id, unique_id = strfind(target,
    "item:(%d+):(%d*):(%d*):(%d*)")
  if not found then return end
  return tonumber(item_id), tonumber(enchant_id) or 0, tonumber(suffix_id) or 0,
    tonumber(unique_id) or 0
end

local function matchItem(arg)
  --[[
    In the vanilla API, GetItemInfo() cannot parse item links or item names.
    It can only parse item ids. It also does not return an item link as the 
    second return value, it returns an item string instead, e.g. 
    "item:6948:0:0:0"
     and NOT "|cffffffff|Hitem:6948:0:0:0|h[Hearthstone]|h|r"
     An item string parse function is used to replace an input item link or item
     string into an item id, where available.
  --]]
  local itemId = parseItemString(arg)
	local itemName, itemLink, rarity = GetItemInfo(itemId or arg)

	if not itemName then
		itemName = arg
		itemLink = arg
  else
    --[[
    -- This function return expects an item link where possible. So for vanilla, 
    -- item string, color from rarity and item name are re-combined into an 
    -- item link.
    --]]
    local ITEMLINK_FORMAT = "%s|H%s|h[%s]|h|r"
    local color
    _, _, _, color = GetItemQualityColor(rarity)
    itemLink = string.format(ITEMLINK_FORMAT, color, itemLink, itemName)
	end

	return itemName, itemLink
end

local function getItemNameById(id)
	local itemName = GetItemInfo(id)
	return itemName
end

-- This was implemented in wotlk or later
local function GetContainerItemID(container, slot)
	local itemLink = GetContainerItemLink(container, slot)
	if itemLink then
		local _, _, itemID = string.find(itemLink, "|Hitem:(%d+):")
		if itemID then
			return itemID
		end
	end
end

---------------------------------------------------------------------------------------------

local function deleteItems(test)
	local numDeleted = 0
	if test then
		print("Running test, looking for items to delete.")
	end

	for bag = 0, NUM_BAG_SLOTS do
		for slot = 1, GetContainerNumSlots(bag) do
			local itemId = GetContainerItemID(bag, slot)

			if itemId then
				local itemName = getItemNameById(itemId)

				if itemName then
					for i, item in ipairs(SimpleAutoDelete.list) do
						if leq(itemName, item) then
							local _, itemLink = matchItem(itemId)

							if test then
								print("Found item that would be deleted ".. itemLink..".")
							else
								printv("Deleting item ".. itemLink..".")
								PickupContainerItem(bag, slot)
								DeleteCursorItem()
							end

							numDeleted = numDeleted + 1
						end
					end
				end
			end
		end
	end

	if test then
		print("Found "..numDeleted.." items to delete.")
	end
end

local throttle = 0
local f = CreateFrame("Frame")
f:Hide()

f:SetScript("OnEvent", function(self, event, ...)
	if event == "LOOT_CLOSED" then
		if not UnitAffectingCombat("player") then
			f:Show()
		else
			f:RegisterEvent("PLAYER_REGEN_ENABLED")
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		f:Show()
		f:UnregisterEvent("PLAYER_REGEN_ENABLED")
	end
end)

f:SetScript("OnUpdate", function(self, elapsed)
	throttle = throttle + elapsed

	if throttle > SimpleAutoDelete.delay then
		throttle = 0
		deleteItems()
		self:Hide()
	end
end)

f:RegisterEvent("LOOT_CLOSED")

---------------------------------------------------------------------------------------------

local function addItem(arg)
	local itemName, itemLink = matchItem(arg)

	for _, item in ipairs(SimpleAutoDelete.list) do
		if leq(item, itemName) then
			print(itemLink .. " already exists in the list.")
			return
		end
	end

	print(itemLink .. " added to the list.")
	table.insert(SimpleAutoDelete.list, itemName)
end

local function removeItem(arg)
	local itemName, itemLink = matchItem(arg)

	for i, item in ipairs(SimpleAutoDelete.list) do
		if leq(item, itemName) then
			table.remove(SimpleAutoDelete.list, i)
			print(itemLink .. " removed from the list.")
			return
		end
	end

	print(itemLink .. " was not found in the list.")
end

local function viewItems()
	if getTableSize(SimpleAutoDelete.list) == 0 then
		print("The list of items to be deleted is currently empty.")
		return
	end

	print("Items in list:")
	for _, item in ipairs(SimpleAutoDelete.list) do
		local itemName, itemLink = matchItem(item)
		print("  " .. itemLink)
	end
end

local function setDelay(arg)
	local num = tonumber(arg)

	if num then
		SimpleAutoDelete.delay = num
		print("Delay set to " .. SimpleAutoDelete.delay .. " seconds.")
	else
		print("Invalid argument for delay. Please specify a number in seconds. Delay is currently set to ".. SimpleAutoDelete.delay .. " seconds.")
	end
end

local function setPrint(arg)
	if arg == "true" then
		SimpleAutoDelete.print = true
	elseif arg == "false" then
		SimpleAutoDelete.print = false
	else
		SimpleAutoDelete.print = not SimpleAutoDelete.print
	end

	if SimpleAutoDelete.print then
		print("Printing enabled.")
	else
		print("Printing disabled.")
	end
end

SLASH_SIMPLEAUTODELETE1 = "/simpleautodelete"
SLASH_SIMPLEAUTODELETE2 = "/sad"
SlashCmdList["SIMPLEAUTODELETE"] = function(cmd)
	local _, _, cmd, arg = string.find(cmd, "%s?(%w+)%s?(.*)")
	if cmd == "add" then
		addItem(arg)
	elseif cmd == "remove" then
		removeItem(arg)
	elseif cmd == "list" then
		viewItems()
	elseif cmd == "delay" then
		setDelay(arg)
	elseif cmd == "print" then
		setPrint(arg)
	elseif cmd == "test" then
		deleteItems(true)
	elseif cmd == "run" then
		deleteItems()
	else
		print("Unrecognized command. The available are commands:")
		print("/sad add <item name or link> - Adds an item to the list")
		print("/sad remove <item name or link> - Removes an item from the list")
		print("/sad list - Lists all items in the list")
		print("/sad delay <seconds> - Sets the delay time in seconds for deletion")
		print("/sad print <true/false> - Toggles printing of items being deleted")
		print("/sad test - Lists all items in your bags that would be deleted")
		print("/sad run - Scan your bags now and look for items to delete")
	end
end