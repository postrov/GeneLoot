function GeneLoot_OnLoad()
        this:RegisterEvent("VARIABLES_LOADED")
end

--- loot spec -> officer mapping
local LOOT_OFFICERS = {
  str_dps = "Aylje",
  str_tank = "Aylje",
  agi_dps = "Aylje",
  -- agi_tank = "Aylje",
  int_dps = "Sorcelator",
  int_healer = "Ktenn",
  vanq_token = "Sorcelator",
  conq_token = "Ktenn",
  prot_token = "Aylje"
}

local function getLootSpec(itemLink, stats, itemType, itemSubType)
  local str, agi, int, spi, dodge, parry
  str = stats["ITEM_MOD_STRENGTH_SHORT"] or 0
  agi = stats["ITEM_MOD_AGILITY_SHORT"] or 0
  int = stats["ITEM_MOD_INTELLECT_SHORT"] or 0
  if str > 0 then
    dodge = stats["ITEM_MOD_DODGE_RATING_SHORT"] or 0
    parry = stats["ITEM_MOD_PARRY_RATING_SHORT"] or 0
    return (parry > 0 or dodge > 0) and "str_tank" or "str_dps"
  elseif int > 0 then
    spi = stats["ITEM_MOD_SPIRIT_SHORT"] or 0
    return (spi > 0) and "int_healer" or "int_dps"
  elseif agi > 0 then
    return "agi_dps"
  else
    -- todo: perhaps determine troublesome items by id
    -- todo: handle tier tokens properly
    return nil
  end
end

local function getLootOfficer(lootSpec)
  return lootSpec and LOOT_OFFICERS[lootSpec]
end

--- gets item information for all loot items, assumes looting is in progress
local function getLootItems()
  local items = {}
  for i = 1, numLootItems do
    if GetLootSlotType(index) == LOOT_SLOT_ITEM then
      local item = {}
      item.itemLink = GetLootSlotLink(i)
      item.itemName, item.itemLink, item.itemRarity, item.itemLevel, item.itemMinLevel,
            item.itemType, item.itemSubType, item.itemStackCount, item.itemEquipLoc,
            item.itemTexture, item.itemSellPrice = GetItemInfo(itemLink)
      item.itemStats = GetItemStats(itemLink)
      items[#items + 1] = item
    end
  end
  return items
end

--- announce all loot and appropriate officers to whisper to
local function announceLootItems(items)
  for i = 1, #items do 
      local lootSpec = getLootSpec(itemLink, itemStats, itemType, itemSubType)
      local lootOfficer = getLootOfficer(lootSpec) or "idk"

      if itemRarity >= lootThreshold then
        -- todo: choose channel here, make sure to spam only in raids too
        SendChatMessage(format("%d: %s -> %s", index, itemLink, lootOfficer), "RAID_WARNING")
      end
  end
end

--- main function to be called when looting takes place
local function processLoot()
  local numLootItems = GetNumLootItems()
  local lootThreshold = GetLootThreshold()
  local lootmethod, masterlooterPartyID, masterlooterRaidID = GetLootMethod()
  -- todo: perhaps check if player is master looter
  if numLootItems == 0 then
    print("Not looting now")
  else
    local items = getLootItems()
    items.sort(items, function(a, b)
      return (a.itemName < b.itemName)  or (a.itemLevel > b.itemLevel)
    end)
    announceLootItems(items)
  end
end

--- slash command function to run looting announcements
local function geneLootSlash(msg, editbox)
  print("GeneLoot slash")
  processLoot()
end

SLASH_GENELOOT1 = "/geneloot"
SlashCmdList.GENELOOT = geneLootSlash

