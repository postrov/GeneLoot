--- gets location used for deciding whether new looting is the same as previous looting
local function getLocation()
  local zone, subZone = GetRealZoneText() or '', GetSubZoneText() or ''
  return zone .. subZone
end

--- looting info variables, describing last looting circumstances
local LOOT_RESET_TIMER = 30
local lastLootTime = 0
local lastLootLocation = getLocation()
local lastLootTargetGUID = nil

--- assumes loot window is opened, returns GUID or nil
local function getLootTargetGUID()
  return UnitExists('target') and UnitIsEnemy('target', 'player') and UnitGUID('target') or nil
end

--- sets old looting info to current looting info
local function resetLastLootInfo()
  lastLootTime = GetTime()
  lastLootLocation = getLocation()
  lastLootTargetGUID = getLootTargetGUID()
end

--- tries to tell if current looting is different than last looting
local function shouldAutoProcessLoot()
  -- todo: perhaps check if we're in raid and ML
  local time = GetTime()
  if time - lastLootTime > LOOT_RESET_TIMER then
    return true
  end

  local lootTargetGUID = getLootTargetGUID()
  if lootTarget then
    return lootTargetGUID ~= lastLootTargetGUID
  end
 
  return getLocation() ~= lastLootLocation  
end

--- loot spec -> officer mapping
local LOOT_OFFICERS = {
  str_dps = 'Berrí',
  str_tank = 'Berrí',
  agi_dps = 'Aylje',
  -- agi_tank = 'Aylje',
  int_dps = 'Sorcelator',
  int_healer = 'Ktenn',
  vanq_token = 'Sorcelator',
  conq_token = 'Ktenn',
  prot_token = 'Aylje'
}

local function getLootSpec(item)
  local stats = item.itemStats
  local str, agi, int, spi, dodge, parry
  str = stats['ITEM_MOD_STRENGTH_SHORT'] or 0
  agi = stats['ITEM_MOD_AGILITY_SHORT'] or 0
  int = stats['ITEM_MOD_INTELLECT_SHORT'] or 0
  if str > 0 then
    dodge = stats['ITEM_MOD_DODGE_RATING_SHORT'] or 0
    parry = stats['ITEM_MOD_PARRY_RATING_SHORT'] or 0
    return (parry > 0 or dodge > 0) and 'str_tank' or 'str_dps'
  elseif int > 0 then
    spi = stats['ITEM_MOD_SPIRIT_SHORT'] or 0
    return (spi > 0) and 'int_healer' or 'int_dps'
  elseif agi > 0 then
    return 'agi_dps'
  else
    local name = item.itemName
    if string.match(name, ' Vanquisher$') then
      return 'vanq_token'
    elseif string.match(name, ' Protector$') then
      return 'prot_token'
    elseif string.match(name, ' Conqueror$') then
      return 'conq_token'
    end
    -- todo: perhaps determine troublesome items by id
    return nil
  end
end

local function getLootOfficer(lootSpec)
  return lootSpec and LOOT_OFFICERS[lootSpec]
end

--- gets item information for all loot items, assumes looting is in progress
local function getLootItems(numLootItems)
  local items = {}
  for i = 1, numLootItems do
    if GetLootSlotType(i) == LOOT_SLOT_ITEM then
      local item = {}
      item.itemLink = GetLootSlotLink(i)
      item.itemName, item.itemLink, item.itemRarity, item.itemLevel, item.itemMinLevel,
            item.itemType, item.itemSubType, item.itemStackCount, item.itemEquipLoc,
            item.itemTexture, item.itemSellPrice = GetItemInfo(item.itemLink)
      item.itemStats = GetItemStats(item.itemLink)
      items[#items + 1] = item
    end
  end
  return items
end

--- announce all loot and appropriate officers to whisper to
local function announceLootItems(items)
  local lootThreshold = GetLootThreshold()
  local index = 1
  for i = 1, #items do 
      local item = items[i]
      local lootSpec = getLootSpec(item)
      local lootOfficer = getLootOfficer(lootSpec) or 'idk'
      if item.itemRarity >= lootThreshold then
        SendChatMessage(format('%d: %s -> %s', index, item.itemLink, lootOfficer), 'RAID_WARNING')
        -- print(format('%d: %s -> %s', index, item.itemLink, lootOfficer))
        index = index + 1
      end
  end
end

--- main function to be called when looting takes place
local function processLoot()
  local numLootItems = GetNumLootItems()

  if numLootItems == 0 then
    print('Not looting now')
  else
    local items = getLootItems(numLootItems)
    table.sort(items, function(a, b)
      local itemName1, itemName2 = a and a.itemName or '', b and b.itemName or ''
      local ilvl1, ilvl2 = a and a.itemLevel or '', b and b.itemLevel or ''
      return (itemName1 .. ilvl1) < (itemName2 .. ilvl2)
    end)
    announceLootItems(items)
  end
end

--- slash command function to run looting announcements
local function geneLootSlash(msg, editbox)
  processLoot()
end

SLASH_GENELOOT1 = '/geneloot'
SlashCmdList.GENELOOT = geneLootSlash

local frame = CreateFrame('Frame', 'GeneLootFrame')
frame:RegisterEvent('LOOT_OPENED')

local function isPlayerMasterLooter()
  if not IsInRaid() then
    return false
  end

  local lootmethod, masterLooterPartyID, masterLooterRaidID = GetLootMethod()
  if (lootmethod ~= 'master') then
    return false;
  end
  
  return UnitId(format('raid%d', masterLooterRaidID)) == UnitId('player')
end

local function eventHandler(self, event, ...) 
  if event == 'LOOT_OPENED' then
    if isPlayerMasterLooter and shouldAutoProcessLoot() then
      resetLastLootInfo()
      processLoot()
    end
  end
end

frame:SetScript('OnEvent', eventHandler)

