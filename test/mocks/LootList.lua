local M = {}

---@param loot_facade LootFacade
function M.new( loot_facade )
  local m_items = {}

  ---@param items MasterLootDistributableItem[]
  local function load_items( items )
    for slot, _ in pairs( m_items ) do
      m_items[ slot ] = nil
    end

    for slot, item in pairs( items or {} ) do
      m_items[ slot ] = item
    end
  end

  local looting = false

  local function get_items()
    local result = {}

    for _, item in pairs( m_items or {} ) do
      table.insert( result, item )
    end

    return result
  end

  local function get_source_guid()
    return M.source_guid or "PrincessKenny"
  end

  ---@param item_id number
  local function get_slot( item_id )
    for slot, item in pairs( m_items or {} ) do
      if item.id == item_id then
        return slot
      end
    end
  end

  ---@param item_id number
  local function count( item_id )
    local result = 0

    for _, item in pairs( get_items() ) do
      if item.id == item_id then
        result = result + 1
      end
    end

    return result
  end

  ---@param item_id number
  ---@return MasterLootDistributableItem?
  local function get_by_id( item_id )
    for _, item in pairs( get_items() ) do
      if item.id == item_id then return item end
    end
  end

  ---@param ... MasterLootDistributableItem
  local function on_loot_opened( ... )
    looting = true
    load_items( { ... } )
  end

  local function on_loot_slot_cleared( slot )
    m_items[ slot ] = nil
  end

  local function on_loot_closed()
    looting = false
  end

  local function size()
    local result = 0

    for _ in pairs( m_items ) do
      result = result + 1
    end

    return result
  end

  loot_facade.subscribe( "LootOpened", on_loot_opened )
  loot_facade.subscribe( "LootSlotCleared", on_loot_slot_cleared )
  loot_facade.subscribe( "LootClosed", on_loot_closed )

  ---@type SoftResLootList
  return {
    ---@diagnostic disable-next-line: assign-type-mismatch
    get_items = get_items,
    get_source_guid = get_source_guid,
    get_slot = get_slot,
    count = count,
    is_looting = function() return looting end,
    get_by_id = get_by_id,
    size = size
  }
end

return M
